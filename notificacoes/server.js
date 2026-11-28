// Biko - MICROSSERVIÇO DE NOTIFICAÇÕES (Node >= 22.13, sem bibliotecas externas)
//
// Processo separado da API principal, com banco próprio (coleção "notificacoes" no Firestore) e porta própria (3001).
// - A API principal PUBLICA eventos de pedido (POST /eventos).
// - Este serviço decide QUEM recebe e QUAL o texto, e guarda as notificações.
// - A API principal consulta as notificações do usuário logado (GET /usuarios/:id/notificacoes).
// Só a API principal fala com ele: toda chamada precisa da chave X-Service-Key.
const http = require('http');
const { modoFirestore } = require('../firebase');
const crypto = require('crypto');
const { N, exclusivo } = require('./db');
const push = require('./push');

const SERVICE_KEY = process.env.NOTIF_KEY || 'biko-dev-key';
const now = () => Date.now();

// ---------- regras: nome da ação, texto e quem recebe ----------
// Cada ação do pedido vira uma notificação com o NOME DA AÇÃO como título.
const ACOES = {
  pendente:   { titulo: 'Novo pedido',          para: 'prestador', texto: (e) => `${e.ator_nome || 'Um cliente'} pediu "${e.pedido.servico}" para ${dataBR(e.pedido.data)} às ${e.pedido.hora}.` },
  confirmado: { titulo: 'Pedido confirmado',    para: 'cliente',   texto: (e) => `${e.ator_nome || 'O prestador'} confirmou "${e.pedido.servico}" para ${dataBR(e.pedido.data)} às ${e.pedido.hora}.` },
  recusado:   { titulo: 'Pedido recusado',      para: 'cliente',   texto: (e) => `${e.ator_nome || 'O prestador'} recusou "${e.pedido.servico}".${motivo(e)}` },
  cancelado:  { titulo: 'Pedido cancelado',     para: 'outros',    texto: (e) => `${e.ator_nome || 'Alguém'} cancelou "${e.pedido.servico}" de ${dataBR(e.pedido.data)} às ${e.pedido.hora}.${motivo(e)}` },
  concluido:  { titulo: 'Serviço concluído',    para: 'cliente',   texto: (e) => `"${e.pedido.servico}" foi marcado como concluído por ${e.ator_nome || 'o prestador'}.` },
  atrasado:   { titulo: 'Aviso de atraso',      para: 'cliente',   texto: (e) => `${e.ator_nome || 'O prestador'} avisou um imprevisto em "${e.pedido.servico}". ${e.nota || ''}`.trim() },
  iniciado:   { titulo: 'Atendimento iniciado', para: 'cliente',   texto: (e) => `${e.ator_nome || 'O prestador'} começou o atendimento de "${e.pedido.servico}".${/antecipado/i.test(e.nota || '') ? ` ${e.nota}.` : ''}` },
  prorrogado: { titulo: 'Tempo prorrogado',     para: 'cliente',   texto: (e) => `${e.ator_nome || 'O prestador'} precisou de mais tempo em "${e.pedido.servico}": ${e.nota || ''}`.trim() },
  pago:       { titulo: 'Pagamento recebido',   para: 'prestador', texto: (e) => `${e.ator_nome || 'O cliente'} pagou "${e.pedido.servico}". ${e.nota || ''}`.trim() },
  estornado:  { titulo: 'Pagamento estornado',  para: 'outros',    texto: (e) => `O pagamento de "${e.pedido.servico}" foi devolvido ao cliente. ${e.nota || ''}`.trim() },
  remarcado:  { titulo: 'Horário remarcado',    para: 'cliente',   texto: (e) => `"${e.pedido.servico}" mudou de horário por um imprevisto no atendimento anterior. ${e.nota || ''}`.trim() },
};
const dataBR = (d) => String(d || '').split('-').reverse().join('/');
// o texto da nota já vem montado pela API; aqui só aproveitamos o motivo quando existe
const motivo = (e) => (e.nota ? ` Motivo: ${e.nota}` : '');

// Quem recebe: nunca quem fez a ação (ninguém precisa ser avisado do que ele mesmo fez).
function destinatarios(e, regra) {
  const ids = regra.para === 'cliente' ? [e.cliente_id]
    : regra.para === 'prestador' ? [e.prestador_id]
    : [e.cliente_id, e.prestador_id];
  return [...new Set(ids)].filter((id) => Number.isInteger(id) && id > 0 && id !== e.ator_id);
}

// ---------- utilidades HTTP ----------
class HttpError extends Error { constructor(status, msg) { super(msg); this.status = status; } }
const fail = (status, msg) => { throw new HttpError(status, msg); };
function send(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': Buffer.byteLength(body) });
  res.end(body);
}
function readBody(req, limit = 64 * 1024) {
  return new Promise((resolve, reject) => {
    const chunks = []; let size = 0;
    req.on('data', (c) => { size += c.length; if (size > limit) { reject(new HttpError(413, 'Corpo muito grande.')); req.destroy(); } else chunks.push(c); });
    req.on('end', () => {
      if (!chunks.length) return resolve({});
      try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); } catch { reject(new HttpError(400, 'JSON inválido.')); }
    });
    req.on('error', reject);
  });
}
function checkKey(req) {
  const got = Buffer.from(String(req.headers['x-service-key'] || ''));
  const want = Buffer.from(SERVICE_KEY);
  if (got.length !== want.length || !crypto.timingSafeEqual(got, want)) fail(401, 'Chave de serviço inválida.');
}
const view = (n) => ({ id: n.id, acao: n.acao, titulo: n.titulo, mensagem: n.mensagem, pedido_id: n.pedido_id, lida: !!n.lida });
const doUsuario = (uid) => N.where('usuario_id', '==', uid);
const naoLidas = async (uid) => (await N.where('usuario_id', '==', uid, 'lida', '==', 0)).length;

// ---------- rotas ----------
const routes = [];
function route(method, pattern, handler) {
  const keys = [];
  const re = new RegExp('^' + pattern.replace(/:(\w+)/g, (_, k) => { keys.push(k); return '(\\d+)'; }) + '$');
  routes.push({ method, re, keys, handler });
}

// Saúde do serviço (usada para saber se ele está no ar)
route('GET', '/saude', () => [200, { ok: true, servico: 'notificacoes' }]);

// A API principal publica um evento de pedido. Resposta 200 = "recebi", mesmo que ninguém precise ser avisado.
route('POST', '/eventos', async (ctx) => {
  const e = ctx.body;
  if (!Number.isInteger(e.evento_id) || e.evento_id < 1) fail(400, 'evento_id inválido.');
  if (!e.pedido || !Number.isInteger(e.pedido.id)) fail(400, 'pedido inválido.');
  const regra = ACOES[e.acao];
  if (!regra) return [200, { criadas: 0, ignorado: `ação "${e.acao}" não gera notificação` }];
  const texto = regra.texto(e).slice(0, 400);
  // uma por vez: o mesmo evento chegando 2 vezes (reenvio) não duplica a notificação
  const novas = await exclusivo(async () => {
    const lista = [];
    for (const uid of destinatarios(e, regra)) {
      if (await N.first('evento_id', '==', e.evento_id, 'usuario_id', '==', uid)) continue;
      const n = { evento_id: e.evento_id, usuario_id: uid, acao: e.acao, titulo: regra.titulo, mensagem: texto, pedido_id: e.pedido.id, lida: 0, criada_em: now() };
      n.id = await N.insert(n);
      lista.push(n);
    }
    return lista;
  });
  // Pop-up no celular (push). Sem esperar: a API não fica presa ao Firebase. Um reenvio do
  // mesmo evento não cria notificação nova, então também não manda push repetido.
  for (const n of novas) push.enviar(n);
  return [200, { criadas: novas.length }];
});

// Lista as notificações de um usuário (mais novas primeiro). ?nao_lidas=1 filtra só as não lidas.
route('GET', '/usuarios/:uid/notificacoes', async (ctx) => {
  const uid = Number(ctx.params.uid);
  const limit = Math.min(Math.max(parseInt(ctx.query.limit, 10) || 20, 1), 50);
  const offset = Math.max(parseInt(ctx.query.offset, 10) || 0, 0);
  const todas = await doUsuario(uid);
  const rows = (ctx.query.nao_lidas === '1' ? todas.filter((n) => !n.lida) : todas).sort((a, b) => b.id - a.id);
  const total = rows.length;
  return [200, { notificacoes: rows.slice(offset, offset + limit).map(view), nao_lidas: todas.filter((n) => !n.lida).length, total, limit, offset, has_more: offset + limit < total }];
});

route('GET', '/usuarios/:uid/notificacoes/contagem', async (ctx) => [200, { nao_lidas: await naoLidas(Number(ctx.params.uid)) }]);

// Marca UMA como lida. Só a dona da notificação consegue (de outro usuário dá 404).
route('POST', '/usuarios/:uid/notificacoes/:id/lida', async (ctx) => {
  const uid = Number(ctx.params.uid), id = Number(ctx.params.id);
  const n = await N.get(id);
  if (!n || n.usuario_id !== uid) fail(404, 'Notificação não encontrada.');
  if (!n.lida) await N.update(id, { lida: 1 });
  return [200, { ok: true, nao_lidas: await naoLidas(uid) }];
});

route('POST', '/usuarios/:uid/notificacoes/lidas', async (ctx) => {
  const uid = Number(ctx.params.uid);
  const abertas = await N.where('usuario_id', '==', uid, 'lida', '==', 0);
  await Promise.all(abertas.map((n) => N.update(n.id, { lida: 1 })));
  return [200, { ok: true, marcadas: abertas.length, nao_lidas: 0 }];
});

// Aparelhos para o push. A API principal manda o id de quem está logado e o token do aparelho.
route('POST', '/dispositivos', async (ctx) => {
  const { usuario_id: uid, token, plataforma } = ctx.body;
  if (!Number.isInteger(uid) || uid < 1) fail(400, 'usuario_id inválido.');
  if (!push.tokenValido(token)) fail(400, 'Token do aparelho inválido.');
  await push.registrar(uid, token, plataforma);
  return [200, { ok: true, push_ligado: push.ligado() }];
});
route('POST', '/dispositivos/remover', async (ctx) => {
  if (!push.tokenValido(ctx.body.token)) fail(400, 'Token do aparelho inválido.');
  await push.remover(ctx.body.token);
  return [200, { ok: true }];
});

// ---------- servidor ----------
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const ctx = { query: Object.fromEntries(url.searchParams), params: {}, body: {} };
  try {
    let matched = null;
    for (const r of routes) {
      if (r.method !== req.method) continue;
      const m = r.re.exec(url.pathname);
      if (m) { matched = r; r.keys.forEach((k, i) => (ctx.params[k] = m[i + 1])); break; }
    }
    if (!matched) fail(404, 'Rota não encontrada.');
    if (url.pathname !== '/saude') checkKey(req);
    if (req.method !== 'GET') {
      ctx.body = await readBody(req);
      if (typeof ctx.body !== 'object' || ctx.body === null || Array.isArray(ctx.body)) fail(400, 'JSON inválido.');
    }
    const [status, data] = await matched.handler(ctx);
    send(res, status, data);
  } catch (err) {
    if (err instanceof HttpError) return send(res, err.status, { error: err.message });
    console.error(err);
    send(res, 500, { error: 'Erro interno do serviço de notificações.' });
  }
});

const PORT = Number(process.env.NOTIF_PORT || 3001);
const HOST = process.env.NOTIF_HOST || '127.0.0.1'; // só aceita conexões da própria máquina
if (require.main === module) {
  server.listen(PORT, HOST, () => console.log(`Banco: ${modoFirestore()}\n` +`Microsserviço de notificações em http://${HOST}:${PORT}`));
}
module.exports = server;
module.exports.ACOES = ACOES;
module.exports.push = push;
