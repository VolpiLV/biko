// Testes automatizados de ponta a ponta (backend). Rodar com:  node --disable-warning=ExperimentalWarning test.js
const os = require('os');
const path = require('path');
const fs = require('fs');
const assert = require('assert');

// banco temporário, para não mexer no biko.db real
const tmp = path.join(os.tmpdir(), `biko-test-${Date.now()}.db`);
process.env.BIKO_DB = tmp;
// Microsserviço de notificações: começa "fora do ar" (porta fechada); mais abaixo ele é ligado
process.env.NOTIF_URL = 'http://127.0.0.1:1';
process.env.NOTIF_DB = path.join(os.tmpdir(), `biko-notif-test-${Date.now()}.db`);
process.env.PAG_URL = 'http://127.0.0.1:1'; // pagamentos também começa fora do ar
process.env.PAG_DB = path.join(os.tmpdir(), `biko-pag-test-${Date.now()}.db`);
const server = require('./server');

let base;
let passed = 0;
const results = [];

const cookieJar = new WeakMap();
const cookieOf = async (c) => cookieJar.get(c) || '';
function client() {
  let cookie = '';
  const fn = async (method, url, body) => {
    const res = await fetch(base + url, {
      method,
      headers: { ...(body ? { 'Content-Type': 'application/json' } : {}), ...(cookie ? { Cookie: cookie } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    const sc = res.headers.get('set-cookie');
    if (sc) cookie = sc.split(';')[0].endsWith('=') ? '' : sc.split(';')[0];
    let data = {};
    try { data = await res.json(); } catch (e) { /* não é JSON */ }
    return { status: res.status, data, res };
  };
  const wrapped = async (...a) => { const r = await fn(...a); cookieJar.set(wrapped, cookie); return r; };
  return wrapped;
}

async function t(name, fn) {
  try { await fn(); passed++; results.push(`  ✔ ${name}`); }
  catch (e) { results.push(`  ✘ ${name}\n      ${e.message}`); process.exitCode = 1; }
}

(async () => {
  await new Promise((r) => server.listen(0, r));
  base = `http://127.0.0.1:${server.address().port}`;

  const anon = (method, url, body) => client()(method, url, body); // sem cookie: cada chamada é um visitante novo
  const admin = client(), cliente = client(), prest = client();

  await t('serve a página inicial', async () => {
    const r = await fetch(base + '/');
    assert.strictEqual(r.status, 200);
    assert.ok((await r.text()).includes('id="app"'));
  });
  await t('bloqueia path traversal nos arquivos estáticos', async () => {
    const r = await fetch(base + '/..%2fserver.js');
    assert.ok([403, 404].includes(r.status));
    assert.ok(!(await r.text()).includes('createServer'));
  });

  // ---------- LOGIN ----------
  await t('login sem campos -> 400', async () => assert.strictEqual((await anon('POST', '/api/auth/login', {})).status, 400));
  await t('login com senha errada -> 401 com mensagem genérica', async () => {
    const r = await anon('POST', '/api/auth/login', { email: 'admin@biko.com', password: 'errada123' });
    assert.strictEqual(r.status, 401);
    assert.strictEqual(r.data.error, 'E-mail ou senha inválidos.');
  });
  await t('login com e-mail inexistente -> mesma mensagem (não revela existência)', async () => {
    const r = await anon('POST', '/api/auth/login', { email: 'naoexiste@x.com', password: 'qualquer1' });
    assert.strictEqual(r.status, 401);
    assert.strictEqual(r.data.error, 'E-mail ou senha inválidos.');
  });
  await t('login válido dos 3 perfis', async () => {
    assert.strictEqual((await admin('POST', '/api/auth/login', { email: 'admin@biko.com', password: 'Admin@123' })).data.user.role, 'admin');
    assert.strictEqual((await cliente('POST', '/api/auth/login', { email: 'cliente@biko.com', password: 'Cliente@123' })).data.user.role, 'cliente');
    assert.strictEqual((await prest('POST', '/api/auth/login', { email: 'prestador@biko.com', password: 'Prestador@123' })).data.user.role, 'prestador');
  });
  await t('resposta de login não vaza o hash da senha', async () => {
    const r = await anon('POST', '/api/auth/login', { email: 'admin@biko.com', password: 'Admin@123' });
    assert.ok(!JSON.stringify(r.data).includes('password'));
  });
  await t('cookie de sessão é HttpOnly', async () => {
    const r = await anon('POST', '/api/auth/login', { email: 'admin@biko.com', password: 'Admin@123' });
    assert.ok(r.res.headers.get('set-cookie').includes('HttpOnly'));
  });

  // ---------- CADASTRO ----------
  await t('cadastro inválido -> 400 com erros por campo', async () => {
    const r = await anon('POST', '/api/auth/register', { name: 'Jo', email: 'x', password: '123' });
    assert.strictEqual(r.status, 400);
    assert.ok(r.data.fields.name && r.data.fields.email && r.data.fields.password);
  });
  const novo = client();
  await t('cadastro válido -> 201 e já fica logado', async () => {
    const r = await novo('POST', '/api/auth/register', { name: 'Ana Souza', email: 'Ana@Teste.com', phone: '(47) 98888-7777', password: 'Senha1234' });
    assert.strictEqual(r.status, 201);
    assert.strictEqual(r.data.user.email, 'ana@teste.com');
    assert.strictEqual((await novo('GET', '/api/auth/me')).status, 200);
  });
  await t('cadastro com e-mail repetido -> 409', async () => {
    const r = await anon('POST', '/api/auth/register', { name: 'Outra Ana', email: 'ana@teste.com', password: 'Senha1234' });
    assert.strictEqual(r.status, 409);
    assert.ok(r.data.fields.email);
  });
  await t('auto-cadastro NUNCA cria admin (role=admin vira cliente)', async () => {
    const r = await anon('POST', '/api/auth/register', { name: 'Hacker X', email: 'hacker@x.com', password: 'Senha1234', role: 'admin' });
    assert.strictEqual(r.data.user.role, 'cliente');
  });
  await t('cadastro como prestador funciona', async () => {
    const r = await anon('POST', '/api/auth/register', { name: 'Pedro Pedreiro', email: 'pedro@x.com', password: 'Senha1234', role: 'prestador' });
    assert.strictEqual(r.data.user.role, 'prestador');
  });

  // ---------- SESSÃO / LOGOUT ----------
  await t('sessão persiste (/me) e sem cookie dá 401', async () => {
    assert.strictEqual((await cliente('GET', '/api/auth/me')).data.user.email, 'cliente@biko.com');
    assert.strictEqual((await anon('GET', '/api/auth/me')).status, 401);
  });
  await t('logout invalida a sessão no servidor', async () => {
    const login = await fetch(base + '/api/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: 'cliente@biko.com', password: 'Cliente@123' }) });
    const cookie = login.headers.get('set-cookie').split(';')[0];
    const withCookie = (method, url) => fetch(base + url, { method, headers: { Cookie: cookie } });
    assert.strictEqual((await withCookie('GET', '/api/auth/me')).status, 200);
    assert.strictEqual((await withCookie('POST', '/api/auth/logout')).status, 200);
    // o MESMO cookie, reaproveitado depois do logout, não pode mais funcionar
    assert.strictEqual((await withCookie('GET', '/api/auth/me')).status, 401);
  });
  await t('logout exige estar logado', async () => assert.strictEqual((await anon('POST', '/api/auth/logout')).status, 401));

  // ---------- RECUPERAÇÃO DE SENHA ----------
  await t('forgot responde igual para e-mail existente e inexistente', async () => {
    const a = await anon('POST', '/api/auth/forgot', { email: 'ana@teste.com' });
    const b = await anon('POST', '/api/auth/forgot', { email: 'ninguem@teste.com' });
    assert.strictEqual(a.status, 200); assert.strictEqual(b.status, 200);
    assert.strictEqual(a.data.message, b.data.message);
    assert.ok(a.data.devToken && !b.data.devToken);
  });
  await t('fluxo completo de redefinição de senha', async () => {
    const { data } = await anon('POST', '/api/auth/forgot', { email: 'ana@teste.com' });
    assert.strictEqual((await anon('POST', '/api/auth/reset', { token: data.devToken, password: 'fraca' })).status, 400);
    assert.strictEqual((await anon('POST', '/api/auth/reset', { token: 'tokeninvalido', password: 'NovaSenha99' })).status, 400);
    assert.strictEqual((await anon('POST', '/api/auth/reset', { token: data.devToken, password: 'NovaSenha99' })).status, 200);
    assert.strictEqual((await anon('POST', '/api/auth/reset', { token: data.devToken, password: 'OutraSenha99' })).status, 400); // token de uso único
    assert.strictEqual((await anon('POST', '/api/auth/login', { email: 'ana@teste.com', password: 'Senha1234' })).status, 401);
    assert.strictEqual((await anon('POST', '/api/auth/login', { email: 'ana@teste.com', password: 'NovaSenha99' })).status, 200);
    assert.strictEqual((await novo('GET', '/api/auth/me')).status, 401); // sessão antiga foi derrubada
  });

  // ---------- PERFIS / CONTROLE DE ACESSO ----------
  await t('rotas protegidas sem login -> 401', async () => {
    for (const u of ['/api/users', '/api/cliente/home', '/api/prestador/painel']) assert.strictEqual((await anon('GET', u)).status, 401, u);
  });
  await t('cliente NÃO acessa área de admin nem de prestador (403)', async () => {
    assert.strictEqual((await cliente('GET', '/api/users')).status, 403);
    assert.strictEqual((await cliente('GET', '/api/prestador/painel')).status, 403);
    assert.strictEqual((await cliente('POST', '/api/users', { name: 'X Y Z', email: 'z@z.com', password: 'Senha1234', role: 'admin' })).status, 403);
    assert.strictEqual((await cliente('PATCH', '/api/users/1', { role: 'cliente' })).status, 403);
  });
  await t('prestador NÃO acessa área de cliente nem de admin (403)', async () => {
    assert.strictEqual((await prest('GET', '/api/cliente/home')).status, 403);
    assert.strictEqual((await prest('GET', '/api/users')).status, 403);
  });
  await t('cada perfil acessa a própria área (200)', async () => {
    assert.strictEqual((await cliente('GET', '/api/cliente/home')).status, 200);
    assert.strictEqual((await prest('GET', '/api/prestador/painel')).status, 200);
    assert.strictEqual((await admin('GET', '/api/users')).status, 200);
  });

  // ---------- GESTÃO DE USUÁRIOS ----------
  let anaId;
  await t('admin lista usuários e filtra por busca/perfil/status', async () => {
    const all = (await admin('GET', '/api/users')).data.users;
    assert.ok(all.length >= 6);
    anaId = all.find((u) => u.email === 'ana@teste.com').id;
    assert.strictEqual((await admin('GET', '/api/users?search=ana')).data.users.every((u) => /ana/i.test(u.name + u.email)), true);
    assert.ok((await admin('GET', '/api/users?role=prestador')).data.users.every((u) => u.role === 'prestador'));
    assert.strictEqual((await admin('GET', '/api/users?search=zzzzzz')).data.users.length, 0); // estado "nenhum resultado"
  });
  await t('admin cria usuário (validação, duplicidade e perfil inválido)', async () => {
    assert.strictEqual((await admin('POST', '/api/users', { name: 'A', email: 'x', password: '1', role: 'cliente' })).status, 400);
    assert.strictEqual((await admin('POST', '/api/users', { name: 'Fulano Teste', email: 'fulano@x.com', password: 'Senha1234', role: 'chefe' })).status, 400);
    const ok = await admin('POST', '/api/users', { name: 'Fulano Teste', email: 'fulano@x.com', password: 'Senha1234', role: 'prestador' });
    assert.strictEqual(ok.status, 201);
    assert.strictEqual((await admin('POST', '/api/users', { name: 'Fulano Teste', email: 'fulano@x.com', password: 'Senha1234', role: 'prestador' })).status, 409);
  });
  await t('admin edita dados e atribui outro perfil', async () => {
    const r = await admin('PATCH', `/api/users/${anaId}`, { name: 'Ana Souza Lima', role: 'prestador' });
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.data.user.role, 'prestador');
    assert.strictEqual(r.data.user.name, 'Ana Souza Lima');
  });
  await t('edição valida e-mail duplicado, perfil inválido e usuário inexistente', async () => {
    assert.strictEqual((await admin('PATCH', `/api/users/${anaId}`, { email: 'cliente@biko.com' })).status, 409);
    assert.strictEqual((await admin('PATCH', `/api/users/${anaId}`, { role: 'deus' })).status, 400);
    assert.strictEqual((await admin('PATCH', '/api/users/99999', { name: 'Nome Qualquer' })).status, 404);
  });
  await t('desativar usuário: derruba sessão, bloqueia login e reativar libera', async () => {
    const vit = client();
    await vit('POST', '/api/auth/login', { email: 'ana@teste.com', password: 'NovaSenha99' });
    assert.strictEqual((await vit('GET', '/api/auth/me')).status, 200);
    assert.strictEqual((await admin('PATCH', `/api/users/${anaId}`, { active: false })).data.user.active, false);
    assert.strictEqual((await vit('GET', '/api/auth/me')).status, 401);
    const r = await anon('POST', '/api/auth/login', { email: 'ana@teste.com', password: 'NovaSenha99' });
    assert.strictEqual(r.status, 403);
    assert.ok(/desativada/i.test(r.data.error));
    assert.ok((await admin('GET', '/api/users?status=inativo')).data.users.some((u) => u.id === anaId));
    await admin('PATCH', `/api/users/${anaId}`, { active: true });
    assert.strictEqual((await anon('POST', '/api/auth/login', { email: 'ana@teste.com', password: 'NovaSenha99' })).status, 200);
  });
  await t('admin não pode desativar nem rebaixar a si mesmo', async () => {
    const me = (await admin('GET', '/api/auth/me')).data.user;
    assert.strictEqual((await admin('PATCH', `/api/users/${me.id}`, { active: false })).status, 400);
    assert.strictEqual((await admin('PATCH', `/api/users/${me.id}`, { role: 'cliente' })).status, 400);
    assert.strictEqual((await admin('GET', '/api/auth/me')).status, 200);
  });
  await t('admin redefine senha de outro usuário', async () => {
    assert.strictEqual((await admin('POST', `/api/users/${anaId}/password`, { password: 'fraca' })).status, 400);
    assert.strictEqual((await admin('POST', `/api/users/${anaId}/password`, { password: 'SenhaDoAdmin1' })).status, 200);
    assert.strictEqual((await anon('POST', '/api/auth/login', { email: 'ana@teste.com', password: 'SenhaDoAdmin1' })).status, 200);
  });
  await t('mudar o perfil de alguém derruba a sessão dele (permissões novas só após novo login)', async () => {
    const p = client();
    await p('POST', '/api/auth/login', { email: 'pedro@x.com', password: 'Senha1234' });
    const pid = (await p('GET', '/api/auth/me')).data.user.id;
    assert.strictEqual((await p('GET', '/api/prestador/painel')).status, 200);
    await admin('PATCH', `/api/users/${pid}`, { role: 'cliente' });
    assert.strictEqual((await p('GET', '/api/prestador/painel')).status, 401);
  });

  // =====================================================================
  // 4. PERFIL DO USUÁRIO
  // =====================================================================
  const { db: rawDb } = require('./db'); // mesmo banco temporário do servidor (para simular passagem de tempo)
  const pad2 = (n) => String(n).padStart(2, '0');
  const ymd = (d) => `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
  const inDays = (n) => { const d = new Date(); d.setDate(d.getDate() + n); return ymd(d); };
  const PNG = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
  async function newUser(email, name, role = 'cliente', password = 'Senha1234') {
    const c = client();
    const r = await c('POST', '/api/auth/register', { name, email, phone: '(47) 98888-0000', password, role });
    assert.strictEqual(r.status, 201, `cadastro de ${email}: ${r.data.error}`);
    return { c, id: r.data.user.id, email, password };
  }

  const perfil = await newUser('perfil@teste.com', 'Paula Perfil');

  await t('perfil: rotas exigem login (401)', async () => {
    assert.strictEqual((await anon('PATCH', '/api/me', { name: 'X Y Z' })).status, 401);
    assert.strictEqual((await anon('POST', '/api/me/password', {})).status, 401);
    assert.strictEqual((await anon('PUT', '/api/me/photo', {})).status, 401);
    assert.strictEqual((await anon('DELETE', '/api/me/photo')).status, 401);
  });
  await t('perfil: edita nome e telefone e os dados persistem em um novo login', async () => {
    const r = await perfil.c('PATCH', '/api/me', { name: 'Paula Souza', phone: '(47) 97777-1111' });
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.data.user.name, 'Paula Souza');
    const again = client();
    await again('POST', '/api/auth/login', { email: perfil.email, password: perfil.password });
    const me = (await again('GET', '/api/auth/me')).data.user;
    assert.strictEqual(me.name, 'Paula Souza');
    assert.strictEqual(me.phone, '(47) 97777-1111');
  });
  await t('perfil: valida nome, e-mail e telefone (erro por campo)', async () => {
    const r = await perfil.c('PATCH', '/api/me', { name: 'ab', email: 'invalido', phone: 'abc' });
    assert.strictEqual(r.status, 400);
    assert.ok(r.data.fields.name && r.data.fields.email && r.data.fields.phone);
  });
  await t('perfil: não dá para mudar o próprio perfil nem o status por esta rota', async () => {
    const r = await perfil.c('PATCH', '/api/me', { role: 'admin', active: false });
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.data.user.role, 'cliente');
    assert.strictEqual(r.data.user.active, true);
    assert.strictEqual((await perfil.c('GET', '/api/users')).status, 403);
  });
  await t('perfil: trocar e-mail exige a senha atual correta e o login passa a usar o novo', async () => {
    assert.strictEqual((await perfil.c('PATCH', '/api/me', { email: 'novo.perfil@teste.com' })).data.fields.currentPassword !== undefined, true);
    const wrong = await perfil.c('PATCH', '/api/me', { email: 'novo.perfil@teste.com', currentPassword: 'errada123' });
    assert.strictEqual(wrong.status, 400);
    const ok = await perfil.c('PATCH', '/api/me', { email: 'Novo.Perfil@teste.com', currentPassword: perfil.password });
    assert.strictEqual(ok.status, 200);
    assert.strictEqual(ok.data.user.email, 'novo.perfil@teste.com');
    assert.strictEqual((await anon('POST', '/api/auth/login', { email: perfil.email, password: perfil.password })).status, 401);
    assert.strictEqual((await anon('POST', '/api/auth/login', { email: 'novo.perfil@teste.com', password: perfil.password })).status, 200);
    perfil.email = 'novo.perfil@teste.com';
  });
  await t('perfil: e-mail de outra pessoa -> 409', async () => {
    const r = await perfil.c('PATCH', '/api/me', { email: 'admin@biko.com', currentPassword: perfil.password });
    assert.strictEqual(r.status, 409);
  });
  await t('senha: atual errada, nova fraca e nova igual à atual são recusadas', async () => {
    assert.ok((await perfil.c('POST', '/api/me/password', { currentPassword: 'errada123', newPassword: 'NovaSenha99' })).data.fields.currentPassword);
    assert.ok((await perfil.c('POST', '/api/me/password', { currentPassword: perfil.password, newPassword: 'curta' })).data.fields.newPassword);
    assert.ok((await perfil.c('POST', '/api/me/password', { currentPassword: perfil.password, newPassword: perfil.password })).data.fields.newPassword);
  });
  await t('senha: troca com sucesso, antiga deixa de valer, outras sessões caem e a atual continua', async () => {
    const outra = client();
    await outra('POST', '/api/auth/login', { email: perfil.email, password: perfil.password });
    assert.strictEqual((await outra('GET', '/api/auth/me')).status, 200);
    const r = await perfil.c('POST', '/api/me/password', { currentPassword: perfil.password, newPassword: 'OutraSenha55' });
    assert.strictEqual(r.status, 200);
    assert.strictEqual((await outra('GET', '/api/auth/me')).status, 401);
    assert.strictEqual((await perfil.c('GET', '/api/auth/me')).status, 200);
    assert.strictEqual((await anon('POST', '/api/auth/login', { email: perfil.email, password: perfil.password })).status, 401);
    assert.strictEqual((await anon('POST', '/api/auth/login', { email: perfil.email, password: 'OutraSenha55' })).status, 200);
    perfil.password = 'OutraSenha55';
  });
  await t('senha: bloqueia força bruta na senha atual (429)', async () => {
    const u = await newUser('brutepwd@teste.com', 'Bruno Brute');
    let last;
    for (let i = 0; i < 6; i++) last = await u.c('POST', '/api/me/password', { currentPassword: 'chute' + i, newPassword: 'NovaSenha99' });
    assert.strictEqual(last.status, 429);
  });
  await t('foto: recusa arquivo que não é imagem, tipo falso e formato não permitido', async () => {
    assert.strictEqual((await perfil.c('PUT', '/api/me/photo', { image: 'oi' })).status, 400);
    assert.strictEqual((await perfil.c('PUT', '/api/me/photo', { image: 'data:image/gif;base64,R0lGODlhAQABAAAAACw=' })).status, 400);
    const fake = 'data:image/png;base64,' + Buffer.from('isto é só texto, não um PNG').toString('base64');
    assert.strictEqual((await perfil.c('PUT', '/api/me/photo', { image: fake })).status, 400);
  });
  await t('foto: acima de 200 KB -> 413', async () => {
    const big = 'data:image/png;base64,' + Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(210 * 1024, 1)]).toString('base64');
    assert.strictEqual((await perfil.c('PUT', '/api/me/photo', { image: big })).status, 413);
    const huge = 'data:image/png;base64,' + 'A'.repeat(500 * 1024);
    assert.strictEqual((await perfil.c('PUT', '/api/me/photo', { image: huge })).status, 413);
  });
  await t('foto: envia, outro usuário logado consegue ver, persiste no login e pode ser removida', async () => {
    const r = await perfil.c('PUT', '/api/me/photo', { image: PNG });
    assert.strictEqual(r.status, 200);
    assert.ok(r.data.user.photo_url && r.data.user.photo_url.startsWith(`/api/photo/${perfil.id}`));
    const img = await fetch(base + r.data.user.photo_url, { headers: { Cookie: await cookieOf(cliente) } });
    assert.strictEqual(img.status, 200);
    assert.strictEqual(img.headers.get('content-type'), 'image/png');
    assert.strictEqual((await img.arrayBuffer()).byteLength, Buffer.from(PNG.split(',')[1], 'base64').length);
    assert.strictEqual((await anon('GET', `/api/photo/${perfil.id}`)).status, 401);
    const again = client();
    const login = await again('POST', '/api/auth/login', { email: perfil.email, password: perfil.password });
    assert.ok(login.data.user.photo_url);
    const del = await perfil.c('DELETE', '/api/me/photo');
    assert.strictEqual(del.data.user.photo_url, null);
    assert.strictEqual((await perfil.c('GET', `/api/photo/${perfil.id}`)).status, 404);
  });

  // =====================================================================
  // SERVIÇOS DO PRESTADOR
  // =====================================================================
  const prest2 = await newUser('eletro@teste.com', 'Eduardo Eletro', 'prestador');
  let svcId;
  const goodService = { title: 'Instalação de tomadas', category: 'Eletricista', description: 'Tomadas novas e troca.', price: 80, duration_min: 60 };

  await t('serviços: só prestador cadastra (cliente 403, sem login 401)', async () => {
    assert.strictEqual((await cliente('POST', '/api/services', goodService)).status, 403);
    assert.strictEqual((await anon('POST', '/api/services', goodService)).status, 401);
  });
  await t('serviços: valida título, categoria, preço e duração', async () => {
    const r = await prest2.c('POST', '/api/services', { title: 'ab', category: 'Mágico', price: -5, duration_min: 20 });
    assert.strictEqual(r.status, 400);
    assert.ok(r.data.fields.title && r.data.fields.category && r.data.fields.price && r.data.fields.duration_min);
    assert.strictEqual((await prest2.c('POST', '/api/services', { ...goodService, price: 'abc' })).status, 400);
  });
  await t('serviços: prestador cria e lista os próprios', async () => {
    const r = await prest2.c('POST', '/api/services', goodService);
    assert.strictEqual(r.status, 201);
    assert.strictEqual(r.data.service.price, 80);
    svcId = r.data.service.id;
    assert.ok((await prest2.c('GET', '/api/services/mine')).data.services.some((s) => s.id === svcId));
    assert.strictEqual((await cliente('GET', '/api/services/mine')).status, 403);
  });
  await t('serviços: outro prestador não edita (403) e inexistente dá 404', async () => {
    assert.strictEqual((await prest('PATCH', `/api/services/${svcId}`, { price: 1 })).status, 403);
    assert.strictEqual((await prest2.c('PATCH', '/api/services/99999', { price: 1 })).status, 404);
  });
  await t('serviços: edita preço e desativa/reativa (some e volta na busca)', async () => {
    const e = await prest2.c('PATCH', `/api/services/${svcId}`, { price: 95.5 });
    assert.strictEqual(e.data.service.price, 95.5);
    assert.strictEqual((await prest2.c('PATCH', `/api/services/${svcId}`, { price: 0 })).status, 400);
    const find = async () => (await cliente('GET', '/api/search?q=tomadas')).data.results.some((s) => s.id === svcId);
    assert.strictEqual(await find(), true);
    await prest2.c('PATCH', `/api/services/${svcId}`, { active: false });
    assert.strictEqual(await find(), false);
    await prest2.c('PATCH', `/api/services/${svcId}`, { active: true });
    assert.strictEqual(await find(), true);
  });

  // =====================================================================
  // 6. BUSCA
  // =====================================================================
  await t('busca: exige login e traz as categorias', async () => {
    assert.strictEqual((await anon('GET', '/api/search')).status, 401);
    const c = (await cliente('GET', '/api/categories')).data.categories;
    assert.ok(c.length >= 6 && c.every((x) => x.nome));
    assert.ok((await cliente('GET', '/api/cliente/home')).data.categorias.find((x) => x.nome === 'Encanador').total >= 1);
  });
  await t('busca: sem filtro lista os serviços ativos de prestadores ativos', async () => {
    const r = (await cliente('GET', '/api/search')).data;
    assert.ok(r.total >= 6 && r.results.length === r.total);
    assert.ok(r.results.every((s) => s.active && s.provider_name));
  });
  await t('busca: ignora acento e maiúscula, e procura em título, categoria, descrição e prestador', async () => {
    assert.ok((await cliente('GET', '/api/search?q=ENCANADÓR')).data.results.some((s) => s.category === 'Encanador'));
    assert.ok((await cliente('GET', '/api/search?q=goteiras')).data.results.some((s) => /telhado/i.test(s.title)));
    assert.ok((await cliente('GET', '/api/search?q=' + encodeURIComponent('joana'))).data.results.every((s) => s.provider_name.includes('Joana')));
  });
  await t('busca: várias palavras funcionam como E (todas precisam aparecer)', async () => {
    assert.strictEqual((await cliente('GET', '/api/search?q=vazamentos+carlos')).data.total, 1);
    assert.strictEqual((await cliente('GET', '/api/search?q=vazamentos+joana')).data.total, 0);
  });
  await t('busca: sem resultado devolve lista vazia (estado "nenhum resultado")', async () => {
    const r = await cliente('GET', '/api/search?q=zzzzxyz');
    assert.strictEqual(r.status, 200);
    assert.deepStrictEqual([r.data.total, r.data.results.length], [0, 0]);
  });
  await t('busca: caracteres especiais não quebram nem viram curinga', async () => {
    for (const q of ['%', "'; DROP TABLE users;--", '_', '\\']) {
      const r = await cliente('GET', '/api/search?q=' + encodeURIComponent(q));
      assert.strictEqual(r.status, 200);
      assert.strictEqual(r.data.total, 0, q);
    }
    assert.strictEqual((await admin('GET', '/api/users')).status, 200);
  });
  await t('busca: filtro por categoria e por preço máximo', async () => {
    const cat = (await cliente('GET', '/api/search?category=Pintor')).data.results;
    assert.ok(cat.length >= 1 && cat.every((s) => s.category === 'Pintor'));
    const cheap = (await cliente('GET', '/api/search?max_price=130')).data.results;
    assert.ok(cheap.length >= 1 && cheap.every((s) => s.price <= 130));
  });
  await t('busca: ordenação por preço e paginação', async () => {
    const asc = (await cliente('GET', '/api/search?sort=preco_asc')).data.results.map((s) => s.price);
    assert.deepStrictEqual(asc, [...asc].sort((a, b) => a - b));
    const desc = (await cliente('GET', '/api/search?sort=preco_desc')).data.results.map((s) => s.price);
    assert.deepStrictEqual(desc, [...desc].sort((a, b) => b - a));
    const p1 = (await cliente('GET', '/api/search?sort=preco_asc&limit=2&offset=0')).data;
    const p2 = (await cliente('GET', '/api/search?sort=preco_asc&limit=2&offset=2')).data;
    assert.strictEqual(p1.results.length, 2);
    assert.ok(p1.total > 2 && p1.results[0].id !== p2.results[0].id);
  });
  await t('busca: parâmetros inválidos -> 400', async () => {
    for (const qs of ['category=Mágico', 'max_price=abc', 'max_price=-1', 'sort=aleatorio', 'q=' + 'a'.repeat(81)]) {
      assert.strictEqual((await cliente('GET', '/api/search?' + qs)).status, 400, qs);
    }
  });
  await t('busca: não mostra serviço de prestador desativado nem de quem virou cliente', async () => {
    const tmp = await newUser('sumido@teste.com', 'Sumido Silva', 'prestador');
    await tmp.c('POST', '/api/services', { ...goodService, title: 'Serviço do sumido' });
    const has = async () => (await cliente('GET', '/api/search?q=sumido')).data.total > 0;
    assert.strictEqual(await has(), true);
    await admin('PATCH', `/api/users/${tmp.id}`, { active: false });
    assert.strictEqual(await has(), false);
    await admin('PATCH', `/api/users/${tmp.id}`, { active: true });
    assert.strictEqual(await has(), true);
    await admin('PATCH', `/api/users/${tmp.id}`, { role: 'cliente' });
    assert.strictEqual(await has(), false);
  });

  // =====================================================================
  // 5. AGENDAMENTO / PEDIDOS
  // =====================================================================
  const svc = async (title) => (await cliente('GET', '/api/search?q=' + encodeURIComponent(title))).data.results[0];
  const vaza = await svc('Reparo de vazamentos');   // Carlos, 60 min, R$ 120
  const chuveiro = await svc('chuveiro');           // Carlos, 90 min, R$ 150
  const faxina = await svc('Faxina');               // Joana, 240 min
  const book = (who, service, date, time, extra = {}) =>
    who('POST', '/api/orders', { service_id: service.id, date, time, address: 'Rua das Flores, 120 - Centro', notes: '', ...extra });
  const cliente2 = await newUser('cliente2@teste.com', 'Clara Dois');
  const D = (n) => inDays(n);

  await t('pedido: só cliente cria (prestador/admin 403, sem login 401)', async () => {
    assert.strictEqual((await book(prest, vaza, D(10), '10:00')).status, 403);
    assert.strictEqual((await book(admin, vaza, D(10), '10:00')).status, 403);
    assert.strictEqual((await book(anon, vaza, D(10), '10:00')).status, 401);
  });
  let o1;
  await t('pedido: cliente cria com sucesso (pendente, preço copiado, horário final calculado, histórico)', async () => {
    const r = await book(cliente, vaza, D(10), '10:00', { notes: 'Pia da cozinha' });
    assert.strictEqual(r.status, 201);
    o1 = r.data.order;
    assert.strictEqual(o1.status, 'pendente');
    assert.strictEqual(o1.price, 120);
    assert.strictEqual(o1.end_time, '11:00');
    assert.strictEqual(o1.provider.name, 'Carlos Silva');
    const h = (await cliente('GET', `/api/orders/${o1.id}`)).data.order.history;
    assert.deepStrictEqual(h.map((e) => e.status), ['pendente']);
  });
  await t('pedido: valida data/hora (passado, <1h, >60 dias, data inexistente, minutos, fora do expediente)', async () => {
    const f = async (d, h, extra) => (await book(cliente, vaza, d, h, extra));
    assert.ok((await f(D(-1), '10:00')).data.fields.time);
    const soon = new Date(Date.now() + 30 * 60000); soon.setMinutes(Math.ceil(soon.getMinutes() / 15) * 15, 0, 0);
    assert.ok((await f(ymd(soon), `${pad2(soon.getHours())}:${pad2(soon.getMinutes())}`)).data.fields.time);
    assert.ok((await f(D(90), '10:00')).data.fields.date);
    assert.ok((await f('2027-02-31', '10:00')).data.fields.date);
    assert.ok((await f('amanhã', '10:00')).data.fields.date);
    assert.ok((await f(D(11), '10:10')).data.fields.time);
    assert.ok((await f(D(11), '06:00')).data.fields.time);
    assert.ok((await f(D(11), '19:30')).data.fields.time);   // 19:30 + 60 min passa das 20:00
    assert.strictEqual((await f(D(11), '19:00')).status, 201); // termina às 20:00 em ponto: pode
  });
  await t('pedido: valida endereço, observações e serviço inexistente/inativo', async () => {
    assert.ok((await book(cliente, vaza, D(12), '10:00', { address: 'rua' })).data.fields.address);
    assert.ok((await book(cliente, vaza, D(12), '10:00', { notes: 'x'.repeat(501) })).data.fields.notes);
    assert.strictEqual((await cliente('POST', '/api/orders', { service_id: 99999, date: D(12), time: '10:00', address: 'Rua das Flores, 120' })).status, 404);
    await prest2.c('PATCH', `/api/services/${svcId}`, { active: false });
    assert.strictEqual((await book(cliente, { id: svcId }, D(12), '10:00')).status, 404);
    await prest2.c('PATCH', `/api/services/${svcId}`, { active: true });
  });
  await t('conflito: mesmo horário, horário sobreposto e cliente com 2 pedidos ao mesmo tempo -> 409', async () => {
    assert.strictEqual((await book(cliente2.c, vaza, D(10), '10:00')).status, 409);     // idêntico ao o1
    assert.strictEqual((await book(cliente2.c, vaza, D(10), '10:30')).status, 409);     // começa no meio do o1
    assert.strictEqual((await book(cliente2.c, chuveiro, D(10), '09:15')).status, 409); // 09:15-10:45 invade o o1
    const own = await book(cliente, faxina, D(10), '10:30');                            // outra prestadora, mas o cliente já está ocupado
    assert.strictEqual(own.status, 409);
    assert.ok(own.data.fields.time);
  });
  await t('conflito: horário colado (termina às 11:00, outro começa às 11:00) é permitido', async () => {
    assert.strictEqual((await book(cliente2.c, vaza, D(10), '11:00')).status, 201);
    assert.strictEqual((await book(cliente2.c, chuveiro, D(10), '08:30')).status, 201); // 08:30-10:00 termina exatamente quando o o1 começa
  });
  await t('conflito: duas requisições simultâneas pelo mesmo horário -> só uma passa', async () => {
    const a = await newUser('corrida1@teste.com', 'Corrida Um'), b = await newUser('corrida2@teste.com', 'Corrida Dois');
    const [r1, r2] = await Promise.all([book(a.c, vaza, D(15), '14:00'), book(b.c, vaza, D(15), '14:00')]);
    assert.deepStrictEqual([r1.status, r2.status].sort(), [201, 409]);
  });
  await t('agenda do prestador mostra horários ocupados (e valida a data)', async () => {
    const r = (await cliente('GET', `/api/providers/${vaza.provider_id}/agenda?date=${D(10)}`)).data;
    assert.ok(r.busy.some((b) => b.start === '10:00' && b.end === '11:00'));
    assert.strictEqual((await cliente('GET', `/api/providers/${vaza.provider_id}/agenda?date=lixo`)).status, 400);
    assert.ok(!JSON.stringify(r).includes('Maria'), 'não pode expor quem agendou');
  });
  await t('status: quem não participa não vê o pedido (404); admin vê; ação inválida -> 400', async () => {
    assert.strictEqual((await cliente2.c('GET', `/api/orders/${o1.id}`)).status, 404);
    assert.strictEqual((await prest2.c('POST', `/api/orders/${o1.id}/status`, { action: 'confirmar' })).status, 404);
    assert.strictEqual((await admin('GET', `/api/orders/${o1.id}`)).status, 200);
    assert.strictEqual((await prest('POST', `/api/orders/${o1.id}/status`, { action: 'explodir' })).status, 400);
    assert.strictEqual((await cliente('GET', '/api/orders/abc')).status, 404);
  });
  await t('status: telefone da outra parte só aparece depois de confirmado', async () => {
    assert.strictEqual((await cliente('GET', `/api/orders/${o1.id}`)).data.order.provider.phone, null);
    assert.strictEqual((await prest('GET', `/api/orders/${o1.id}`)).data.order.client.phone, null);
  });
  await t('status: cliente não confirma nem conclui (403); prestador confirma', async () => {
    assert.strictEqual((await cliente('POST', `/api/orders/${o1.id}/status`, { action: 'confirmar' })).status, 403);
    assert.strictEqual((await cliente('POST', `/api/orders/${o1.id}/status`, { action: 'concluir' })).status, 403);
    const r = await prest('POST', `/api/orders/${o1.id}/status`, { action: 'confirmar' });
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.data.order.status, 'confirmado');
    assert.ok(r.data.order.provider.phone && r.data.order.client.phone);
  });
  await t('status: confirmar duas vezes -> 409 (transição inválida)', async () => {
    assert.strictEqual((await prest('POST', `/api/orders/${o1.id}/status`, { action: 'confirmar' })).status, 409);
  });
  await t('status: concluir antes do horário agendado -> 400', async () => {
    assert.strictEqual((await prest('POST', `/api/orders/${o1.id}/status`, { action: 'concluir' })).status, 400);
    assert.ok(!(await prest('GET', `/api/orders/${o1.id}`)).data.order.actions.includes('concluir'));
  });
  await t('status: concluir depois do horário atualiza ganhos do mês; depois de concluído nada muda', async () => {
    const before = (await prest('GET', '/api/prestador/painel')).data.resumo.ganhosMes;
    const old = (await prest('GET', '/api/orders?status=confirmado')).data.orders.find((o) => o.date < D(0));
    assert.ok(old, 'pedido de demonstração já passado');
    assert.ok(old.actions.includes('concluir'));
    assert.strictEqual((await prest('POST', `/api/orders/${old.id}/status`, { action: 'concluir' })).data.order.status, 'concluido');
    assert.strictEqual((await prest('GET', '/api/prestador/painel')).data.resumo.ganhosMes, before + old.price);
    for (const action of ['confirmar', 'recusar', 'cancelar', 'concluir']) {
      assert.strictEqual((await prest('POST', `/api/orders/${old.id}/status`, { action, reason: 'teste ok' })).status, 409, action);
    }
    assert.strictEqual((await cliente('POST', `/api/orders/${old.id}/status`, { action: 'cancelar' })).status, 409);
  });
  await t('status: recusar exige motivo e libera o horário', async () => {
    const r = await book(cliente2.c, chuveiro, D(20), '09:00');
    const id = r.data.order.id;
    assert.strictEqual((await book(cliente, chuveiro, D(20), '09:30')).status, 409);
    const sem = await prest('POST', `/api/orders/${id}/status`, { action: 'recusar' });
    assert.strictEqual(sem.status, 400);
    assert.ok(sem.data.fields.reason);
    const ok = await prest('POST', `/api/orders/${id}/status`, { action: 'recusar', reason: 'Estarei viajando' });
    assert.strictEqual(ok.data.order.status, 'recusado');
    assert.strictEqual(ok.data.order.status_reason, 'Estarei viajando');
    assert.strictEqual((await book(cliente, chuveiro, D(20), '09:30')).status, 201); // horário liberado
    assert.strictEqual((await prest('POST', `/api/orders/${id}/status`, { action: 'confirmar' })).status, 409); // recusado é final
  });
  await t('status: cliente cancela pedido pendente sem motivo e o horário é liberado', async () => {
    const r = await book(cliente2.c, faxina, D(25), '13:00');
    const id = r.data.order.id;
    assert.strictEqual((await book(cliente, faxina, D(25), '14:00')).status, 409);
    const c = await cliente2.c('POST', `/api/orders/${id}/status`, { action: 'cancelar' });
    assert.strictEqual(c.data.order.status, 'cancelado');
    assert.strictEqual((await book(cliente, faxina, D(25), '14:00')).status, 201);
  });
  await t('status: cliente não cancela pedido confirmado a menos de 2h; prestador cancela com motivo', async () => {
    const maria = (await cliente('GET', '/api/auth/me')).data.user.id;
    const t0 = Date.now();
    const ins = rawDb.prepare(`INSERT INTO orders (client_id, provider_id, service_id, service_title, category, price_cents, start_ts, end_ts, address, notes, status, created_at, updated_at)
      VALUES (?,?,?,?,?,?,?,?,?,?, 'confirmado', ?, ?)`).run(maria, vaza.provider_id, vaza.id, 'Reparo (teste 2h)', 'Encanador', 12000, t0 + 90 * 60000, t0 + 150 * 60000, 'Rua X, 1', '', t0, t0);
    const id = Number(ins.lastInsertRowid);
    const cc = await cliente('POST', `/api/orders/${id}/status`, { action: 'cancelar' });
    assert.strictEqual(cc.status, 400);
    assert.ok(/2 horas/.test(cc.data.error));
    assert.ok(!(await cliente('GET', `/api/orders/${id}`)).data.order.actions.includes('cancelar'));
    assert.strictEqual((await prest('POST', `/api/orders/${id}/status`, { action: 'cancelar' })).status, 400); // sem motivo
    const pc = await prest('POST', `/api/orders/${id}/status`, { action: 'cancelar', reason: 'Imprevisto no trabalho' });
    assert.strictEqual(pc.data.order.status, 'cancelado');
  });
  await t('status: cliente cancela pedido confirmado com mais de 2h de antecedência', async () => {
    const r = await book(cliente2.c, vaza, D(30), '16:00');
    await prest('POST', `/api/orders/${r.data.order.id}/status`, { action: 'confirmar' });
    assert.strictEqual((await cliente2.c('POST', `/api/orders/${r.data.order.id}/status`, { action: 'cancelar' })).data.order.status, 'cancelado');
  });
  await t('histórico: cada mudança fica registrada com quem fez e o motivo, em ordem', async () => {
    const r = await book(cliente2.c, chuveiro, D(35), '08:00');
    const id = r.data.order.id;
    await prest('POST', `/api/orders/${id}/status`, { action: 'confirmar' });
    await prest('POST', `/api/orders/${id}/status`, { action: 'cancelar', reason: 'Peça em falta' });
    const h = (await cliente2.c('GET', `/api/orders/${id}`)).data.order.history;
    assert.deepStrictEqual(h.map((e) => e.status), ['pendente', 'confirmado', 'cancelado']);
    assert.strictEqual(h[2].note, 'Peça em falta');
    assert.strictEqual(h[1].actor_name, 'Carlos Silva');
    assert.strictEqual(h[0].actor_role, 'cliente');
  });
  await t('listagem: cada perfil vê só o que é seu; admin vê tudo; filtro por status', async () => {
    const mine = (await cliente('GET', '/api/orders')).data.orders;
    assert.ok(mine.length >= 2 && mine.every((o) => o.client.name === 'Maria Cliente'));
    const theirs = (await prest('GET', '/api/orders')).data.orders;
    assert.ok(theirs.every((o) => o.provider.name === 'Carlos Silva'));
    assert.strictEqual((await prest2.c('GET', '/api/orders')).data.orders.length, 0);
    const all = (await admin('GET', '/api/orders')).data.orders;
    assert.ok(all.length > mine.length + 1 && new Set(all.map((o) => o.client.id)).size > 1);
    assert.ok((await cliente('GET', '/api/orders?status=cancelado')).data.orders.every((o) => o.status === 'cancelado'));
    assert.strictEqual((await cliente('GET', '/api/orders?status=xyz')).status, 400);
    assert.strictEqual((await anon('GET', '/api/orders')).status, 401);
  });
  await t('preço do pedido fica congelado mesmo se o prestador mudar o preço depois', async () => {
    await prest('PATCH', `/api/services/${vaza.id}`, { price: 999 });
    assert.strictEqual((await cliente('GET', `/api/orders/${o1.id}`)).data.order.price, 120);
    await prest('PATCH', `/api/services/${vaza.id}`, { price: 120 });
  });
  await t('painel do prestador mostra pedidos novos reais e próximos agendamentos', async () => {
    const p = (await prest('GET', '/api/prestador/painel')).data;
    const pend = (await prest('GET', '/api/orders?status=pendente')).data.orders.length;
    assert.strictEqual(p.resumo.pedidosNovos, pend);
    assert.ok(Array.isArray(p.proximos));
  });

  // ---------- AGENDA ELÁSTICA (imprevistos no atendimento) ----------
  const mariaId = (await cliente('GET', '/api/auth/me')).data.user.id;
  const rawOrder = (o) => Number(rawDb.prepare(`INSERT INTO orders (client_id, provider_id, service_id, service_title, category, price_cents,
      start_ts, end_ts, address, notes, status, started_ts, completed_ts, extended_min, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
    .run(o.client ?? mariaId, o.provider ?? vaza.provider_id, o.service ?? null, o.title ?? 'Limpeza de fogão', 'Limpeza', 9000,
      o.start, o.end, 'Rua X, 1', '', o.status ?? 'confirmado', o.started ?? null, o.completed ?? null, o.extended ?? 0, Date.now(), Date.now()).lastInsertRowid);
  const getO = async (id) => (await prest('GET', `/api/orders/${id}`)).data.order;
  const MIN = 60000;

  await t('elástica: iniciar (até 30 min antes ou antecipado); um atendimento por vez; concluir cedo libera o horário', async () => {
    const t0 = Date.now();
    const far = rawOrder({ start: t0 + 3 * 3600e3, end: t0 + 3.5 * 3600e3 });
    const near = rawOrder({ start: t0 + 20 * MIN, end: t0 + 50 * MIN });
    const near2 = rawOrder({ start: t0 + 25 * MIN, end: t0 + 55 * MIN, client: cliente2.id });
    assert.ok((await getO(far)).actions.includes('iniciar')); // dá para antecipar
    assert.strictEqual((await cliente('POST', `/api/orders/${near}/status`, { action: 'iniciar' })).status, 403);
    assert.strictEqual((await prest('POST', `/api/orders/${near}/status`, { action: 'estender', minutes: 15, reason: 'teste' })).status, 400); // não iniciado
    const r = await prest('POST', `/api/orders/${near}/status`, { action: 'iniciar' });
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.data.order.in_progress, true);
    assert.ok(r.data.order.actions.includes('estender') && r.data.order.actions.includes('concluir') && !r.data.order.actions.includes('iniciar'));
    assert.strictEqual((await prest('POST', `/api/orders/${near}/status`, { action: 'iniciar' })).status, 409);
    assert.strictEqual((await prest('POST', `/api/orders/${near2}/status`, { action: 'iniciar' })).status, 409); // já tem um em andamento
    assert.ok(!(await cliente('GET', `/api/orders/${near}`)).data.order.actions.includes('cancelar')); // já começou
    const done = await prest('POST', `/api/orders/${near}/status`, { action: 'concluir' }); // antes do horário marcado: pode, pois iniciou
    assert.strictEqual(done.data.order.status, 'concluido');
    assert.ok(done.data.order.real_duration_min >= 1);
    const h = (await getO(near)).history;
    assert.deepStrictEqual(h.map((e) => e.status), ['iniciado', 'concluido']);
    assert.ok(/antes do previsto/.test(h[1].note));
    for (const id of [far, near2]) await prest('POST', `/api/orders/${id}/status`, { action: 'cancelar', reason: 'limpeza do teste' });
  });

  await t('elástica: antecipar — começa agora, libera o horário antigo, recusa se bater com outro pedido', async () => {
    const t0 = Date.now();
    const early = rawOrder({ start: t0 + 2 * 3600e3, end: t0 + 2.5 * 3600e3 });
    const blocker = rawOrder({ start: t0 + 10 * MIN, end: t0 + 40 * MIN, client: cliente2.id });
    const clash = await prest('POST', `/api/orders/${early}/status`, { action: 'iniciar' });
    assert.strictEqual(clash.status, 409);
    assert.ok(/outro pedido/.test(clash.data.error));
    await prest('POST', `/api/orders/${blocker}/status`, { action: 'cancelar', reason: 'liberar agenda' });
    for (const o of rawDb.prepare("SELECT id FROM orders WHERE provider_id = ? AND status = 'confirmado' AND started_ts IS NULL AND start_ts < ? AND end_ts > ? AND id != ?").all(vaza.provider_id, Date.now() + 31 * MIN, Date.now() - MIN, early)) {
      await prest('POST', `/api/orders/${o.id}/status`, { action: 'cancelar', reason: 'liberar agenda' });
    }
    const r = await prest('POST', `/api/orders/${early}/status`, { action: 'iniciar' });
    assert.strictEqual(r.status, 200, JSON.stringify(r.data));
    assert.strictEqual(r.data.order.in_progress, true);
    assert.ok(Math.abs(rawDb.prepare('SELECT start_ts FROM orders WHERE id = ?').get(early).start_ts - Date.now()) < 5000);
    assert.strictEqual(r.data.order.duration_min, 30);
    const h = (await getO(early)).history;
    assert.ok(/antecipado/.test(h[h.length - 1].note));
    assert.strictEqual((await prest('POST', `/api/orders/${early}/status`, { action: 'concluir' })).data.order.status, 'concluido');
  });
  await t('elástica: prorrogar (acabou a energia) remarca os seguintes em cascata e o intervalo livre absorve', async () => {
    const y = new Date(); y.setDate(y.getDate() - 1);
    const at = (h, m) => { const d = new Date(y); d.setHours(h, m, 0, 0); return d.getTime(); };
    const A = rawOrder({ start: at(8, 0), end: at(8, 30), started: at(8, 0) });                         // fogão, 30 min, em andamento
    const B = rawOrder({ start: at(8, 30), end: at(9, 30), client: cliente2.id });                        // colado no A
    const C = rawOrder({ start: at(10, 0), end: at(11, 0), client: cliente2.id, status: 'pendente' });    // 30 min de folga antes
    const D = rawOrder({ start: at(12, 0), end: at(13, 0) });                                             // longe: não mexe
    const ext = (minutes, reason) => prest('POST', `/api/orders/${A}/status`, { action: 'estender', minutes, reason });
    assert.ok((await ext(15)).data.fields.reason);         // motivo obrigatório
    assert.ok((await ext(20, 'Acabou a energia')).data.fields.minutes); // só blocos de 15
    assert.strictEqual((await cliente('POST', `/api/orders/${A}/status`, { action: 'estender', minutes: 15, reason: 'x x x' })).status, 403);

    const r1 = (await ext(15, 'Acabou a energia')).data.order;
    assert.strictEqual(r1.end_time, '08:45');
    assert.strictEqual(r1.planned_end_time, '08:30');
    assert.strictEqual(r1.extended_min, 15);
    let b = await getO(B);
    assert.deepStrictEqual([b.time, b.end_time, b.delay_min, b.original_time], ['08:45', '09:45', 15, '08:30']);
    assert.strictEqual((await getO(C)).time, '10:00'); // 09:45 < 10:00: a folga absorveu

    await ext(30, 'Energia voltou só agora');
    b = await getO(B);
    const c = await getO(C), d = await getO(D);
    assert.deepStrictEqual([b.time, b.delay_min], ['09:15', 45]);
    assert.deepStrictEqual([c.time, c.end_time, c.delay_min], ['10:15', '11:15', 15]);
    assert.deepStrictEqual([d.time, d.delay_min], ['12:00', 0]);
    assert.ok(b.history.some((e) => e.status === 'remarcado' && e.actor_name === null));
    const busy = (await cliente('GET', `/api/providers/${vaza.provider_id}/agenda?date=${ymd(y)}`)).data.busy;
    assert.ok(busy.some((x) => x.start === '08:00' && x.end === '09:15')); // agenda pública reflete o tempo real

    // remarcado por atraso: o cliente pode cancelar mesmo sem as 2 h; o pedido que não mudou continua com a regra
    assert.ok((await cliente2.c('GET', `/api/orders/${B}`)).data.order.actions.includes('cancelar'));
    assert.ok(!(await cliente('GET', `/api/orders/${D}`)).data.order.actions.includes('cancelar'));
    assert.strictEqual((await cliente2.c('POST', `/api/orders/${B}/status`, { action: 'cancelar' })).data.order.status, 'cancelado');

    for (let i = 0; i < 3; i++) await ext(60, 'Serviço maior que o esperado'); // 45 + 180 = 225
    assert.strictEqual((await ext(30, 'mais um pouco')).status, 400);         // passaria de 4 h
    assert.strictEqual((await prest('POST', `/api/orders/${A}/status`, { action: 'concluir' })).data.order.status, 'concluido');
    for (const id of [C, D]) await prest('POST', `/api/orders/${id}/status`, { action: 'cancelar', reason: 'limpeza do teste' });
  });

  await t('aviso de atraso: antes de iniciar, o prestador adia (11:00 -> 11:30), o cliente é avisado e pode cancelar', async () => {
    const tm = new Date(); tm.setDate(tm.getDate() + 1);
    const at = (h, m) => { const d = new Date(tm); d.setHours(h, m, 0, 0); return d.getTime(); };
    const A = rawOrder({ start: at(11, 0), end: at(12, 0) });                                  // Maria, 11:00, confirmado
    const B = rawOrder({ start: at(12, 0), end: at(13, 0), client: cliente2.id });             // colado: será remarcado
    const C = rawOrder({ start: at(14, 0), end: at(15, 0), client: cliente2.id });             // longe: não mexe
    const L = rawOrder({ start: at(19, 0), end: at(20, 0), client: cliente2.id, status: 'pendente' });
    const delay = (id, minutes, reason, who = prest) => who('POST', `/api/orders/${id}/status`, { action: 'atrasar', minutes, reason });

    assert.ok((await getO(A)).actions.includes('atrasar'));
    assert.ok(!(await cliente('GET', `/api/orders/${A}`)).data.order.actions.includes('atrasar'));
    assert.strictEqual((await delay(A, 30, 'x x x', cliente)).status, 403);
    assert.ok((await delay(A, 30, '')).data.fields.reason);           // motivo obrigatório
    assert.ok((await delay(A, 20, 'Falta de luz')).data.fields.minutes); // só 15/30/45/60

    const r = (await delay(A, 30, 'Falta de luz no bairro')).data.order;
    assert.deepStrictEqual([r.time, r.end_time, r.delay_min, r.original_time, r.delay_reason], ['11:30', '12:30', 30, '11:00', 'Falta de luz no bairro']);
    assert.strictEqual(r.status, 'confirmado');
    const b = await getO(B), c = await getO(C);
    assert.deepStrictEqual([b.time, b.delay_min, b.delay_reason], ['12:30', 30, 'Imprevisto no atendimento anterior']);
    assert.deepStrictEqual([c.time, c.delay_min], ['14:00', 0]);
    const h = (await getO(A)).history;
    assert.ok(h.some((e) => e.status === 'atrasado' && /Falta de luz/.test(e.note) && e.actor_name === 'Carlos Silva'));

    // o cliente vê o aviso na tela inicial
    const home = (await cliente('GET', '/api/cliente/home')).data;
    assert.ok(home.avisos.some((o) => o.id === A && o.time === '11:30' && o.delay_reason === 'Falta de luz no bairro'));
    assert.ok((await cliente2.c('GET', '/api/cliente/home')).data.avisos.some((o) => o.id === B));

    // não passa das 22:00 e o total de atraso tem limite
    assert.strictEqual((await delay(L, 60, 'Equipamento quebrado')).status, 200);       // 20:00-21:00
    assert.strictEqual((await delay(L, 60, 'Equipamento quebrado de novo')).status, 200); // 21:00-22:00
    assert.ok((await delay(L, 15, 'mais um pouco')).data.fields.minutes);                 // passaria das 22:00
    for (let i = 0; i < 3; i++) await delay(A, 60, 'Equipamento quebrado');              // 30 + 180 = 210
    assert.ok((await delay(A, 45, 'mais')).data.fields.minutes);                          // passaria de 4 h

    // depois de iniciar não dá mais para avisar atraso (aí é "Preciso de mais tempo")
    const N = rawOrder({ start: Date.now() + 10 * MIN, end: Date.now() + 40 * MIN });
    await prest('POST', `/api/orders/${N}/status`, { action: 'iniciar' });
    assert.ok(!(await getO(N)).actions.includes('atrasar'));
    assert.strictEqual((await delay(N, 15, 'Falta de luz')).status, 409);
    await prest('POST', `/api/orders/${N}/status`, { action: 'concluir' });
    for (const id of [A, B, C, L]) await prest('POST', `/api/orders/${id}/status`, { action: 'cancelar', reason: 'limpeza do teste' });
  });

  await t('elástica: sugere a duração pela mediana do tempo real (sem gordura)', async () => {
    const s = (await prest2.c('POST', '/api/services', { ...goodService, title: 'Limpeza de fogão', category: 'Limpeza', duration_min: 60 })).data.service;
    const stats = async () => (await prest2.c('GET', '/api/services/mine')).data.services.find((x) => x.id === s.id).real_stats;
    assert.strictEqual((await stats()).count, 0);
    const base = Date.now() - 10 * 24 * 3600e3;
    for (const [i, real, extra] of [[0, 30, 0], [1, 28, 0], [2, 45, 15]]) {
      const st = base + i * 24 * 3600e3;
      rawOrder({ provider: prest2.id, service: s.id, start: st, end: st + 60 * MIN, started: st, completed: st + real * MIN, extended: extra, status: 'concluido' });
    }
    const r = await stats();
    assert.deepStrictEqual([r.count, r.median_min, r.avg_min, r.extended_count, r.suggested_min], [3, 30, 34, 1, 30]);
  });

  // ---------- TOKEN BEARER (app mobile) ----------
  const bearer = (token) => async (method, url, body) => {
    const res = await fetch(base + url, {
      method,
      headers: { ...(body ? { 'Content-Type': 'application/json' } : {}), Authorization: `Bearer ${token}` },
      body: body ? JSON.stringify(body) : undefined,
    });
    let data = {};
    try { data = await res.json(); } catch (e) { /* sem corpo */ }
    return { status: res.status, data, res };
  };
  const mobileLogin = (email, password) => fetch(base + '/api/auth/login', {
    method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Client': 'mobile' }, body: JSON.stringify({ email, password }),
  });
  let mobileToken;
  await t('bearer: login com X-Client: mobile devolve token no corpo e não seta cookie', async () => {
    const r = await mobileLogin('cliente@biko.com', 'Cliente@123');
    const data = await r.json();
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.headers.get('set-cookie'), null);
    assert.match(data.token, /^[a-f0-9]{64}$/);
    assert.strictEqual(data.token_type, 'Bearer');
    assert.ok(data.expires_at > Date.now());
    mobileToken = data.token;
  });
  await t('bearer: login web (sem X-Client) continua sem token no corpo', async () => {
    const r = await anon('POST', '/api/auth/login', { email: 'cliente@biko.com', password: 'Cliente@123' });
    assert.strictEqual(r.data.token, undefined);
    assert.ok(r.res.headers.get('set-cookie'));
  });
  await t('bearer: cadastro mobile já devolve token utilizável', async () => {
    const r = await fetch(base + '/api/auth/register', {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Client': 'mobile' },
      body: JSON.stringify({ name: 'Mobile Teste', email: 'mobile@x.com', password: 'Senha1234' }),
    });
    const data = await r.json();
    assert.strictEqual(r.status, 201);
    assert.strictEqual((await bearer(data.token)('GET', '/api/auth/me')).data.user.email, 'mobile@x.com');
  });
  await t('bearer: token válido acessa rotas protegidas e respeita o perfil', async () => {
    const me = await bearer(mobileToken)('GET', '/api/auth/me');
    assert.strictEqual(me.status, 200);
    assert.strictEqual(me.data.user.role, 'cliente');
    assert.strictEqual((await bearer(mobileToken)('GET', '/api/users')).status, 403);
  });
  await t('bearer: token malformado, inexistente ou esquema errado -> 401', async () => {
    assert.strictEqual((await bearer('abc')('GET', '/api/auth/me')).status, 401);
    assert.strictEqual((await bearer('f'.repeat(64))('GET', '/api/auth/me')).status, 401);
    const basic = await fetch(base + '/api/auth/me', { headers: { Authorization: `Basic ${mobileToken}` } });
    assert.strictEqual(basic.status, 401);
  });
  await t('bearer: logout invalida o token', async () => {
    const tk = (await (await mobileLogin('cliente@biko.com', 'Cliente@123')).json()).token;
    assert.strictEqual((await bearer(tk)('POST', '/api/auth/logout')).status, 200);
    assert.strictEqual((await bearer(tk)('GET', '/api/auth/me')).status, 401);
  });
  await t('bearer: admin desativando a conta derruba o token na hora', async () => {
    const tk = (await (await mobileLogin('mobile@x.com', 'Senha1234')).json()).token;
    const id = (await bearer(tk)('GET', '/api/auth/me')).data.user.id;
    await admin('PATCH', `/api/users/${id}`, { active: false });
    assert.strictEqual((await bearer(tk)('GET', '/api/auth/me')).status, 401);
    await admin('PATCH', `/api/users/${id}`, { active: true });
  });

  // ---------- CORS (app Flutter no Chrome) ----------
  await t('cors: preflight de localhost em outra porta é liberado', async () => {
    const r = await fetch(base + '/api/auth/login', {
      method: 'OPTIONS',
      headers: { Origin: 'http://localhost:54321', 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'content-type,x-client' },
    });
    assert.strictEqual(r.status, 204);
    assert.strictEqual(r.headers.get('access-control-allow-origin'), 'http://localhost:54321');
    assert.match(r.headers.get('access-control-allow-headers'), /Authorization/);
    assert.match(r.headers.get('access-control-allow-headers'), /X-Client/);
    assert.strictEqual(r.headers.get('access-control-allow-credentials'), null);
  });
  await t('cors: origem externa é recusada', async () => {
    const pre = await fetch(base + '/api/auth/login', { method: 'OPTIONS', headers: { Origin: 'https://site-malicioso.com' } });
    assert.strictEqual(pre.status, 403);
    assert.strictEqual(pre.headers.get('access-control-allow-origin'), null);
    const get = await fetch(base + '/api/auth/me', { headers: { Origin: 'http://localhost.evil.com' } });
    assert.strictEqual(get.headers.get('access-control-allow-origin'), null);
  });
  await t('cors: respostas de sucesso e de erro levam o cabeçalho (o app consegue ler o erro)', async () => {
    const origin = 'http://127.0.0.1:8080';
    const ok = await fetch(base + '/api/auth/login', {
      method: 'POST', headers: { Origin: origin, 'Content-Type': 'application/json', 'X-Client': 'mobile' },
      body: JSON.stringify({ email: 'cliente@biko.com', password: 'Cliente@123' }),
    });
    assert.strictEqual(ok.status, 200);
    assert.strictEqual(ok.headers.get('access-control-allow-origin'), origin);
    const err = await fetch(base + '/api/auth/me', { headers: { Origin: origin } });
    assert.strictEqual(err.status, 401);
    assert.strictEqual(err.headers.get('access-control-allow-origin'), origin);
  });

  // ---------- PAGINAÇÃO ----------
  await t('paginação /api/users: páginas não se repetem e cobrem o total', async () => {
    const p1 = (await admin('GET', '/api/users?limit=2')).data;
    assert.strictEqual(p1.users.length, 2);
    assert.strictEqual(p1.limit, 2);
    assert.strictEqual(p1.offset, 0);
    assert.ok(p1.total > 2);
    assert.strictEqual(p1.has_more, true);
    const ids = [];
    for (let off = 0; off < p1.total; off += 2) ids.push(...(await admin('GET', `/api/users?limit=2&offset=${off}`)).data.users.map((u) => u.id));
    assert.strictEqual(ids.length, p1.total);
    assert.strictEqual(new Set(ids).size, p1.total);
    const last = (await admin('GET', `/api/users?limit=2&offset=${p1.total - 1}`)).data;
    assert.strictEqual(last.has_more, false);
  });
  await t('paginação /api/users: total respeita os filtros', async () => {
    const d = (await admin('GET', '/api/users?role=prestador&limit=1')).data;
    assert.ok(d.users.every((u) => u.role === 'prestador'));
    assert.strictEqual(d.total, (await admin('GET', '/api/users?role=prestador&limit=100')).data.users.length);
  });
  await t('paginação /api/orders: mesma ordem paginada ou não, total por perfil', async () => {
    const all = (await cliente('GET', '/api/orders?limit=100')).data;
    assert.strictEqual(all.total, all.orders.length);
    const p1 = (await cliente('GET', '/api/orders?limit=1')).data;
    const p2 = (await cliente('GET', '/api/orders?limit=1&offset=1')).data;
    assert.deepStrictEqual([p1.orders[0].id, p2.orders[0].id], all.orders.slice(0, 2).map((o) => o.id));
    const pend = (await cliente('GET', '/api/orders?status=pendente&limit=1')).data;
    assert.strictEqual(pend.total, all.orders.filter((o) => o.status === 'pendente').length);
  });
  await t('paginação: limit/offset inválidos -> 400; limit acima do máximo é limitado a 100', async () => {
    for (const q of ['limit=0', 'limit=-1', 'limit=abc', 'offset=-5', 'offset=1.5']) {
      assert.strictEqual((await admin('GET', `/api/users?${q}`)).status, 400, q);
      assert.strictEqual((await admin('GET', `/api/orders?${q}`)).status, 400, q);
    }
    assert.strictEqual((await admin('GET', '/api/users?limit=5000')).data.limit, 100);
    assert.strictEqual((await admin('GET', '/api/users?offset=9999')).data.users.length, 0);
  });
  await t('resumo do admin bate com as listagens; outros perfis 403', async () => {
    const r = (await admin('GET', '/api/admin/resumo')).data;
    assert.strictEqual(r.pedidos, (await admin('GET', '/api/orders')).data.total);
    assert.strictEqual(r.prestadores, (await admin('GET', '/api/users?role=prestador')).data.total);
    assert.strictEqual((await cliente('GET', '/api/admin/resumo')).status, 403);
  });

  // =====================================================================
  // MICROSSERVIÇO DE NOTIFICAÇÕES
  // =====================================================================
  const { notificador } = server;
  await t('notificações: sem login -> 401', async () => assert.strictEqual((await anon('GET', '/api/notificacoes')).status, 401));
  let oN;
  await t('notificações: microsserviço fora do ar -> 503, mas o pedido é criado normalmente e o evento espera na fila', async () => {
    assert.strictEqual((await cliente('GET', '/api/notificacoes')).status, 503);
    const r = await book(cliente, vaza, D(47), '08:00');
    assert.strictEqual(r.status, 201);
    oN = r.data.order;
    assert.ok(notificador.pendentes() > 0);
  });
  const ms = require('./notificacoes/server');
  await new Promise((r) => ms.listen(0, '127.0.0.1', r));
  process.env.NOTIF_URL = `http://127.0.0.1:${ms.address().port}`;
  const msUrl = process.env.NOTIF_URL;
  await t('notificações: quando o microsserviço volta, a fila é entregue sem perder nada', async () => {
    // forcar: os eventos que falharam estão esperando a próxima tentativa; aqui entregamos já
    for (let i = 0; i < 10 && notificador.pendentes() > 0; i++) { await notificador.flush(true); await new Promise((r) => setImmediate(r)); }
    assert.strictEqual(notificador.pendentes(), 0);
  });
  await t('notificações: prestador recebe "Novo pedido" (título = nome da ação, sem data)', async () => {
    const d = (await prest('GET', '/api/notificacoes')).data;
    const n = d.notificacoes.find((x) => x.pedido_id === oN.id);
    assert.ok(n, 'notificação do pedido novo');
    assert.strictEqual(n.titulo, 'Novo pedido');
    assert.strictEqual(n.acao, 'pendente');
    assert.strictEqual(n.lida, false);
    assert.ok(/Maria/.test(n.mensagem));
    assert.ok(!('criada_em' in n) && !('created_at' in n), 'a lista não traz a data');
    assert.ok(d.nao_lidas >= 1);
  });
  await t('notificações: quem fez a ação não é notificado', async () => {
    const d = (await cliente('GET', '/api/notificacoes?limit=50')).data;
    assert.ok(!d.notificacoes.some((x) => x.pedido_id === oN.id && x.acao === 'pendente'));
  });
  await t('notificações: prestador confirma -> cliente recebe "Pedido confirmado" e o contador sobe', async () => {
    const antes = (await cliente('GET', '/api/notificacoes/contagem')).data.nao_lidas;
    assert.strictEqual((await prest('POST', `/api/orders/${oN.id}/status`, { action: 'confirmar' })).status, 200);
    const depois = (await cliente('GET', '/api/notificacoes/contagem')).data.nao_lidas;
    assert.strictEqual(depois, antes + 1);
    const n = (await cliente('GET', '/api/notificacoes?nao_lidas=1')).data.notificacoes[0];
    assert.strictEqual(n.titulo, 'Pedido confirmado');
    assert.strictEqual(n.pedido_id, oN.id);
  });
  await t('notificações: aviso de atraso chega ao cliente com o motivo', async () => {
    assert.strictEqual((await prest('POST', `/api/orders/${oN.id}/status`, { action: 'atrasar', minutes: 30, reason: 'Pneu furado' })).status, 200);
    const n = (await cliente('GET', '/api/notificacoes')).data.notificacoes[0];
    assert.strictEqual(n.titulo, 'Aviso de atraso');
    assert.ok(/Pneu furado/.test(n.mensagem) && /08:30/.test(n.mensagem));
  });
  await t('notificações: marcar como lida (só a dona); de outro usuário -> 404', async () => {
    const n = (await cliente('GET', '/api/notificacoes?nao_lidas=1')).data.notificacoes[0];
    assert.strictEqual((await prest('POST', `/api/notificacoes/${n.id}/lida`)).status, 404);
    assert.strictEqual((await cliente('POST', '/api/notificacoes/abc/lida')).status, 404);
    const r = await cliente('POST', `/api/notificacoes/${n.id}/lida`);
    assert.strictEqual(r.status, 200);
    const again = (await cliente('GET', '/api/notificacoes?limit=50')).data.notificacoes.find((x) => x.id === n.id);
    assert.strictEqual(again.lida, true);
  });
  await t('notificações: marcar todas como lidas zera o contador', async () => {
    assert.strictEqual((await cliente('POST', '/api/notificacoes/lidas')).status, 200);
    assert.strictEqual((await cliente('GET', '/api/notificacoes/contagem')).data.nao_lidas, 0);
  });
  await t('notificações: cancelamento pelo admin avisa cliente e prestador', async () => {
    assert.strictEqual((await admin('POST', `/api/orders/${oN.id}/status`, { action: 'cancelar', reason: 'Teste do admin' })).status, 200);
    for (const who of [cliente, prest]) {
      const n = (await who('GET', '/api/notificacoes')).data.notificacoes[0];
      assert.strictEqual(n.titulo, 'Pedido cancelado');
      assert.ok(/Teste do admin/.test(n.mensagem));
    }
  });
  await t('microsserviço: sem a chave de serviço -> 401 (ninguém de fora lê as notificações)', async () => {
    assert.strictEqual((await fetch(`${msUrl}/usuarios/1/notificacoes`)).status, 401);
    assert.strictEqual((await fetch(`${msUrl}/usuarios/1/notificacoes`, { headers: { 'X-Service-Key': 'errada' } })).status, 401);
    assert.strictEqual((await fetch(`${msUrl}/saude`)).status, 200);
  });
  await t('microsserviço: o mesmo evento chegando 2 vezes não duplica (idempotente)', async () => {
    const ev = { evento_id: 999999, acao: 'confirmado', pedido: { id: oN.id, servico: 'X', data: '2030-01-01', hora: '10:00' }, cliente_id: 2, prestador_id: 3, ator_id: 3, ator_nome: 'Carlos' };
    const post = () => fetch(`${msUrl}/eventos`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Service-Key': 'biko-dev-key' }, body: JSON.stringify(ev) }).then((r) => r.json());
    assert.strictEqual((await post()).criadas, 1);
    assert.strictEqual((await post()).criadas, 0);
  });
  // =====================================================================
  // MICROSSERVIÇO DE PAGAMENTOS (simulado)
  // =====================================================================
  let oP;
  await t('pagamento: só depois de confirmado; prestador não paga; fora do ar -> 503', async () => {
    oP = (await book(cliente, vaza, D(48), '09:00')).data.order;
    assert.strictEqual(oP.can_pay, false);
    assert.strictEqual((await cliente('POST', `/api/orders/${oP.id}/pagamento`, { metodo: 'pix' })).status, 409);
    await prest('POST', `/api/orders/${oP.id}/status`, { action: 'confirmar' });
    assert.strictEqual((await cliente('GET', `/api/orders/${oP.id}`)).data.order.can_pay, true);
    assert.strictEqual((await prest('GET', `/api/orders/${oP.id}`)).data.order.can_pay, false);
    assert.strictEqual((await prest('POST', `/api/orders/${oP.id}/pagamento`, { metodo: 'pix' })).status, 403);
    assert.strictEqual((await cliente('POST', `/api/orders/${oP.id}/pagamento`, { metodo: 'pix' })).status, 503);
    assert.strictEqual((await cliente2.c('POST', `/api/orders/${oP.id}/pagamento`, { metodo: 'pix' })).status, 404);
  });
  const pms = require('./pagamentos/server');
  await new Promise((r) => pms.listen(0, '127.0.0.1', r));
  process.env.PAG_URL = `http://127.0.0.1:${pms.address().port}`;
  await t('pagamento: método inválido / cartão sem número -> 400', async () => {
    assert.strictEqual((await cliente('POST', `/api/orders/${oP.id}/pagamento`, { metodo: 'boleto' })).status, 400);
    assert.strictEqual((await cliente('POST', `/api/orders/${oP.id}/pagamento`, { metodo: 'cartao', cartao: { final: '12' } })).status, 400);
  });
  await t('pagamento: cartão final 0002 é recusado (simulação) e dá para tentar de novo', async () => {
    const r = await cliente('POST', `/api/orders/${oP.id}/pagamento`, { metodo: 'cartao', cartao: { final: '0002', bandeira: 'Visa', parcelas: 1 } });
    assert.strictEqual(r.status, 201);
    assert.strictEqual(r.data.cobranca.status, 'recusado');
    assert.strictEqual(r.data.order.payment.status, 'recusado');
    assert.strictEqual(r.data.order.can_pay, true);
  });
  await t('pagamento: Pix fica aguardando com código copia e cola; simular aprova', async () => {
    const r = await cliente('POST', `/api/orders/${oP.id}/pagamento`, { metodo: 'pix' });
    assert.strictEqual(r.data.cobranca.status, 'aguardando');
    assert.ok(/BR\.GOV\.BCB\.PIX/.test(r.data.cobranca.pix_copia_cola));
    assert.strictEqual((await prest('GET', `/api/orders/${oP.id}/pagamento`)).data.cobranca.pix_copia_cola, null);
    const c = await cliente('POST', `/api/orders/${oP.id}/pagamento/confirmar`);
    assert.strictEqual(c.data.cobranca.status, 'aprovado');
    assert.strictEqual(c.data.order.payment.status, 'pago');
    assert.ok(/^BKP-/.test(c.data.order.payment.code));
    assert.strictEqual(c.data.order.can_pay, false);
    assert.strictEqual(c.data.cobranca.taxa, 12);
    assert.strictEqual(c.data.cobranca.liquido, 108);
  });
  await t('pagamento: pagar de novo -> 409; histórico do pedido mostra "pago"', async () => {
    assert.strictEqual((await cliente('POST', `/api/orders/${oP.id}/pagamento`, { metodo: 'pix' })).status, 409);
    const h = (await cliente('GET', `/api/orders/${oP.id}`)).data.order.history;
    assert.ok(h.some((e) => e.status === 'pago' && /Pix/.test(e.note)));
  });
  await t('pagamento: prestador recebe a notificação "Pagamento recebido"', async () => {
    const n = (await prest('GET', '/api/notificacoes')).data.notificacoes[0];
    assert.strictEqual(n.titulo, 'Pagamento recebido');
    assert.strictEqual(n.pedido_id, oP.id);
  });
  await t('vendas: prestador vê o que vendeu com taxa; cliente vê o que pagou; outro cliente não vê', async () => {
    const pv = (await prest('GET', '/api/pagamentos')).data;
    assert.ok(pv.cobrancas.some((c) => c.pedido_id === oP.id && c.status === 'aprovado'));
    assert.ok(pv.resumo.vendas >= 1 && pv.resumo.liquido >= 108);
    assert.ok((await cliente('GET', '/api/pagamentos')).data.cobrancas.some((c) => c.pedido_id === oP.id));
    assert.ok(!(await cliente2.c('GET', '/api/pagamentos')).data.cobrancas.some((c) => c.pedido_id === oP.id));
    assert.ok((await admin('GET', '/api/pagamentos')).data.total >= 2);
  });
  await t('pagamento: pedido pago cancelado -> estorno automático + notificação', async () => {
    assert.strictEqual((await prest('POST', `/api/orders/${oP.id}/status`, { action: 'cancelar', reason: 'Imprevisto sério' })).status, 200);
    const o = (await cliente('GET', `/api/orders/${oP.id}`)).data.order;
    assert.strictEqual(o.payment.status, 'estornado');
    assert.ok(o.history.some((e) => e.status === 'estornado'));
    assert.strictEqual((await cliente('GET', `/api/orders/${oP.id}/pagamento`)).data.cobranca.status, 'estornado');
    assert.strictEqual((await cliente('GET', '/api/notificacoes')).data.notificacoes[0].titulo, 'Pagamento estornado');
  });
  await t('pagamento: cartão aprovado na hora com parcelas', async () => {
    const o = (await book(cliente, vaza, D(49), '09:00')).data.order;
    await prest('POST', `/api/orders/${o.id}/status`, { action: 'confirmar' });
    const r = await cliente('POST', `/api/orders/${o.id}/pagamento`, { metodo: 'cartao', cartao: { final: '4242', bandeira: 'Mastercard', parcelas: 3 } });
    assert.strictEqual(r.data.cobranca.status, 'aprovado');
    assert.deepStrictEqual(r.data.cobranca.cartao, { final: '4242', bandeira: 'Mastercard' });
    assert.strictEqual(r.data.cobranca.parcelas, 3);
  });
  pms.close();
  ms.close();

  // ---------- FORÇA BRUTA ----------
  await t('bloqueia após 5 tentativas erradas (429)', async () => {
    let last;
    for (let i = 0; i < 6; i++) last = await anon('POST', '/api/auth/login', { email: 'forca@bruta.com', password: 'tentativa' + i });
    assert.strictEqual(last.status, 429);
  });

  console.log('\nResultados:\n' + results.join('\n'));
  console.log(`\n${passed}/${results.length} testes passaram`);
  server.close();
  for (const f of [process.env.NOTIF_DB, process.env.NOTIF_DB + '-wal', process.env.NOTIF_DB + '-shm', process.env.PAG_DB, process.env.PAG_DB + '-wal', process.env.PAG_DB + '-shm']) { try { fs.rmSync(f, { force: true }); } catch (e) { /* ok */ } }
  try { fs.rmSync(tmp, { force: true }); fs.rmSync(tmp + '-wal', { force: true }); fs.rmSync(tmp + '-shm', { force: true }); } catch (e) { /* ok */ }
  process.exit(process.exitCode || 0);
})();
