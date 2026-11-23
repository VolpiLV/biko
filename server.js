// Biko - backend sem dependências externas (Node >= 22.13): http + node:sqlite + crypto.
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { T, pronto, newUser, hashPassword, verifyPassword, tx } = require('./db');
const { modoFirestore } = require('./firebase');
const { chamarServico, ServicoForaDoAr } = require('./servicos');
const notificador = require('./notificador'); // ponte com o microsserviço de notificações (pasta notificacoes/)

const COOKIE = 'biko_sid';
const SESSION_MS = 7 * 24 * 60 * 60 * 1000; // sessão persistida por 7 dias
const RESET_MS = 30 * 60 * 1000; // token de recuperação vale 30 min
const ROLES = ['admin', 'cliente', 'prestador'];
// Em produção o código iria por e-mail. Para a demonstração ele é devolvido na resposta.
const SHOW_RESET_TOKEN = process.env.NODE_ENV !== 'production';
const PUBLIC_DIR = path.join(__dirname, 'public');
// Categorias de serviço (a mesma lista vale para cadastro de serviço, busca e tela inicial do cliente)
const CATEGORIES = [
  { nome: 'Telhado & Reparador', desc: 'Telhas, goteiras e reparos' },
  { nome: 'Encanador', desc: 'Vazamentos, instalações, reparos' },
  { nome: 'Eletricista', desc: 'Instalações, fiação, quadros' },
  { nome: 'Pintor', desc: 'Pintura interna e externa' },
  { nome: 'Limpeza', desc: 'Faxina e limpeza pós-obra' },
  { nome: 'Jardinagem', desc: 'Poda, grama e jardins' },
];
const CATEGORY_NAMES = CATEGORIES.map((c) => c.nome);

// ---------- utilidades ----------
const now = () => Date.now();
const newToken = () => crypto.randomBytes(32).toString('hex');
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

function send(res, status, obj, headers = {}) {
  const body = JSON.stringify(obj);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': Buffer.byteLength(body), ...headers });
  res.end(body);
}
function sendBinary(res, status, buf, contentType, headers = {}) {
  res.writeHead(status, { 'Content-Type': contentType, 'Content-Length': buf.length, 'Cache-Control': 'private, max-age=86400', 'X-Content-Type-Options': 'nosniff', ...headers });
  res.end(buf);
}
class HttpError extends Error {
  constructor(status, message, fields) { super(message); this.status = status; this.fields = fields; }
}
const fail = (status, message, fields) => { throw new HttpError(status, message, fields); };

function parseCookies(req) {
  const out = {};
  (req.headers.cookie || '').split(';').forEach((p) => {
    const i = p.indexOf('=');
    if (i > -1) out[p.slice(0, i).trim()] = decodeURIComponent(p.slice(i + 1).trim());
  });
  return out;
}
const sessionCookie = (token) => `${COOKIE}=${token}; HttpOnly; SameSite=Lax; Path=/; Max-Age=${SESSION_MS / 1000}`;
const clearCookie = () => `${COOKIE}=; HttpOnly; SameSite=Lax; Path=/; Max-Age=0`;

function readBody(req, limit = 100 * 1024) {
  return new Promise((resolve, reject) => {
    let size = 0, tooBig = false;
    const chunks = [];
    req.on('data', (c) => {
      if (tooBig) return; // já estourou o limite: descarta o resto sem guardar na memória
      size += c.length;
      if (size > limit) { tooBig = true; chunks.length = 0; reject(new HttpError(413, 'Corpo da requisição muito grande.')); return; }
      chunks.push(c);
    });
    req.on('end', () => {
      if (tooBig) return;
      if (!chunks.length) return resolve({});
      try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
      catch (e) { reject(new HttpError(400, 'JSON inválido.')); }
    });
    req.on('error', reject);
  });
}

const photoUrl = (id, v) => (v > 0 ? `/api/photo/${id}?v=${v}` : null);
const publicUser = (u) => ({
  id: u.id, name: u.name, email: u.email, phone: u.phone, role: u.role, active: !!u.active, created_at: u.created_at, photo_url: photoUrl(u.id, u.photo_v),
  // perfil profissional (só prestador)
  ...(u.role === 'prestador' ? { specialty: u.specialty || null, visit_price: u.visit_price_cents ? u.visit_price_cents / 100 : null, online: u.online !== 0, categories: u.categories || null, verified: !!u.cpf } : {}),
});

function validatePassword(pw) {
  if (typeof pw !== 'string' || pw.length < 8) return 'A senha deve ter no mínimo 8 caracteres.';
  if (!/[A-Za-z]/.test(pw) || !/\d/.test(pw)) return 'A senha deve conter letras e números.';
  return null;
}
function validateProfile({ name, email, phone }) {
  const errors = {};
  if (typeof name !== 'string' || name.trim().length < 3) errors.name = 'Informe o nome completo (mín. 3 caracteres).';
  if (typeof email !== 'string' || !EMAIL_RE.test(email.trim())) errors.email = 'Informe um e-mail válido.';
  if (phone && !/^[\d\s()+-]{8,20}$/.test(String(phone))) errors.phone = 'Telefone inválido.';
  return errors;
}

// Sessão = documento sessions/<token> no Firestore
async function createSession(userId) {
  const token = newToken();
  await T.sessions.set(token, { token, user_id: userId, expires_at: now() + SESSION_MS });
  return token;
}

// O app mobile se identifica com "X-Client: mobile" no login/cadastro e recebe o token no corpo
// (para guardar no flutter_secure_storage). O navegador continua só com cookie HttpOnly,
// assim o JavaScript da página web nunca enxerga o token.
const wantsBearer = (req) => String(req.headers['x-client'] || '').toLowerCase() === 'mobile';
async function startSession(ctx, userId) {
  const token = await createSession(userId);
  if (wantsBearer(ctx.req)) return { token, token_type: 'Bearer', expires_at: now() + SESSION_MS };
  ctx.headers['Set-Cookie'] = sessionCookie(token);
  return {};
}

// Paginação por limit/offset (mesmo padrão do /api/search). Valores inválidos -> 400.
function parsePage(query, def = 20, max = 100) {
  const num = (v, fallback) => (v === undefined || v === '' ? fallback : /^\d+$/.test(String(v)) ? Number(v) : NaN);
  const limit = num(query.limit, def), offset = num(query.offset, 0);
  if (!Number.isInteger(limit) || limit < 1) fail(400, `O parâmetro limit deve ser um inteiro entre 1 e ${max}.`);
  if (!Number.isInteger(offset)) fail(400, 'O parâmetro offset deve ser um inteiro maior ou igual a 0.');
  return { limit: Math.min(limit, max), offset };
}
const pageInfo = (total, { limit, offset }) => ({ total, limit, offset, has_more: offset + limit < total });

// Limitador simples de tentativas de login (por e-mail+IP)
const attempts = new Map();
const MAX_ATTEMPTS = 5;
const WINDOW_MS = 10 * 60 * 1000;
const tooManyAttempts = (key) => { const a = attempts.get(key); return !!a && now() - a.first <= WINDOW_MS && a.count >= MAX_ATTEMPTS; };
function registerFailure(key) {
  const a = attempts.get(key);
  if (!a || now() - a.first > WINDOW_MS) attempts.set(key, { count: 1, first: now() });
  else a.count++;
}

// ---------- autenticação / autorização (backend) ----------
// Aceita "Authorization: Bearer <token>" (app mobile) ou o cookie de sessão (web).
// Retorna o usuário da sessão ou lança 401/403. Sessões inválidas são removidas.
function readToken(req) {
  const auth = req.headers.authorization;
  if (auth !== undefined) {
    const m = /^Bearer\s+([a-f0-9]{64})$/i.exec(auth.trim());
    if (!m) fail(401, 'Token de acesso inválido.');
    return m[1].toLowerCase();
  }
  return parseCookies(req)[COOKIE];
}
async function authenticate(ctx) {
  const token = readToken(ctx.req);
  if (!token) fail(401, 'Não autenticado.');
  const s = await T.sessions.get(token);
  const u = s ? await T.users.get(s.user_id) : undefined;
  if (!s || !u || s.expires_at < now()) {
    if (s) await T.sessions.remove(token);
    ctx.headers['Set-Cookie'] = clearCookie();
    fail(401, 'Sessão expirada. Faça login novamente.');
  }
  if (!u.active) {
    await T.sessions.removeWhere('user_id', '==', u.id);
    ctx.headers['Set-Cookie'] = clearCookie();
    fail(403, 'Sua conta está desativada.');
  }
  ctx.user = u;
  ctx.token = token;
}

// ---------- leituras com "join" (no Firestore os dados relacionados são buscados à parte) ----------
const usersById = async () => new Map((await T.users.all()).map((u) => [u.id, u]));
// Serviço + dados do prestador (era o SELECT ... JOIN users)
function withProvider(s, um, rm) {
  const u = um.get(s.provider_id) || {};
  const r = rm ? rm.get(s.provider_id) : null;
  return {
    ...s, provider_name: u.name, provider_photo_v: u.photo_v || 0, u_active: u.active, u_role: u.role,
    provider_specialty: u.specialty || null, provider_verified: !!u.cpf, provider_online: u.online !== 0,
    provider_categories: u.categories || null, provider_rating: r ? r.avg : null, provider_reviews: r ? r.count : 0,
  };
}
// Média das avaliações de cada prestador: Map(id -> { avg, count })
async function ratingsByProvider() {
  const m = new Map();
  for (const r of await T.reviews.all()) {
    const a = m.get(r.provider_id) || { sum: 0, count: 0 };
    a.sum += r.stars; a.count++; m.set(r.provider_id, a);
  }
  for (const a of m.values()) a.avg = Math.round((a.sum / a.count) * 10) / 10;
  return m;
}
// Serviços que aparecem para o cliente: ativos e de prestador ativo
// Categoria desligada no perfil profissional também some da busca.
async function publicServices() {
  const um = await usersById();
  const rm = await ratingsByProvider();
  return (await T.services.where('active', '==', 1)).map((s) => withProvider(s, um, rm))
    .filter((s) => s.u_active && s.u_role === 'prestador' && s.provider_online && (!s.provider_categories || s.provider_categories.includes(s.category)));
}
// Pedido + nome/telefone/foto do cliente e do prestador (era o ORDER_SELECT com JOIN)
function withPeople(o, um) {
  const c = um.get(o.client_id) || {}, p = um.get(o.provider_id) || {};
  return { ...o, client_name: c.name, client_phone: c.phone, client_photo_v: c.photo_v || 0, provider_name: p.name, provider_phone: p.phone, provider_photo_v: p.photo_v || 0 };
}
async function orderRow(id) {
  const o = await T.orders.get(id);
  if (!o) return undefined;
  const [c, p] = await Promise.all([T.users.get(o.client_id), T.users.get(o.provider_id)]);
  return withPeople(o, new Map([[o.client_id, c || {}], [o.provider_id, p || {}]]));
}
const byStartDesc = (a, b) => b.start_ts - a.start_ts || b.id - a.id;
const isActive = (o) => o.status === 'pendente' || o.status === 'confirmado';

async function categoryList() {
  const counts = {};
  for (const s of await publicServices()) counts[s.category] = (counts[s.category] || 0) + 1;
  return CATEGORIES.map((c) => ({ ...c, total: counts[c.nome] || 0 }));
}

// ---------- rotas ----------
const routes = [];
// opts: { auth: bool, roles: [..] }
function route(method, pattern, opts, handler) {
  const keys = [];
  const re = new RegExp('^' + pattern.replace(/:(\w+)/g, (_, k) => { keys.push(k); return '([^/]+)'; }) + '$');
  routes.push({ method, re, keys, opts, handler });
}
const emailTaken = async (mail, exceptId) => (await T.users.where('email', '==', mail)).some((u) => u.id !== exceptId);

// ----- AUTENTICAÇÃO -----
route('POST', '/api/auth/register', {}, async (ctx) => {
  const { name, email, phone, password, role } = ctx.body;
  const errors = validateProfile({ name, email, phone });
  const pwErr = validatePassword(password);
  if (pwErr) errors.password = pwErr;
  // Auto-cadastro só permite cliente ou prestador; admin nunca é criado por aqui.
  const finalRole = role === 'prestador' ? 'prestador' : 'cliente';
  // Verificação do profissional: CPF válido e maior de 18 anos
  let cpf = null, birth = null;
  if (finalRole === 'prestador') {
    cpf = String(ctx.body.cpf || '').replace(/\D/g, '');
    if (!cpfValido(cpf)) errors.cpf = 'CPF inválido. Confira os números.';
    birth = String(ctx.body.birth_date || '');
    const age = idade(birth);
    if (age === null) errors.birth_date = 'Informe a data de nascimento (DD/MM/AAAA).';
    else if (age < 18) errors.birth_date = 'Apenas maiores de 18 anos podem prestar serviços no Biko.';
    if (!ctx.body.terms) errors.terms = 'Aceite os Termos do Prestador para continuar.';
  }
  if (Object.keys(errors).length) fail(400, 'Dados inválidos.', errors);
  const mail = email.trim().toLowerCase();
  const id = await tx(async () => {
    if (await emailTaken(mail)) fail(409, 'Este e-mail já está cadastrado.', { email: 'E-mail já cadastrado.' });
    return T.users.insert({ ...newUser(name.trim(), mail, phone, password, finalRole), ...(cpf ? { cpf, birth_date: birth, online: 1 } : {}) });
  });
  const session = await startSession(ctx, id);
  return [201, { user: publicUser(await T.users.get(id)), ...session }];
});

route('POST', '/api/auth/login', {}, async (ctx) => {
  const { email, password } = ctx.body;
  if (!email || !password) fail(400, 'Informe e-mail e senha.');
  const mail = String(email).trim().toLowerCase();
  const key = `${mail}|${ctx.req.socket.remoteAddress}`;
  if (tooManyAttempts(key)) fail(429, 'Muitas tentativas. Aguarde alguns minutos e tente novamente.');
  // Entra com e-mail ou telefone (só os números do telefone são comparados)
  const digits = mail.replace(/\D/g, '');
  const user = mail.includes('@') ? await T.users.first('email', '==', mail)
    : digits.length >= 10 ? (await T.users.all()).find((u) => String(u.phone || '').replace(/\D/g, '').endsWith(digits.slice(-11))) : undefined;
  if (!user || !verifyPassword(String(password), user.password_hash)) {
    registerFailure(key);
    fail(401, 'E-mail ou senha inválidos.'); // mensagem genérica de propósito
  }
  if (!user.active) fail(403, 'Sua conta está desativada. Fale com o administrador.');
  attempts.delete(key);
  return [200, { user: publicUser(user), ...(await startSession(ctx, user.id)) }];
});

route('POST', '/api/auth/logout', { auth: true }, async (ctx) => {
  await T.sessions.remove(ctx.token);
  ctx.headers['Set-Cookie'] = clearCookie();
  return [200, { ok: true }];
});

route('GET', '/api/auth/me', { auth: true }, (ctx) => [200, { user: publicUser(ctx.user) }]);

route('POST', '/api/auth/forgot', {}, async (ctx) => {
  const mail = String(ctx.body.email || '').trim().toLowerCase();
  if (!EMAIL_RE.test(mail)) fail(400, 'Informe um e-mail válido.');
  const user = (await T.users.where('email', '==', mail)).find((u) => u.active);
  const out = { message: 'Se o e-mail estiver cadastrado, enviaremos as instruções de recuperação.' };
  if (user) {
    const token = newToken().slice(0, 24);
    await T.resets.set(token, { token, user_id: user.id, expires_at: now() + RESET_MS, used: 0 });
    console.log(`[recuperação de senha] ${mail} -> código: ${token}`);
    if (SHOW_RESET_TOKEN) out.devToken = token; // apenas para demonstração
  }
  return [200, out]; // mesma resposta existindo ou não (não revela quais e-mails existem)
});

route('POST', '/api/auth/reset', {}, async (ctx) => {
  const { token, password } = ctx.body;
  const pwErr = validatePassword(password);
  if (pwErr) fail(400, pwErr);
  const tk = String(token || '');
  const r = /^[a-f0-9]{1,64}$/i.test(tk) ? await T.resets.get(tk) : undefined;
  if (!r || r.used || r.expires_at < now()) fail(400, 'Código inválido ou expirado. Solicite um novo.');
  await T.users.update(r.user_id, { password_hash: hashPassword(password) });
  await T.resets.update(r.token, { used: 1 });
  await T.sessions.removeWhere('user_id', '==', r.user_id); // derruba sessões antigas
  return [200, { ok: true, message: 'Senha redefinida com sucesso. Faça login.' }];
});

// ----- ÁREAS POR PERFIL (controle de acesso no backend) -----
// avisos: pedidos ativos do cliente que o prestador adiou (aviso de atraso ou remarcação em cascata)
route('GET', '/api/cliente/home', { auth: true, roles: ['cliente', 'admin'] }, async (ctx) => {
  const t = now();
  const mine = (await T.orders.where('client_id', '==', ctx.user.id))
    .filter((o) => isActive(o) && o.delay_min > 0 && o.end_ts > t).sort((a, b) => a.start_ts - b.start_ts).slice(0, 5);
  const um = await usersById();
  const avisos = mine.map((o) => orderView(withPeople(o, um), ctx.user));
  return [200, { categorias: await categoryList(), avisos }];
});

route('GET', '/api/prestador/painel', { auth: true, roles: ['prestador', 'admin'] }, async (ctx) => {
  const id = ctx.user.id;
  const d = new Date(); const monthStart = new Date(d.getFullYear(), d.getMonth(), 1).getTime();
  const mine = await T.orders.where('provider_id', '==', id);
  const novos = mine.filter((o) => o.status === 'pendente').length;
  const ganhos = mine.filter((o) => o.status === 'concluido' && o.completed_ts >= monthStart).reduce((s, o) => s + o.price_cents, 0);
  const wk = new Date(d.getFullYear(), d.getMonth(), d.getDate() - ((d.getDay() + 6) % 7)).getTime(); // segunda-feira
  const feitosSemana = mine.filter((o) => o.status === 'concluido' && o.completed_ts >= wk);
  const um = await usersById();
  const proximos = mine.filter((o) => o.status === 'confirmado').sort((a, b) => a.start_ts - b.start_ts).slice(0, 3).map((o) => orderView(withPeople(o, um), ctx.user));
  const pendentes = mine.filter((o) => o.status === 'pendente').sort((a, b) => a.start_ts - b.start_ts).map((o) => orderView(withPeople(o, um), ctx.user));
  const r = (await ratingsByProvider()).get(id);
  return [200, {
    resumo: { pedidosNovos: novos, avaliacao: r ? r.avg : null, avaliacoes: r ? r.count : 0, ganhosMes: ganhos / 100, ganhosSemana: feitosSemana.reduce((s, o) => s + o.price_cents, 0) / 100, servicosSemana: feitosSemana.length },
    proximos, pendentes, mensagem: 'Aqui o prestador acompanha pedidos e ganhos.',
  }];
});

// ----- GESTÃO DE USUÁRIOS (somente admin) -----
route('GET', '/api/users', { auth: true, roles: ['admin'] }, async (ctx) => {
  const { search = '', role = '', status = '' } = ctx.query;
  const page = parsePage(ctx.query);
  const s = String(search).toLowerCase();
  const rows = (await T.users.all())
    .filter((u) => !s || u.name.toLowerCase().includes(s) || u.email.toLowerCase().includes(s))
    .filter((u) => !ROLES.includes(role) || u.role === role)
    .filter((u) => (status === 'ativo' ? u.active : status === 'inativo' ? !u.active : true))
    // id desempata nomes iguais, senão a mesma pessoa poderia aparecer em duas páginas
    .sort((a, b) => a.name.localeCompare(b.name, 'pt-BR', { sensitivity: 'base' }) || a.id - b.id);
  return [200, { users: rows.slice(page.offset, page.offset + page.limit).map(publicUser), ...pageInfo(rows.length, page) }];
});

// Números do painel do admin
route('GET', '/api/admin/resumo', { auth: true, roles: ['admin'] }, async () => {
  const us = await T.users.all(), os = await T.orders.all();
  return [200, {
    clientes: us.filter((u) => u.role === 'cliente').length, prestadores: us.filter((u) => u.role === 'prestador').length,
    desativados: us.filter((u) => !u.active).length, pedidos: os.length,
    pendentes: os.filter((o) => o.status === 'pendente').length, concluidos: os.filter((o) => o.status === 'concluido').length,
  }];
});

route('POST', '/api/users', { auth: true, roles: ['admin'] }, async (ctx) => {
  const { name, email, phone, password, role } = ctx.body;
  const errors = validateProfile({ name, email, phone });
  const pwErr = validatePassword(password);
  if (pwErr) errors.password = pwErr;
  if (!ROLES.includes(role)) errors.role = 'Perfil inválido.';
  if (Object.keys(errors).length) fail(400, 'Dados inválidos.', errors);
  const mail = email.trim().toLowerCase();
  const id = await tx(async () => {
    if (await emailTaken(mail)) fail(409, 'Este e-mail já está cadastrado.', { email: 'E-mail já cadastrado.' });
    return T.users.insert(newUser(name.trim(), mail, phone, password, role));
  });
  return [201, { user: publicUser(await T.users.get(id)) }];
});

route('PATCH', '/api/users/:id', { auth: true, roles: ['admin'] }, async (ctx) => {
  const id = Number(ctx.params.id);
  const target = Number.isInteger(id) ? await T.users.get(id) : undefined;
  if (!target) fail(404, 'Usuário não encontrado.');
  const b = ctx.body;
  const next = {
    name: b.name !== undefined ? b.name : target.name,
    email: b.email !== undefined ? b.email : target.email,
    phone: b.phone !== undefined ? b.phone : target.phone,
    role: b.role !== undefined ? b.role : target.role,
    active: b.active !== undefined ? (b.active ? 1 : 0) : target.active,
  };
  const errors = validateProfile(next);
  if (!ROLES.includes(next.role)) errors.role = 'Perfil inválido.';
  if (Object.keys(errors).length) fail(400, 'Dados inválidos.', errors);
  // O admin não pode se bloquear nem se rebaixar (evita ficar sem nenhum admin).
  if (id === ctx.user.id && (!next.active || next.role !== 'admin')) {
    fail(400, 'Você não pode desativar nem remover o perfil de admin da sua própria conta.');
  }
  const mail = String(next.email).trim().toLowerCase();
  if (await emailTaken(mail, id)) fail(409, 'Este e-mail já está cadastrado.', { email: 'E-mail já cadastrado.' });
  await T.users.update(id, { name: String(next.name).trim(), email: mail, phone: next.phone || null, role: next.role, active: next.active });
  // Desativou ou mudou de perfil -> derruba as sessões abertas dessa pessoa
  if (!next.active || next.role !== target.role) await T.sessions.removeWhere('user_id', '==', id);
  return [200, { user: publicUser(await T.users.get(id)) }];
});

route('POST', '/api/users/:id/password', { auth: true, roles: ['admin'] }, async (ctx) => {
  const pwErr = validatePassword(ctx.body.password);
  if (pwErr) fail(400, pwErr);
  const id = Number(ctx.params.id);
  if (!Number.isInteger(id) || !(await T.users.get(id))) fail(404, 'Usuário não encontrado.');
  await T.users.update(id, { password_hash: hashPassword(ctx.body.password) });
  await T.sessions.removeWhere('user_id', '==', id);
  return [200, { ok: true }];
});

// =====================================================================
// 4. PERFIL DO USUÁRIO (qualquer usuário logado, só mexe na própria conta)
// =====================================================================
const MAX_PHOTO_BYTES = 200 * 1024;
const PHOTO_TYPES = { 'image/png': 'png', 'image/jpeg': 'jpeg', 'image/webp': 'webp' };
// Confere os primeiros bytes do arquivo (não confia só no que o cliente diz que é)
function sniffImage(buf) {
  if (buf.length > 8 && buf[0] === 0x89 && buf.toString('ascii', 1, 4) === 'PNG') return 'image/png';
  if (buf.length > 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
  if (buf.length > 12 && buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') return 'image/webp';
  return null;
}

route('PATCH', '/api/me', { auth: true }, async (ctx) => {
  const u = ctx.user, b = ctx.body;
  const next = {
    name: b.name !== undefined ? b.name : u.name,
    email: b.email !== undefined ? b.email : u.email,
    phone: b.phone !== undefined ? b.phone : u.phone,
  };
  const errors = validateProfile(next);
  const mail = String(next.email).trim().toLowerCase();
  // Trocar o e-mail (que é o login) exige confirmar a senha atual
  if (!errors.email && mail !== u.email) {
    const key = `pwd|${u.id}`;
    if (!b.currentPassword) errors.currentPassword = 'Informe a senha atual para trocar o e-mail.';
    else if (tooManyAttempts(key)) fail(429, 'Muitas tentativas. Aguarde alguns minutos e tente novamente.');
    else if (!verifyPassword(String(b.currentPassword), u.password_hash)) { registerFailure(key); errors.currentPassword = 'Senha atual incorreta.'; }
  }
  if (Object.keys(errors).length) fail(400, 'Dados inválidos.', errors);
  if (await emailTaken(mail, u.id)) fail(409, 'Este e-mail já está cadastrado.', { email: 'E-mail já cadastrado.' });
  // perfil e status não entram aqui de propósito: ninguém muda o próprio perfil por esta rota
  await T.users.update(u.id, { name: String(next.name).trim(), email: mail, phone: next.phone ? String(next.phone).trim() : null });
  return [200, { user: publicUser(await T.users.get(u.id)) }];
});

route('POST', '/api/me/password', { auth: true }, async (ctx) => {
  const u = ctx.user;
  const { currentPassword, newPassword } = ctx.body;
  const key = `pwd|${u.id}`;
  if (tooManyAttempts(key)) fail(429, 'Muitas tentativas. Aguarde alguns minutos e tente novamente.');
  if (!currentPassword || !verifyPassword(String(currentPassword), u.password_hash)) {
    registerFailure(key);
    fail(400, 'Dados inválidos.', { currentPassword: 'Senha atual incorreta.' });
  }
  const pwErr = validatePassword(newPassword);
  if (pwErr) fail(400, 'Dados inválidos.', { newPassword: pwErr });
  if (newPassword === currentPassword) fail(400, 'Dados inválidos.', { newPassword: 'A nova senha deve ser diferente da atual.' });
  attempts.delete(key);
  await T.users.update(u.id, { password_hash: hashPassword(newPassword) });
  // derruba as OUTRAS sessões (outros aparelhos); a atual continua valendo
  for (const s of await T.sessions.where('user_id', '==', u.id)) if (s.token !== ctx.token) await T.sessions.remove(s.token);
  return [200, { ok: true, message: 'Senha alterada com sucesso.' }];
});

route('PUT', '/api/me/photo', { auth: true, bodyLimit: 400 * 1024 }, async (ctx) => {
  const m = /^data:(image\/[a-z]+);base64,([A-Za-z0-9+/=]+)$/.exec(String(ctx.body.image || ''));
  if (!m || !PHOTO_TYPES[m[1]]) fail(400, 'Envie uma imagem PNG, JPG ou WEBP.');
  const buf = Buffer.from(m[2], 'base64');
  if (!buf.length) fail(400, 'Imagem vazia.');
  if (buf.length > MAX_PHOTO_BYTES) fail(413, 'A foto deve ter no máximo 200 KB.');
  const real = sniffImage(buf);
  if (!real) fail(400, 'O arquivo enviado não é uma imagem válida.');
  // A foto fica num documento separado (user_photos/<id do usuário>) para não pesar nas listas
  await T.photos.set(ctx.user.id, { user_id: ctx.user.id, mime: real, data: buf });
  await T.users.update(ctx.user.id, { photo_v: (ctx.user.photo_v || 0) + 1 });
  return [200, { user: publicUser(await T.users.get(ctx.user.id)) }];
});

route('DELETE', '/api/me/photo', { auth: true }, async (ctx) => {
  await T.photos.remove(ctx.user.id);
  await T.users.update(ctx.user.id, { photo_v: 0 });
  return [200, { user: publicUser(await T.users.get(ctx.user.id)) }];
});

// Qualquer usuário logado pode ver a foto dos outros (aparece nos resultados de busca e nos pedidos)
route('GET', '/api/photo/:id', { auth: true }, async (ctx) => {
  const id = Number(ctx.params.id);
  const p = Number.isInteger(id) ? await T.photos.get(id) : undefined;
  if (!p) fail(404, 'Sem foto.');
  return [200, Buffer.from(p.data), { contentType: p.mime }];
});

// =====================================================================
// SERVIÇOS DO PRESTADOR (é o que a busca do cliente encontra)
// =====================================================================
const serviceView = (r) => ({
  id: r.id, provider_id: r.provider_id, provider_name: r.provider_name, provider_photo_url: photoUrl(r.provider_id, r.provider_photo_v),
  title: r.title, category: r.category, description: r.description,
  price: r.price_cents / 100, duration_min: r.duration_min, active: !!r.active,
  provider_specialty: r.provider_specialty || null, provider_verified: !!r.provider_verified, provider_online: r.provider_online !== false,
  provider_rating: r.provider_rating ?? null, provider_reviews: r.provider_reviews || 0,
});
async function serviceRow(id) {
  const s = await T.services.get(id);
  if (!s) return undefined;
  const u = await T.users.get(s.provider_id);
  return withProvider(s, new Map([[s.provider_id, u || {}]]));
}

function validateService(b) {
  const e = {};
  if (typeof b.title !== 'string' || b.title.trim().length < 3 || b.title.trim().length > 80) e.title = 'O título deve ter de 3 a 80 caracteres.';
  if (!CATEGORY_NAMES.includes(b.category)) e.category = 'Escolha uma categoria válida.';
  if (b.description !== undefined && b.description !== null && (typeof b.description !== 'string' || b.description.length > 300)) e.description = 'A descrição pode ter no máximo 300 caracteres.';
  const price = Number(b.price);
  if (b.price === '' || b.price === null || b.price === undefined || !Number.isFinite(price) || price <= 0 || price > 100000) e.price = 'Informe um preço entre R$ 0,01 e R$ 100.000.';
  const dur = Number(b.duration_min);
  if (!Number.isInteger(dur) || dur < 30 || dur > 480 || dur % 15 !== 0) e.duration_min = 'A duração deve ser de 30 a 480 minutos, em múltiplos de 15.';
  return e;
}

route('GET', '/api/categories', { auth: true }, async () => [200, { categories: await categoryList() }]);

route('GET', '/api/services/mine', { auth: true, roles: ['prestador'] }, async (ctx) => {
  const um = new Map([[ctx.user.id, ctx.user]]);
  const rows = (await T.services.where('provider_id', '==', ctx.user.id))
    .sort((a, b) => b.active - a.active || a.title.localeCompare(b.title, 'pt-BR', { sensitivity: 'base' }));
  const out = [];
  for (const r of rows) out.push({ ...serviceView(withProvider(r, um)), real_stats: await serviceStats(r.id) });
  return [200, { services: out }];
});

route('POST', '/api/services', { auth: true, roles: ['prestador'] }, async (ctx) => {
  const b = ctx.body;
  const errors = validateService(b);
  if (Object.keys(errors).length) fail(400, 'Dados inválidos.', errors);
  const id = await T.services.insert({
    provider_id: ctx.user.id, title: b.title.trim(), category: b.category, description: String(b.description || '').trim(),
    price_cents: Math.round(Number(b.price) * 100), duration_min: Number(b.duration_min), active: 1, created_at: new Date().toISOString(),
  });
  return [201, { service: serviceView(await serviceRow(id)) }];
});

route('PATCH', '/api/services/:id', { auth: true, roles: ['prestador'] }, async (ctx) => {
  const id = Number(ctx.params.id);
  const s = Number.isInteger(id) ? await T.services.get(id) : undefined;
  if (!s) fail(404, 'Serviço não encontrado.');
  if (s.provider_id !== ctx.user.id) fail(403, 'Este serviço pertence a outro prestador.');
  const b = ctx.body;
  const next = {
    title: b.title !== undefined ? b.title : s.title,
    category: b.category !== undefined ? b.category : s.category,
    description: b.description !== undefined ? b.description : s.description,
    price: b.price !== undefined ? b.price : s.price_cents / 100,
    duration_min: b.duration_min !== undefined ? b.duration_min : s.duration_min,
  };
  const errors = validateService(next);
  if (Object.keys(errors).length) fail(400, 'Dados inválidos.', errors);
  const active = b.active !== undefined ? (b.active ? 1 : 0) : s.active;
  await T.services.update(id, {
    title: next.title.trim(), category: next.category, description: String(next.description || '').trim(),
    price_cents: Math.round(Number(next.price) * 100), duration_min: Number(next.duration_min), active,
  });
  return [200, { service: serviceView(await serviceRow(id)) }];
});

// =====================================================================
// 6. BUSCA (sobre os serviços reais cadastrados, sem acento e sem diferenciar maiúscula)
// =====================================================================
const norm = (s) => String(s ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();
const SORTS = ['relevancia', 'preco_asc', 'preco_desc', 'nome', 'nota'];

route('GET', '/api/search', { auth: true }, async (ctx) => {
  const { q = '', category = '', max_price = '', sort = '' } = ctx.query;
  if (q.length > 80) fail(400, 'A busca pode ter no máximo 80 caracteres.');
  if (category && !CATEGORY_NAMES.includes(category)) fail(400, 'Categoria inválida.');
  let maxCents = null;
  if (max_price !== '') {
    const n = Number(max_price);
    if (!Number.isFinite(n) || n < 0) fail(400, 'O preço máximo deve ser um número válido.');
    maxCents = Math.round(n * 100);
  }
  if (sort && !SORTS.includes(sort)) fail(400, 'Ordenação inválida.');
  const limit = Math.min(Math.max(parseInt(ctx.query.limit, 10) || 20, 1), 50);
  const offset = Math.max(parseInt(ctx.query.offset, 10) || 0, 0);

  let rows = (await publicServices())
    .filter((s) => !category || s.category === category)
    .filter((s) => maxCents === null || s.price_cents <= maxCents);

  // Cada palavra digitada precisa aparecer em algum campo (título, categoria, descrição ou nome do prestador)
  const terms = norm(q).split(/\s+/).filter(Boolean);
  rows = rows.map((r) => {
    const f = { t: norm(r.title), c: norm(r.category), p: norm(r.provider_name), d: norm(r.description) };
    let score = 0;
    for (const term of terms) {
      const s = (f.t.includes(term) ? 3 : 0) + (f.c.includes(term) ? 2 : 0) + (f.p.includes(term) ? 2 : 0) + (f.d.includes(term) ? 1 : 0);
      if (!s) return null;
      score += s;
    }
    return { r, score };
  }).filter(Boolean);

  const cmpName = (a, b) => a.r.title.localeCompare(b.r.title, 'pt-BR');
  const order = sort || (terms.length ? 'relevancia' : 'nome');
  rows.sort(order === 'preco_asc' ? (a, b) => a.r.price_cents - b.r.price_cents || cmpName(a, b)
    : order === 'preco_desc' ? (a, b) => b.r.price_cents - a.r.price_cents || cmpName(a, b)
    : order === 'relevancia' ? (a, b) => b.score - a.score || (b.r.provider_rating || 0) - (a.r.provider_rating || 0) || cmpName(a, b)
    : order === 'nota' ? (a, b) => (b.r.provider_rating || 0) - (a.r.provider_rating || 0) || b.r.provider_reviews - a.r.provider_reviews || cmpName(a, b)
    : cmpName);

  return [200, { total: rows.length, limit, offset, results: rows.slice(offset, offset + limit).map((x) => serviceView(x.r)) }];
});

// Horários já ocupados de um prestador em um dia (sem expor dados de quem agendou)
route('GET', '/api/providers/:id/agenda', { auth: true }, async (ctx) => {
  const day = parseLocal(ctx.query.date, '00:00');
  if (!day) fail(400, 'Informe a data no formato AAAA-MM-DD.');
  const from = day.getTime(), to = from + 24 * 3600e3;
  const rows = (await T.orders.where('provider_id', '==', Number(ctx.params.id)))
    .filter((o) => isActive(o) && o.start_ts < to && o.end_ts > from).sort((a, b) => a.start_ts - b.start_ts);
  return [200, { date: ctx.query.date, busy: rows.map((r) => ({ start: fmtTime(r.start_ts), end: fmtTime(r.end_ts) })) }];
});


// =====================================================================
// 5. AGENDAMENTO / PEDIDOS (regras de negócio)
// =====================================================================
const ACTIVE = ['pendente', 'confirmado'];
const PAYABLE = ['pendente', 'confirmado', 'concluido']; // o cliente já paga ao agendar (se o prestador recusar, o valor é estornado)
const PROTECAO_CENTS = 500;                      // Taxa de Proteção Biko cobrada do cliente (R$ 5,00)
const STATUSES = ['pendente', 'confirmado', 'recusado', 'concluido', 'cancelado'];
const OPEN_HOUR = 7, CLOSE_HOUR = 20;           // atendimento das 07:00 às 20:00
const MIN_LEAD_MS = 60 * 60 * 1000;             // agendar com pelo menos 1 h de antecedência
const MAX_AHEAD_MS = 60 * 24 * 3600e3;          // e no máximo 60 dias à frente
const CLIENT_CANCEL_LIMIT_MS = 2 * 3600e3;      // cliente cancela pedido confirmado até 2 h antes

// Agenda elástica: a duração do serviço é o tempo NORMAL (sem "gordura"). Imprevistos são
// tratados durante o atendimento: o prestador prorroga e os pedidos seguintes são remarcados;
// se terminar antes, concluir libera o restante do horário na hora.
const START_EARLY_MS = 30 * 60e3;               // até 30 min antes: começa "no horário" (a agenda não muda)
// Mais cedo que isso o atendimento é ANTECIPADO: o pedido passa a começar agora e o horário
// antigo fica livre na agenda (ex.: o prestador terminou outro serviço cedo e foi direto ao cliente).
const EXTEND_STEPS = [15, 30, 45, 60];          // prorrogação em blocos de 15 min
const MAX_EXTEND_MIN = 240;                     // no máximo 4 h a mais no total
const HARD_CLOSE_HOUR = 22;                     // imprevisto pode passar das 20h, mas não das 22h
const SHIFT_ROUND_MS = 5 * 60e3;                // remarcações arredondadas para 5 min
// Aviso de atraso: ANTES de iniciar, o prestador avisa o cliente de um imprevisto
// (falta de luz, equipamento quebrado...) e adia o horário (ex.: 11:00 -> 11:30).
const DELAY_STEPS = [15, 30, 45, 60];
const MAX_DELAY_MIN = 240;                      // no máximo 4 h de atraso somado no pedido
const CASCADE_REASON = 'Imprevisto no atendimento anterior';

// ação -> { novo status, quem pode, estados de origem permitidos, se exige motivo }
// atrasar/iniciar/estender não mudam o status (continua "confirmado"), só registram no histórico.
const ACTIONS = {
  confirmar: { to: 'confirmado', from: ['pendente'], who: 'prestador' },
  recusar:   { to: 'recusado',   from: ['pendente'], who: 'prestador', reason: true },
  atrasar:   { to: null,         from: ['pendente', 'confirmado'], who: 'prestador', reason: true },
  iniciar:   { to: 'confirmado', from: ['confirmado'], who: 'prestador' },
  estender:  { to: 'confirmado', from: ['confirmado'], who: 'prestador', reason: true },
  concluir:  { to: 'concluido',  from: ['confirmado'], who: 'prestador' },
  cancelar:  { to: 'cancelado',  from: ['pendente', 'confirmado'], who: 'participante' },
};

const pad = (n) => String(n).padStart(2, '0');
const fmtDate = (ts) => { const d = new Date(ts); return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`; };
function fmtTime(ts) { const d = new Date(ts); return `${pad(d.getHours())}:${pad(d.getMinutes())}`; }
// Converte "AAAA-MM-DD" + "HH:MM" em Date local, rejeitando datas que não existem (ex.: 2026-02-31)
function parseLocal(date, time) {
  const dm = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(date || ''));
  const tm = /^(\d{2}):(\d{2})$/.exec(String(time || ''));
  if (!dm || !tm) return null;
  const [y, mo, d, h, mi] = [dm[1], dm[2], dm[3], tm[1], tm[2]].map(Number);
  const dt = new Date(y, mo - 1, d, h, mi, 0, 0);
  if (dt.getFullYear() !== y || dt.getMonth() !== mo - 1 || dt.getDate() !== d || dt.getHours() !== h || dt.getMinutes() !== mi) return null;
  return dt;
}

// Cliente: pedido confirmado só até 2 h antes, EXCETO se o horário foi remarcado por atraso
// do prestador (aí pode cancelar sem restrição). Atendimento já iniciado não dá para cancelar.
function clientMayCancel(o, t) {
  if (o.status !== 'confirmado') return true;
  if (o.started_ts) return false;
  return o.delay_min > 0 || o.start_ts - t >= CLIENT_CANCEL_LIMIT_MS;
}

function availableActions(o, user, t = now()) {
  const out = [];
  const isProvider = o.provider_id === user.id, isClient = o.client_id === user.id;
  for (const [name, a] of Object.entries(ACTIONS)) {
    if (!a.from.includes(o.status)) continue;
    if (a.who === 'prestador' && !isProvider) continue;
    if (name === 'atrasar' && (o.started_ts || o.delay_min >= MAX_DELAY_MIN || t >= o.end_ts)) continue;
    if (name === 'iniciar' && o.started_ts) continue;
    if (name === 'estender' && (!o.started_ts || o.extended_min >= MAX_EXTEND_MIN)) continue;
    if (name === 'concluir' && !o.started_ts && o.start_ts > t) continue;
    if (name === 'cancelar') {
      if (!(isProvider || isClient || user.role === 'admin')) continue;
      if (isClient && !clientMayCancel(o, t)) continue;
    }
    out.push(name);
  }
  return out;
}

function orderView(o, user) {
  const seeContact = ['confirmado', 'concluido'].includes(o.status) || user.role === 'admin';
  return {
    id: o.id, status: o.status, status_reason: o.status_reason,
    service_id: o.service_id, service_title: o.service_title, category: o.category, price: o.price_cents / 100,
    date: fmtDate(o.start_ts), time: fmtTime(o.start_ts), end_time: fmtTime(o.end_ts), duration_min: Math.round((o.end_ts - o.start_ts) / 60000),
    // agenda elástica
    in_progress: o.status === 'confirmado' && !!o.started_ts,
    started_time: o.started_ts ? fmtTime(o.started_ts) : null,
    planned_end_time: fmtTime(o.planned_end_ts || o.end_ts),
    extended_min: o.extended_min || 0,
    delay_min: o.delay_min || 0,
    original_time: o.delay_min ? fmtTime(o.start_ts - o.delay_min * 60000) : null,
    delay_reason: o.delay_min ? (o.delay_reason || CASCADE_REASON) : null,
    real_duration_min: o.status === 'concluido' && o.started_ts && o.completed_ts ? Math.max(1, Math.round((o.completed_ts - o.started_ts) / 60000)) : null,
    address: o.address, notes: o.notes, created_at: o.created_at,
    client: { id: o.client_id, name: o.client_name, photo_url: photoUrl(o.client_id, o.client_photo_v), phone: seeContact ? o.client_phone : null },
    provider: { id: o.provider_id, name: o.provider_name, photo_url: photoUrl(o.provider_id, o.provider_photo_v), phone: seeContact ? o.provider_phone : null },
    actions: availableActions(o, user),
    // pagamento (simulado, microsserviço pagamentos/)
    payment: o.payment_status ? { status: o.payment_status, code: o.payment_code } : null,
    can_pay: o.client_id === user.id && PAYABLE.includes(o.status) && !['pago', 'estorno_pendente', 'estornado'].includes(o.payment_status),
    protection_fee: PROTECAO_CENTS / 100, total: (o.price_cents + PROTECAO_CENTS) / 100,
  };
}

async function loadOrderFor(user, id) {
  const o = Number.isInteger(id) ? await orderRow(id) : undefined;
  // quem não participa do pedido (e não é admin) recebe 404, como se ele não existisse
  if (!o || !(user.role === 'admin' || o.client_id === user.id || o.provider_id === user.id)) fail(404, 'Pedido não encontrado.');
  return o;
}
async function addEvent(orderId, status, actorId, note) {
  const id = await T.events.insert({ order_id: orderId, status, actor_id: actorId ?? null, note: note || null, created_at: now() });
  // Todo evento do pedido também vai para a caixa de saída do microsserviço de notificações
  await notificador.publicar(id, orderId, status, actorId, note);
}

// O atendimento passou do horário (prorrogação ou início atrasado): empurra os próximos pedidos
// ativos do prestador que agora se sobrepõem, em cascata. Um intervalo livre entre pedidos
// absorve o atraso e a cascata para ali. Cada cliente afetado ganha um registro no histórico
// e pode cancelar sem a regra das 2 h.
async function pushFollowing(o, newEnd) {
  const next = (await T.orders.where('provider_id', '==', o.provider_id))
    .filter((r) => r.id !== o.id && isActive(r) && !r.started_ts && r.start_ts >= o.start_ts)
    .sort((a, b) => a.start_ts - b.start_ts || a.id - b.id);
  let cursor = newEnd, moved = 0;
  for (const r of next) {
    if (r.start_ts >= cursor) break;
    const shift = Math.ceil((cursor - r.start_ts) / SHIFT_ROUND_MS) * SHIFT_ROUND_MS;
    const shiftMin = shift / 60000;
    await T.orders.update(r.id, {
      start_ts: r.start_ts + shift, end_ts: r.end_ts + shift, planned_end_ts: (r.planned_end_ts || r.end_ts) + shift,
      delay_min: (r.delay_min || 0) + shiftMin, delay_reason: CASCADE_REASON, updated_at: now(),
    });
    await addEvent(r.id, 'remarcado', null, `Novo horário ${fmtTime(r.start_ts + shift)}–${fmtTime(r.end_ts + shift)} (+${shiftMin} min por imprevisto no atendimento anterior). O cliente pode cancelar sem custo.`);
    cursor = r.end_ts + shift;
    moved++;
  }
  return moved;
}
const movedNote = (n) => (n ? ` — ${n} pedido(s) seguinte(s) remarcado(s)` : '');

// Duração real dos últimos atendimentos de um serviço (iniciar -> concluir).
// Sugere a MEDIANA arredondada para 15 min: o tempo típico, sem gordura.
// Os imprevistos (minoria) ficam por conta da prorrogação, não da duração cadastrada.
async function serviceStats(serviceId) {
  const rows = (await T.orders.where('service_id', '==', serviceId))
    .filter((o) => o.status === 'concluido' && o.started_ts && o.completed_ts > o.started_ts)
    .sort((a, b) => b.completed_ts - a.completed_ts).slice(0, 20)
    .map((o) => ({ ms: o.completed_ts - o.started_ts, extended_min: o.extended_min || 0 }));
  if (!rows.length) return { count: 0 };
  const mins = rows.map((r) => r.ms / 60000).sort((a, b) => a - b);
  const mid = Math.floor(mins.length / 2);
  const median = mins.length % 2 ? mins[mid] : (mins[mid - 1] + mins[mid]) / 2;
  const avg = mins.reduce((s, m) => s + m, 0) / mins.length;
  const suggested = Math.min(480, Math.max(30, Math.ceil(median / 15) * 15));
  return {
    count: rows.length, avg_min: Math.round(avg), median_min: Math.round(median),
    extended_count: rows.filter((r) => r.extended_min > 0).length,
    suggested_min: rows.length >= 3 ? suggested : null, // com poucos dados não sugere nada
  };
}

route('POST', '/api/orders', { auth: true, roles: ['cliente'] }, async (ctx) => {
  const b = ctx.body;
  const errors = {};
  const serviceId = Number(b.service_id);
  const s = Number.isInteger(serviceId) ? await serviceRow(serviceId) : null;
  if (!s || !s.active || !s.u_active || s.u_role !== 'prestador') fail(404, 'Este serviço não está mais disponível.');
  if (s.provider_id === ctx.user.id) fail(400, 'Você não pode contratar o seu próprio serviço.');

  const start = parseLocal(b.date, b.time);
  const address = typeof b.address === 'string' ? b.address.trim() : '';
  const notes = typeof b.notes === 'string' ? b.notes.trim() : '';
  if (address.length < 5 || address.length > 200) errors.address = 'Informe o endereço do serviço (5 a 200 caracteres).';
  if (notes.length > 500) errors.notes = 'As observações podem ter no máximo 500 caracteres.';
  if (!start) errors.date = 'Informe uma data e um horário válidos.';
  else {
    const t = now(), startTs = start.getTime(), endTs = startTs + s.duration_min * 60000;
    const end = new Date(endTs);
    if (start.getMinutes() % 15 !== 0) errors.time = 'Os horários começam em múltiplos de 15 minutos.';
    else if (startTs < t + MIN_LEAD_MS) errors.time = 'Agende com pelo menos 1 hora de antecedência.';
    else if (startTs > t + MAX_AHEAD_MS) errors.date = 'Só é possível agendar até 60 dias à frente.';
    else if (start.getHours() < OPEN_HOUR || fmtDate(endTs) !== fmtDate(startTs) || end.getHours() > CLOSE_HOUR || (end.getHours() === CLOSE_HOUR && end.getMinutes() > 0)) {
      errors.time = `O atendimento é das ${pad(OPEN_HOUR)}:00 às ${pad(CLOSE_HOUR)}:00 e o serviço dura ${s.duration_min} min.`;
    }
  }
  if (Object.keys(errors).length) fail(400, 'Dados inválidos.', errors);

  const startTs = start.getTime(), endTs = startTs + s.duration_min * 60000;
  // Conflito de horário: nem o prestador nem o cliente podem ter dois pedidos ativos sobrepostos.
  // A checagem e a gravação rodam "uma por vez" (tx): se duas pessoas pedirem o mesmo horário, só uma passa.
  const id = await tx(async () => {
    const overlap = async (col, uid) => (await T.orders.where(col, '==', uid)).some((o) => isActive(o) && o.start_ts < endTs && o.end_ts > startTs);
    if (await overlap('provider_id', s.provider_id)) fail(409, 'O prestador já tem um compromisso nesse horário. Escolha outro.', { time: 'Horário indisponível.' });
    if (await overlap('client_id', ctx.user.id)) fail(409, 'Você já tem outro pedido nesse horário.', { time: 'Você já tem um pedido nesse horário.' });
    const t = now();
    const newId = await T.orders.insert({
      client_id: ctx.user.id, provider_id: s.provider_id, service_id: s.id, service_title: s.title, category: s.category, price_cents: s.price_cents,
      start_ts: startTs, end_ts: endTs, address, notes, status: 'pendente', status_reason: null, completed_ts: null,
      started_ts: null, planned_end_ts: null, extended_min: 0, delay_min: 0, delay_reason: null,
      payment_status: null, payment_id: null, payment_code: null, created_at: t, updated_at: t,
    });
    await addEvent(newId, 'pendente', ctx.user.id, 'Pedido criado');
    return newId;
  });
  return [201, { order: orderView(await orderRow(id), ctx.user) }];
});

route('GET', '/api/orders', { auth: true }, async (ctx) => {
  const { status = '' } = ctx.query;
  if (status && !STATUSES.includes(status)) fail(400, 'Status inválido.');
  const page = parsePage(ctx.query);
  let rows = ctx.user.role === 'cliente' ? await T.orders.where('client_id', '==', ctx.user.id)
    : ctx.user.role === 'prestador' ? await T.orders.where('provider_id', '==', ctx.user.id)
      : await T.orders.all();
  if (status) rows = rows.filter((o) => o.status === status);
  rows.sort(byStartDesc);
  const um = await usersById();
  return [200, { orders: rows.slice(page.offset, page.offset + page.limit).map((o) => orderView(withPeople(o, um), ctx.user)), ...pageInfo(rows.length, page) }];
});

route('GET', '/api/orders/:id', { auth: true }, async (ctx) => {
  const o = await loadOrderFor(ctx.user, Number(ctx.params.id));
  const um = await usersById();
  const history = (await T.events.where('order_id', '==', o.id)).sort((a, b) => a.id - b.id).map((e) => {
    const u = e.actor_id ? um.get(e.actor_id) : null;
    return { status: e.status, note: e.note, created_at: e.created_at, actor_name: u ? u.name : null, actor_role: u ? u.role : null };
  });
  const rv = await T.reviews.first('order_id', '==', o.id);
  const review = rv ? { stars: rv.stars, comment: rv.comment } : null;
  return [200, { order: { ...orderView(o, ctx.user), history, review, can_review: !rv && o.status === 'concluido' && o.client_id === ctx.user.id, client_since: (um.get(o.client_id) || {}).created_at || null } }];
});

route('POST', '/api/orders/:id/status', { auth: true }, async (ctx) => {
  const action = String(ctx.body.action || '');
  const a = ACTIONS[action];
  if (!a) fail(400, 'Ação inválida.');
  const reason = typeof ctx.body.reason === 'string' ? ctx.body.reason.trim() : '';
  const id = await tx(async () => {
    const o = await loadOrderFor(ctx.user, Number(ctx.params.id));
    const isProvider = o.provider_id === ctx.user.id, isClient = o.client_id === ctx.user.id;
    // 1) quem pode fazer a ação
    if (a.who === 'prestador' && !isProvider) fail(403, 'Só o prestador deste pedido pode fazer isso.');
    if (action === 'cancelar' && !(isProvider || isClient || ctx.user.role === 'admin')) fail(403, 'Você não pode cancelar este pedido.');
    // 2) o status atual permite? (pedido encerrado não muda mais)
    if (!a.from.includes(o.status)) fail(409, `Não é possível ${action} um pedido que está "${o.status}".`);
    // 3) regras de cada ação
    const t = now();
    if (action === 'concluir' && !o.started_ts && o.start_ts > t) fail(400, 'Só é possível concluir depois do horário agendado.');
    if (action === 'cancelar' && isClient && !clientMayCancel(o, t)) {
      fail(400, o.started_ts ? 'O atendimento já começou. Fale com o prestador.' : 'Pedido confirmado só pode ser cancelado pelo cliente até 2 horas antes. Fale com o prestador.');
    }
    const needReason = a.reason || (action === 'cancelar' && !isClient);
    if (needReason && reason.length < 3) fail(400, 'Informe o motivo.', { reason: 'Informe o motivo (mín. 3 caracteres).' });
    if (reason.length > 200) fail(400, 'O motivo pode ter no máximo 200 caracteres.', { reason: 'Máximo de 200 caracteres.' });

    if (action === 'atrasar') {
      if (o.started_ts) fail(409, 'O atendimento já começou. Use "Preciso de mais tempo".');
      if (t >= o.end_ts) fail(400, 'O horário deste pedido já passou.');
      const min = Number(ctx.body.minutes);
      if (!DELAY_STEPS.includes(min)) fail(400, 'Escolha de quanto será o atraso.', { minutes: `Escolha ${DELAY_STEPS.join(', ')} minutos.` });
      if (o.delay_min + min > MAX_DELAY_MIN) fail(400, `O pedido pode ser adiado no máximo ${MAX_DELAY_MIN / 60} h no total. Combine outro dia com o cliente.`, { minutes: 'Limite de atraso atingido.' });
      const newStart = o.start_ts + min * 60000, newEnd = o.end_ts + min * 60000;
      if (newStart < t) fail(400, 'O novo horário já passou. Escolha um atraso maior.', { minutes: 'O novo horário já passou.' });
      const limit = new Date(o.start_ts); limit.setHours(HARD_CLOSE_HOUR, 0, 0, 0);
      if (newEnd > limit.getTime()) fail(400, `Com esse atraso o serviço passaria das ${HARD_CLOSE_HOUR}:00. Combine outro dia com o cliente.`, { minutes: `Passaria das ${HARD_CLOSE_HOUR}:00.` });
      await T.orders.update(o.id, {
        start_ts: newStart, end_ts: newEnd, planned_end_ts: o.planned_end_ts ? o.planned_end_ts + min * 60000 : null,
        delay_min: (o.delay_min || 0) + min, delay_reason: reason, updated_at: t,
      });
      const moved = await pushFollowing(o, newEnd);
      await addEvent(o.id, 'atrasado', ctx.user.id, `Novo horário ${fmtTime(newStart)}–${fmtTime(newEnd)} (+${min} min): ${reason}. O cliente pode cancelar sem custo${movedNote(moved)}`);
      return o.id;
    }

    if (action === 'iniciar') {
      if (o.started_ts) fail(409, 'Este atendimento já foi iniciado.');
      const busy = (await T.orders.where('provider_id', '==', o.provider_id)).some((r) => r.id !== o.id && r.status === 'confirmado' && r.started_ts);
      if (busy) fail(409, 'Você já tem um atendimento em andamento. Conclua ele antes de iniciar outro.');
      const plannedMs = (o.planned_end_ts || o.end_ts) - o.start_ts;
      if (t < o.start_ts - START_EARLY_MS) {
        // ANTECIPADO: o atendimento passa a ser de agora até agora + duração normal
        const newStart = t, newEnd = t + plannedMs;
        const clash = async (col, uid) => (await T.orders.where(col, '==', uid)).some((r) => r.id !== o.id && isActive(r) && r.start_ts < newEnd && r.end_ts > newStart);
        if (await clash('provider_id', o.provider_id)) fail(409, 'Você tem outro pedido nesse intervalo. Não dá para antecipar este agora.');
        if (await clash('client_id', o.client_id)) fail(409, 'O cliente tem outro pedido nesse intervalo. Não dá para antecipar este agora.');
        await T.orders.update(o.id, { started_ts: t, start_ts: newStart, end_ts: newEnd, planned_end_ts: newEnd, updated_at: t });
        const d = new Date(o.start_ts);
        await addEvent(o.id, 'iniciado', ctx.user.id, `Atendimento antecipado: estava marcado para ${pad(d.getDate())}/${pad(d.getMonth() + 1)} às ${fmtTime(o.start_ts)} e começou agora (previsão de término ${fmtTime(newEnd)}). O horário antigo ficou livre na agenda`);
        return o.id;
      }
      // Começou atrasado: o tempo do serviço conta a partir do início real, e quem vem depois é remarcado.
      const newEnd = Math.max(o.end_ts, t + plannedMs);
      const lateMin = Math.max(0, Math.round((t - o.start_ts) / 60000));
      await T.orders.update(o.id, { started_ts: t, planned_end_ts: o.planned_end_ts || o.end_ts, end_ts: newEnd, updated_at: t });
      const moved = newEnd > o.end_ts ? await pushFollowing(o, newEnd) : 0;
      await addEvent(o.id, 'iniciado', ctx.user.id, (lateMin >= 5 ? `Atendimento iniciado com ${lateMin} min de atraso` : 'Atendimento iniciado') + movedNote(moved));
      return o.id;
    }

    if (action === 'estender') {
      if (!o.started_ts) fail(400, 'Inicie o atendimento antes de pedir mais tempo.');
      const min = Number(ctx.body.minutes);
      if (!EXTEND_STEPS.includes(min)) fail(400, 'Escolha quanto tempo a mais.', { minutes: `Escolha ${EXTEND_STEPS.join(', ')} minutos.` });
      if (o.extended_min + min > MAX_EXTEND_MIN) fail(400, `O atendimento pode ser prorrogado no máximo ${MAX_EXTEND_MIN / 60} h no total.`, { minutes: 'Limite de prorrogação atingido.' });
      const newEnd = o.end_ts + min * 60000;
      const limit = new Date(o.start_ts); limit.setHours(HARD_CLOSE_HOUR, 0, 0, 0);
      if (newEnd > limit.getTime()) fail(400, `Não dá para passar das ${HARD_CLOSE_HOUR}:00. Conclua e combine um retorno com o cliente.`, { minutes: `Passaria das ${HARD_CLOSE_HOUR}:00.` });
      await T.orders.update(o.id, { planned_end_ts: o.planned_end_ts || o.end_ts, end_ts: newEnd, extended_min: (o.extended_min || 0) + min, updated_at: t });
      const moved = await pushFollowing(o, newEnd);
      await addEvent(o.id, 'prorrogado', ctx.user.id, `+${min} min (novo término ${fmtTime(newEnd)}): ${reason}${movedNote(moved)}`);
      return o.id;
    }

    let note = reason || null;
    if (action === 'concluir') {
      // Terminou antes do previsto: como pedido concluído não ocupa a agenda, o restante já fica livre.
      const freed = Math.floor((o.end_ts - t) / 60000);
      if (freed >= 5) note = `Concluído ${freed} min antes do previsto — horário liberado na agenda`;
    }
    const patch = { status: a.to, status_reason: reason || null, completed_ts: a.to === 'concluido' ? t : null, updated_at: t };
    // Pedido já pago foi cancelado: o dinheiro volta para o cliente (estorno no microsserviço de pagamentos)
    if ((a.to === 'cancelado' || a.to === 'recusado') && o.payment_status === 'pago') { patch.payment_status = 'estorno_pendente'; estornoActor.set(o.id, ctx.user.id); }
    await T.orders.update(o.id, patch);
    await addEvent(o.id, a.to, ctx.user.id, note);
    return o.id;
  });
  await processarEstornos();
  return [200, { order: orderView(await orderRow(id), ctx.user) }];
});

// =====================================================================
// NOTIFICAÇÕES (quem guarda e monta as notificações é o MICROSSERVIÇO da pasta notificacoes/;
// aqui a API só confere quem está logado e repassa o pedido com o id dessa pessoa)
// =====================================================================
async function notif(method, pathname, body) {
  try {
    const r = await notificador.chamar(method, pathname, body);
    if (r.status >= 400) fail(r.status === 401 ? 502 : r.status, r.data.error || 'Erro no serviço de notificações.');
    return r.data;
  } catch (e) {
    if (e instanceof notificador.ServicoForaDoAr) fail(503, 'As notificações estão fora do ar agora. O resto do Biko continua funcionando normalmente.');
    throw e;
  }
}
const notifBase = (ctx) => `/usuarios/${ctx.user.id}/notificacoes`;

route('GET', '/api/notificacoes', { auth: true }, async (ctx) => {
  await notificador.flush().catch(() => {}); // entrega o que estiver pendente antes de listar
  const qs = new URLSearchParams();
  for (const k of ['limit', 'offset', 'nao_lidas']) if (ctx.query[k] !== undefined) qs.set(k, ctx.query[k]);
  return [200, await notif('GET', `${notifBase(ctx)}${qs.size ? '?' + qs : ''}`)];
});
route('GET', '/api/notificacoes/contagem', { auth: true }, async (ctx) => {
  await notificador.flush().catch(() => {});
  return [200, await notif('GET', `${notifBase(ctx)}/contagem`)];
});
route('POST', '/api/notificacoes/lidas', { auth: true }, async (ctx) => [200, await notif('POST', `${notifBase(ctx)}/lidas`, {})]);
route('POST', '/api/notificacoes/:id/lida', { auth: true }, async (ctx) => {
  if (!/^\d+$/.test(ctx.params.id)) fail(404, 'Notificação não encontrada.');
  return [200, await notif('POST', `${notifBase(ctx)}/${ctx.params.id}/lida`, {})];
});

// =====================================================================
// PAGAMENTOS / VENDAS (SIMULADO — quem guarda as cobranças é o MICROSSERVIÇO da pasta pagamentos/;
// nenhum dinheiro de verdade é movimentado, serve só para a apresentação)
// =====================================================================
const pagUrl = () => process.env.PAG_URL || 'http://127.0.0.1:3002';
const PAG_KEY = process.env.PAG_KEY || 'biko-dev-key';
async function pag(method, pathname, body) {
  try {
    const r = await chamarServico(pagUrl(), PAG_KEY, method, pathname, body);
    if (r.status >= 400) fail(r.status === 401 ? 502 : r.status, r.data.error || 'Erro no serviço de pagamentos.');
    return r.data;
  } catch (e) {
    if (e instanceof ServicoForaDoAr) fail(503, 'O pagamento está fora do ar agora. Tente de novo em instantes; o pedido continua valendo.');
    throw e;
  }
}
const brl = (v) => 'R$ ' + Number(v).toFixed(2).replace('.', ',');

// Guarda no pedido o que o microsserviço respondeu. Se aprovou agora, entra no histórico
// do pedido (e por tabela vira a notificação "Pagamento recebido" para o prestador).
async function aplicarCobranca(orderId, c, actorId) {
  await tx(async () => {
    const o = await T.orders.get(orderId);
    const status = c.status === 'aprovado' ? 'pago' : c.status;
    await T.orders.update(orderId, { payment_status: status, payment_id: c.id, payment_code: c.codigo, updated_at: now() });
    if (status === 'pago' && o.payment_status !== 'pago') {
      const forma = c.metodo === 'cartao' ? `cartão ${c.cartao.bandeira} final ${c.cartao.final}${c.parcelas > 1 ? ` em ${c.parcelas}x` : ''}` : 'Pix';
      await addEvent(orderId, 'pago', actorId, `${brl(c.valor)} via ${forma} — comprovante ${c.codigo}`);
    }
  });
}

// Estornos pendentes (pedido pago que foi cancelado). Se o microsserviço estiver fora do ar,
// tenta de novo depois — o pedido fica como "estorno_pendente" até dar certo.
const estornoActor = new Map();
let estornando = false;
async function processarEstornos() {
  if (estornando) return;
  estornando = true;
  try {
    const pend = (await T.orders.where('payment_status', '==', 'estorno_pendente')).slice(0, 20);
    for (const o of pend) {
      let c;
      try { c = (await chamarServico(pagUrl(), PAG_KEY, 'POST', `/cobrancas/${o.payment_id}/estornar`, { motivo: o.status_reason || 'Pedido cancelado' })).data.cobranca; }
      catch (e) { return; } // fora do ar: tenta na próxima
      if (!c) continue;
      await T.orders.update(o.id, { payment_status: 'estornado' });
      await addEvent(o.id, 'estornado', estornoActor.get(o.id) ?? null, `${brl(c.valor)} devolvido ao cliente (${c.codigo})`);
      estornoActor.delete(o.id);
    }
  } finally { estornando = false; }
}

// O cliente paga o pedido: Pix (fica aguardando) ou cartão (aprova/recusa na hora).
// Do cartão só chega o FINAL (4 dígitos), a bandeira e as parcelas — o número inteiro nunca sai do navegador.
route('POST', '/api/orders/:id/pagamento', { auth: true, roles: ['cliente'] }, async (ctx) => {
  const o = await loadOrderFor(ctx.user, Number(ctx.params.id));
  if (o.client_id !== ctx.user.id) fail(403, 'Só o cliente do pedido pode pagar.');
  if (!PAYABLE.includes(o.status)) fail(409, 'Só dá para pagar depois que o prestador confirmar o pedido.');
  if (['pago', 'estorno_pendente', 'estornado'].includes(o.payment_status)) fail(409, 'Este pedido já foi pago.');
  const { metodo, cartao } = ctx.body;
  if (!['pix', 'cartao'].includes(metodo)) fail(400, 'Escolha Pix ou cartão.', { metodo: 'Escolha a forma de pagamento.' });
  let card = null;
  if (metodo === 'cartao') {
    const c = cartao || {};
    if (!/^\d{4}$/.test(String(c.final || ''))) fail(400, 'Dados do cartão inválidos.', { cartao: 'Informe o número do cartão.' });
    card = { final: String(c.final), bandeira: c.bandeira, parcelas: Number(c.parcelas || 1) };
  }
  const { cobranca } = await pag('POST', '/cobrancas', {
    pedido_id: o.id, descricao: o.service_title, valor_centavos: o.price_cents + PROTECAO_CENTS, taxa_protecao_centavos: PROTECAO_CENTS,
    pagador_id: o.client_id, pagador_nome: o.client_name, recebedor_id: o.provider_id, recebedor_nome: o.provider_name,
    metodo, cartao: card,
  });
  await aplicarCobranca(o.id, cobranca, ctx.user.id);
  return [201, { cobranca, order: orderView(await orderRow(o.id), ctx.user) }];
});

// "Simular pagamento" do Pix (na vida real quem avisa é o banco)
route('POST', '/api/orders/:id/pagamento/confirmar', { auth: true, roles: ['cliente'] }, async (ctx) => {
  const o = await loadOrderFor(ctx.user, Number(ctx.params.id));
  if (o.client_id !== ctx.user.id) fail(403, 'Só o cliente do pedido pode pagar.');
  if (!o.payment_id) fail(404, 'Nenhum pagamento iniciado para este pedido.');
  const { cobranca } = await pag('POST', `/cobrancas/${o.payment_id}/confirmar`, {});
  await aplicarCobranca(o.id, cobranca, ctx.user.id);
  return [200, { cobranca, order: orderView(await orderRow(o.id), ctx.user) }];
});

// Comprovante / situação do pagamento de um pedido (cliente, prestador do pedido e admin)
route('GET', '/api/orders/:id/pagamento', { auth: true }, async (ctx) => {
  const o = await loadOrderFor(ctx.user, Number(ctx.params.id));
  if (!o.payment_id) return [200, { cobranca: null }];
  const { cobranca } = await pag('GET', `/cobrancas/${o.payment_id}`);
  if (o.client_id !== ctx.user.id) cobranca.pix_copia_cola = null; // só quem paga vê o código Pix
  return [200, { cobranca }];
});

// Vendas: cliente vê o que pagou, prestador o que vendeu (com a taxa da plataforma), admin vê tudo
route('GET', '/api/pagamentos', { auth: true }, async (ctx) => {
  await processarEstornos();
  const qs = new URLSearchParams();
  if (ctx.user.role === 'cliente') qs.set('pagador_id', ctx.user.id);
  else if (ctx.user.role === 'prestador') qs.set('recebedor_id', ctx.user.id);
  const page = parsePage(ctx.query, 20, 100);
  qs.set('limit', page.limit); qs.set('offset', page.offset);
  const d = await pag('GET', `/cobrancas?${qs}`);
  if (ctx.user.role !== 'cliente') d.cobrancas.forEach((c) => (c.pix_copia_cola = null));
  return [200, d];
});

// =====================================================================
// TELAS NOVAS DO FIGMA: conversas, avaliações, perfil profissional, portfólio e carteira
// =====================================================================

// ----- Verificação do profissional -----
// CPF: confere os dois dígitos verificadores (o mesmo cálculo da Receita)
function cpfValido(cpf) {
  if (!/^\d{11}$/.test(cpf) || /^(\d)\1{10}$/.test(cpf)) return false;
  const dig = (n) => {
    let s = 0;
    for (let i = 0; i < n; i++) s += Number(cpf[i]) * (n + 1 - i);
    const r = (s * 10) % 11;
    return r === 10 ? 0 : r;
  };
  return dig(9) === Number(cpf[9]) && dig(10) === Number(cpf[10]);
}
// "AAAA-MM-DD" ou "DD/MM/AAAA" -> idade em anos (null se a data não existe ou está no futuro)
function idade(str) {
  let m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(str), y, mo, d;
  if (m) [y, mo, d] = [m[1], m[2], m[3]].map(Number);
  else if ((m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(str))) [d, mo, y] = [m[1], m[2], m[3]].map(Number);
  else return null;
  const dt = new Date(y, mo - 1, d);
  if (dt.getFullYear() !== y || dt.getMonth() !== mo - 1 || dt.getDate() !== d || dt > new Date() || y < 1900) return null;
  const t = new Date();
  let a = t.getFullYear() - y;
  if (t.getMonth() < mo - 1 || (t.getMonth() === mo - 1 && t.getDate() < d)) a--;
  return a;
}
route('POST', '/api/auth/verificar-profissional', {}, (ctx) => {
  // usado pela tela "Verificação do Profissional" para mostrar a idade antes de enviar
  const cpf = String(ctx.body.cpf || '').replace(/\D/g, '');
  const age = idade(String(ctx.body.birth_date || ''));
  return [200, { cpf_ok: cpfValido(cpf), idade: age, maior: age !== null && age >= 18 }];
});

// ----- Conversas (chat entre cliente e prestador) -----
const otherView = (u) => ({ id: u.id, name: u.name, role: u.role, photo_url: photoUrl(u.id, u.photo_v), specialty: u.specialty || null, online: u.role === 'prestador' ? u.online !== 0 : true });
// Uma conversa é sempre entre um cliente e um prestador (o admin só observa pelos pedidos)
async function parConversa(me, otherId) {
  if (me.role === 'admin') fail(403, 'O admin não participa das conversas.');
  const other = Number.isInteger(otherId) ? await T.users.get(otherId) : undefined;
  if (!other || !other.active || other.id === me.id) fail(404, 'Pessoa não encontrada.');
  const okPair = (me.role === 'cliente' && other.role === 'prestador') || (me.role === 'prestador' && other.role === 'cliente');
  if (!okPair) fail(400, 'A conversa é entre cliente e prestador.');
  return { other, client_id: me.role === 'cliente' ? me.id : other.id, provider_id: me.role === 'prestador' ? me.id : other.id };
}
const meuLado = (me) => (me.role === 'cliente' ? 'client_id' : 'provider_id');

route('GET', '/api/conversas', { auth: true, roles: ['cliente', 'prestador'] }, async (ctx) => {
  const me = ctx.user;
  const msgs = (await T.messages.where(meuLado(me), '==', me.id)).sort((a, b) => a.id - b.id);
  const byOther = new Map();
  for (const m of msgs) {
    const oid = me.role === 'cliente' ? m.provider_id : m.client_id;
    const c = byOther.get(oid) || { unread: 0 };
    c.last = m;
    if (m.sender_id !== me.id && !m.read) c.unread++;
    byOther.set(oid, c);
  }
  const um = await usersById();
  const list = [...byOther.entries()].filter(([oid]) => um.get(oid)).map(([oid, c]) => ({
    user: otherView(um.get(oid)), unread: c.unread,
    last: { text: c.last.text, mine: c.last.sender_id === me.id, created_at: c.last.created_at },
  })).sort((a, b) => b.last.created_at - a.last.created_at);
  return [200, { conversas: list, nao_lidas: list.reduce((s, c) => s + c.unread, 0) }];
});

route('GET', '/api/conversas/:id', { auth: true, roles: ['cliente', 'prestador'] }, async (ctx) => {
  const p = await parConversa(ctx.user, Number(ctx.params.id));
  const msgs = (await T.messages.where('client_id', '==', p.client_id, 'provider_id', '==', p.provider_id)).sort((a, b) => a.id - b.id);
  for (const m of msgs) if (m.sender_id !== ctx.user.id && !m.read) await T.messages.update(m.id, { read: 1 }); // abriu = leu
  // próximo pedido ativo entre os dois (para o atalho de agenda e o telefone depois de confirmado)
  const prox = (await T.orders.where('client_id', '==', p.client_id)).filter((o) => o.provider_id === p.provider_id && isActive(o)).sort((a, b) => a.start_ts - b.start_ts)[0];
  const phone = prox && prox.status === 'confirmado' ? p.other.phone : null;
  return [200, {
    other: { ...otherView(p.other), phone },
    next_order: prox ? { id: prox.id, date: fmtDate(prox.start_ts), time: fmtTime(prox.start_ts), status: prox.status, title: prox.service_title } : null,
    messages: msgs.slice(-200).map((m) => ({ id: m.id, text: m.text, mine: m.sender_id === ctx.user.id, created_at: m.created_at })),
  }];
});

route('POST', '/api/conversas/:id', { auth: true, roles: ['cliente', 'prestador'] }, async (ctx) => {
  const p = await parConversa(ctx.user, Number(ctx.params.id));
  const text = typeof ctx.body.texto === 'string' ? ctx.body.texto.trim() : '';
  if (!text) fail(400, 'Escreva uma mensagem.', { texto: 'Escreva uma mensagem.' });
  if (text.length > 1000) fail(400, 'A mensagem pode ter no máximo 1000 caracteres.', { texto: 'Máximo de 1000 caracteres.' });
  const id = await T.messages.insert({ client_id: p.client_id, provider_id: p.provider_id, sender_id: ctx.user.id, text, read: 0, created_at: now() });
  return [201, { message: { id, text, mine: true, created_at: now() } }];
});

// ----- Avaliação (cliente avalia depois do serviço concluído) -----
route('POST', '/api/orders/:id/avaliacao', { auth: true, roles: ['cliente'] }, async (ctx) => {
  const o = await loadOrderFor(ctx.user, Number(ctx.params.id));
  if (o.client_id !== ctx.user.id) fail(403, 'Só o cliente do pedido pode avaliar.');
  if (o.status !== 'concluido') fail(409, 'Só dá para avaliar depois que o serviço for concluído.');
  const stars = Number(ctx.body.nota);
  if (!Number.isInteger(stars) || stars < 1 || stars > 5) fail(400, 'Dê uma nota de 1 a 5 estrelas.', { nota: 'Escolha de 1 a 5 estrelas.' });
  const comment = typeof ctx.body.comentario === 'string' ? ctx.body.comentario.trim().slice(0, 300) : '';
  await tx(async () => {
    if (await T.reviews.first('order_id', '==', o.id)) fail(409, 'Você já avaliou este serviço.');
    await T.reviews.insert({ order_id: o.id, provider_id: o.provider_id, client_id: o.client_id, stars, comment, created_at: now() });
  });
  return [201, { review: { stars, comment } }];
});

// ----- Perfil profissional -----
async function perfilPublico(u) {
  const r = (await ratingsByProvider()).get(u.id);
  const services = (await T.services.where('provider_id', '==', u.id)).filter((s) => s.active && (!u.categories || u.categories.includes(s.category)));
  const fotos = (await T.portfolio.where('provider_id', '==', u.id)).sort((a, b) => a.id - b.id);
  const reviews = (await T.reviews.where('provider_id', '==', u.id)).sort((a, b) => b.id - a.id).slice(0, 5);
  const um = await usersById();
  return {
    ...otherView(u), verified: !!u.cpf, visit_price: u.visit_price_cents ? u.visit_price_cents / 100 : null, categories: u.categories || null,
    rating: r ? r.avg : null, reviews_count: r ? r.count : 0,
    reviews: reviews.map((x) => ({ stars: x.stars, comment: x.comment, client_name: (um.get(x.client_id) || {}).name || 'Cliente' })),
    services: services.map((s) => ({ id: s.id, title: s.title, category: s.category, price: s.price_cents / 100, duration_min: s.duration_min })),
    portfolio: fotos.map((f) => ({ id: f.id, url: `/api/portfolio/${f.id}/foto` })),
  };
}
route('GET', '/api/prestadores/:id', { auth: true }, async (ctx) => {
  const u = await T.users.get(Number(ctx.params.id));
  if (!u || u.role !== 'prestador' || !u.active) fail(404, 'Profissional não encontrado.');
  return [200, { prestador: await perfilPublico(u) }];
});
route('GET', '/api/me/profissional', { auth: true, roles: ['prestador'] }, async (ctx) => [200, { prestador: await perfilPublico(ctx.user) }]);

route('PATCH', '/api/me/profissional', { auth: true, roles: ['prestador'] }, async (ctx) => {
  const b = ctx.body, patch = {}, errors = {};
  if (b.specialty !== undefined) {
    const sp = String(b.specialty || '').trim();
    if (sp.length > 60) errors.specialty = 'Máximo de 60 caracteres.'; else patch.specialty = sp || null;
  }
  if (b.visit_price !== undefined) {
    const v = Number(String(b.visit_price).replace(',', '.'));
    if (!Number.isFinite(v) || v <= 0 || v > 100000) errors.visit_price = 'Informe um valor entre R$ 0,01 e R$ 100.000.';
    else patch.visit_price_cents = Math.round(v * 100);
  }
  if (b.online !== undefined) patch.online = b.online ? 1 : 0;
  if (b.categories !== undefined) {
    if (!Array.isArray(b.categories) || b.categories.some((c) => !CATEGORY_NAMES.includes(c))) errors.categories = 'Categoria inválida.';
    else patch.categories = [...new Set(b.categories)];
  }
  if (Object.keys(errors).length) fail(400, 'Dados inválidos.', errors);
  if (Object.keys(patch).length) await T.users.update(ctx.user.id, patch);
  const u = await T.users.get(ctx.user.id);
  return [200, { user: publicUser(u), prestador: await perfilPublico(u) }];
});

// ----- Portfólio de trabalhos (fotos, até 6) -----
route('POST', '/api/me/portfolio', { auth: true, roles: ['prestador'], bodyLimit: 400 * 1024 }, async (ctx) => {
  const m = /^data:(image\/[a-z]+);base64,([A-Za-z0-9+/=]+)$/.exec(String(ctx.body.image || ''));
  if (!m || !PHOTO_TYPES[m[1]]) fail(400, 'Envie uma imagem PNG, JPG ou WEBP.');
  const buf = Buffer.from(m[2], 'base64');
  if (!buf.length) fail(400, 'Imagem vazia.');
  if (buf.length > MAX_PHOTO_BYTES) fail(413, 'A foto deve ter no máximo 200 KB.');
  const real = sniffImage(buf);
  if (!real) fail(400, 'O arquivo enviado não é uma imagem válida.');
  if ((await T.portfolio.where('provider_id', '==', ctx.user.id)).length >= 6) fail(409, 'O portfólio aceita até 6 fotos. Remova uma para adicionar outra.');
  const id = await T.portfolio.insert({ provider_id: ctx.user.id, mime: real, data: buf, created_at: now() });
  return [201, { foto: { id, url: `/api/portfolio/${id}/foto` } }];
});
route('DELETE', '/api/me/portfolio/:id', { auth: true, roles: ['prestador'] }, async (ctx) => {
  const f = await T.portfolio.get(Number(ctx.params.id));
  if (!f || f.provider_id !== ctx.user.id) fail(404, 'Foto não encontrada.');
  await T.portfolio.remove(f.id);
  return [200, { ok: true }];
});
route('GET', '/api/portfolio/:id/foto', { auth: true }, async (ctx) => {
  const f = await T.portfolio.get(Number(ctx.params.id));
  if (!f) fail(404, 'Foto não encontrada.');
  return [200, Buffer.from(f.data), { contentType: f.mime }];
});

// ----- Ganhos e Carteira (prestador) — SIMULADO, usa as cobranças do microsserviço de pagamentos -----
async function carteira(user) {
  const d = new Date(), monthStart = new Date(d.getFullYear(), d.getMonth(), 1).getTime();
  const pagos = (await pag('GET', `/cobrancas?recebedor_id=${user.id}&limit=100`)).cobrancas.filter((c) => c.status === 'aprovado');
  const orders = new Map((await T.orders.where('provider_id', '==', user.id)).map((o) => [o.id, o]));
  const saques = (await T.withdrawals.where('provider_id', '==', user.id));
  const cents = (v) => Math.round(v * 100);
  let liberado = 0, pendente = 0, mes = 0;
  for (const c of pagos) {
    const o = orders.get(c.pedido_id);
    if (o && o.status === 'concluido') liberado += cents(c.liquido); else pendente += cents(c.liquido);
    if ((c.pago_em || 0) >= monthStart) mes += cents(c.liquido);
  }
  const sacado = saques.reduce((s, w) => s + w.valor_centavos, 0);
  const historico = [
    ...pagos.map((c) => ({ tipo: 'entrada', titulo: c.descricao, valor: c.liquido, quando: c.pago_em || c.criada_em, liberado: (orders.get(c.pedido_id) || {}).status === 'concluido' })),
    ...saques.map((w) => ({ tipo: 'saque', titulo: 'Saque Pix efetuado', valor: w.valor_centavos / 100, quando: w.created_at })),
  ].sort((a, b) => b.quando - a.quando).slice(0, 20);
  return { disponivel: (liberado - sacado) / 100, pendente: pendente / 100, este_mes: mes / 100, historico, chave_pix: user.email };
}
route('GET', '/api/carteira', { auth: true, roles: ['prestador'] }, async (ctx) => [200, await carteira(ctx.user)]);
route('POST', '/api/carteira/saque', { auth: true, roles: ['prestador'] }, async (ctx) => {
  const valor = Number(String(ctx.body.valor ?? '').replace(',', '.'));
  if (!Number.isFinite(valor) || valor <= 0) fail(400, 'Informe o valor do saque.', { valor: 'Informe um valor maior que zero.' });
  const out = await tx(async () => {
    const c = await carteira(ctx.user);
    if (Math.round(valor * 100) > Math.round(c.disponivel * 100)) fail(400, `Você tem ${brl(c.disponivel)} disponível para saque.`, { valor: 'Valor maior que o saldo disponível.' });
    await T.withdrawals.insert({ provider_id: ctx.user.id, valor_centavos: Math.round(valor * 100), created_at: now(), pix: ctx.user.email });
    return carteira(ctx.user);
  });
  return [201, { ...out, mensagem: `Transferência de ${brl(valor)} enviada via Pix (simulação).` }];
});

// ---------- arquivos estáticos ----------
const MIME = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon' };
function serveStatic(req, res, pathname) {
  let rel = decodeURIComponent(pathname);
  if (rel === '/') rel = '/index.html';
  const file = path.normalize(path.join(PUBLIC_DIR, rel));
  if (!file.startsWith(PUBLIC_DIR + path.sep)) { res.writeHead(403); return res.end('Forbidden'); } // evita ../
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }); return res.end('Não encontrado'); }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}

// ---------- CORS ----------
// O app Flutter rodando no Chrome (flutter run -d chrome) fica em outra porta do localhost,
// então o navegador só deixa ele chamar a API se o servidor autorizar a origem.
// Em desenvolvimento: qualquer porta de localhost/127.0.0.1. Em produção: só o que estiver em CORS_ORIGINS.
// Não liberamos credenciais (cookies): o app usa token Bearer, então outra origem não aproveita a sessão do site.
const DEV_ORIGIN_RE = /^http:\/\/(localhost|127\.0\.0\.1)(:\d{1,5})?$/;
const EXTRA_ORIGINS = (process.env.CORS_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean);
function corsHeaders(req) {
  const origin = req.headers.origin;
  const allowed = origin && (EXTRA_ORIGINS.includes(origin) || (process.env.NODE_ENV !== 'production' && DEV_ORIGIN_RE.test(origin)));
  return allowed ? { 'Access-Control-Allow-Origin': origin, Vary: 'Origin' } : {};
}

// ---------- servidor ----------
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (!url.pathname.startsWith('/api/')) {
    if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405); return res.end(); }
    return serveStatic(req, res, url.pathname);
  }
  const cors = corsHeaders(req);
  // Preflight: o navegador pergunta antes de mandar Authorization / X-Client / JSON
  if (req.method === 'OPTIONS') {
    if (!cors['Access-Control-Allow-Origin']) { res.writeHead(403); return res.end(); }
    res.writeHead(204, {
      ...cors,
      'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type, X-Client',
      'Access-Control-Max-Age': '600',
    });
    return res.end();
  }
  const ctx = { req, res, headers: { ...cors }, query: Object.fromEntries(url.searchParams), params: {}, body: {} };
  try {
    let matched = null;
    for (const r of routes) {
      if (r.method !== req.method) continue;
      const m = r.re.exec(url.pathname);
      if (m) { matched = r; r.keys.forEach((k, i) => (ctx.params[k] = decodeURIComponent(m[i + 1]))); break; }
    }
    if (!matched) fail(404, 'Rota não encontrada.');
    if (req.method !== 'GET') {
      ctx.body = await readBody(req, matched.opts.bodyLimit);
      if (typeof ctx.body !== 'object' || ctx.body === null || Array.isArray(ctx.body)) fail(400, 'JSON inválido.');
    }
    await pronto; // dados de exemplo já gravados no Firestore
    if (matched.opts.auth) await authenticate(ctx);
    if (matched.opts.roles && !matched.opts.roles.includes(ctx.user.role)) fail(403, 'Você não tem permissão para acessar este recurso.');
    const [status, data, extra] = await matched.handler(ctx); // algumas rotas (notificações) são assíncronas
    if (Buffer.isBuffer(data)) sendBinary(res, status, data, extra.contentType, ctx.headers);
    else send(res, status, data, ctx.headers);
  } catch (err) {
    if (err instanceof HttpError) return send(res, err.status, { error: err.message, fields: err.fields }, ctx.headers);
    console.error(err);
    send(res, 500, { error: 'Erro interno do servidor.' }, cors);
  }
});

const PORT = process.env.PORT || 3000;
// Enquanto o servidor estiver no ar, a caixa de saída é entregue ao microsserviço a cada 2 s
let estornoTimer = null;
server.on('listening', () => {
  console.log(`Banco: ${modoFirestore()}`);
  pronto.then(() => notificador.preencherInicial()).catch((e) => console.error('[notificações]', e.message));
  notificador.iniciar();
  estornoTimer = setInterval(() => processarEstornos().catch(() => {}), 10000);
  estornoTimer.unref();
});
server.on('close', () => { notificador.parar(); clearInterval(estornoTimer); });
if (require.main === module) {
  server.listen(PORT, () => console.log(`Biko rodando em http://localhost:${PORT}`));
}
module.exports = server;
module.exports.notificador = notificador;
