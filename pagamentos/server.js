// Biko - MICROSSERVIÇO DE PAGAMENTOS / VENDAS (SIMULADO, só para apresentação do TCC)
//
// Nenhum dinheiro de verdade passa por aqui e nenhum banco é chamado. Ele imita um gateway:
//   - Pix: gera um código "copia e cola" de mentira e fica "aguardando" até alguém tocar em
//     "Simular pagamento" (no mundo real seria o banco avisando).
//   - Cartão: aprova na hora. Para mostrar uma recusa na apresentação, use um cartão que termine em 0002.
// Guarda só os 4 últimos dígitos do cartão. Processo separado (porta 3002) com banco próprio.
const http = require('http');
const crypto = require('crypto');
const { db } = require('./db');

const SERVICE_KEY = process.env.PAG_KEY || 'biko-dev-key';
const TAXA_PLATAFORMA = 0.10;              // 10% fica com o Biko, 90% vai para o prestador
const PIX_VALIDADE_MS = 30 * 60e3;         // Pix "vale" 30 min
const MAX_PARCELAS = 3;
const CARTAO_RECUSADO = '0002';            // final de cartão que simula recusa
const now = () => Date.now();

class HttpError extends Error { constructor(status, msg) { super(msg); this.status = status; } }
const fail = (status, msg) => { throw new HttpError(status, msg); };
function send(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': Buffer.byteLength(body) });
  res.end(body);
}
function readBody(req, limit = 32 * 1024) {
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

const codigo = () => 'BKP-' + crypto.randomBytes(4).toString('hex').toUpperCase();
// Código Pix de mentira, com cara de "copia e cola" (não funciona em banco nenhum)
const pixFake = (c) => `00020126580014BR.GOV.BCB.PIX0136biko-demo-${c.codigo.toLowerCase()}5204000053039865406${(c.valor_centavos / 100).toFixed(2)}5802BR5904BIKO6009JOINVILLE62070503***6304DEMO`;

function view(c) {
  return {
    id: c.id, codigo: c.codigo, pedido_id: c.pedido_id, descricao: c.descricao,
    pagador: { id: c.pagador_id, nome: c.pagador_nome }, recebedor: { id: c.recebedor_id, nome: c.recebedor_nome },
    valor: c.valor_centavos / 100, taxa: c.taxa_centavos / 100, liquido: c.liquido_centavos / 100,
    metodo: c.metodo, parcelas: c.parcelas,
    cartao: c.metodo === 'cartao' ? { final: c.cartao_final, bandeira: c.cartao_bandeira } : null,
    pix_copia_cola: c.status === 'aguardando' ? c.pix_copia_cola : null,
    autorizacao: c.autorizacao, status: c.status, motivo: c.motivo,
    criada_em: c.criada_em, expira_em: c.expira_em, pago_em: c.pago_em, estornado_em: c.estornado_em,
  };
}
// Pix vencido vira "expirado" na hora em que alguém olha
function expirar() {
  db.prepare("UPDATE cobrancas SET status = 'expirado', motivo = 'Pix expirou sem pagamento' WHERE status = 'aguardando' AND expira_em < ?").run(now());
}
const carregar = (id) => { expirar(); const c = db.prepare('SELECT * FROM cobrancas WHERE id = ?').get(id); if (!c) fail(404, 'Cobrança não encontrada.'); return c; };

// ---------- rotas ----------
const routes = [];
function route(method, pattern, handler) {
  const keys = [];
  const re = new RegExp('^' + pattern.replace(/:(\w+)/g, (_, k) => { keys.push(k); return '(\\d+)'; }) + '$');
  routes.push({ method, re, keys, handler });
}

route('GET', '/saude', () => [200, { ok: true, servico: 'pagamentos', simulado: true }]);

// Cria uma cobrança para um pedido.
route('POST', '/cobrancas', (ctx) => {
  const b = ctx.body;
  const int = (v) => Number.isInteger(v) && v > 0;
  if (!int(b.pedido_id) || !int(b.pagador_id) || !int(b.recebedor_id) || !int(b.valor_centavos)) fail(400, 'Dados da cobrança inválidos.');
  if (!['pix', 'cartao'].includes(b.metodo)) fail(400, 'Escolha Pix ou cartão.');
  expirar();
  if (db.prepare("SELECT 1 FROM cobrancas WHERE pedido_id = ? AND status = 'aprovado'").get(b.pedido_id)) fail(409, 'Este pedido já foi pago.');
  // um Pix antigo ainda aberto para o mesmo pedido é substituído pelo novo pedido de pagamento
  db.prepare("UPDATE cobrancas SET status = 'expirado', motivo = 'Substituído por uma nova tentativa' WHERE pedido_id = ? AND status = 'aguardando'").run(b.pedido_id);

  let parcelas = 1, final = null, bandeira = null;
  if (b.metodo === 'cartao') {
    const c = b.cartao || {};
    final = String(c.final || '');
    if (!/^\d{4}$/.test(final)) fail(400, 'Informe o cartão.');
    parcelas = Number(c.parcelas || 1);
    if (!Number.isInteger(parcelas) || parcelas < 1 || parcelas > MAX_PARCELAS) fail(400, `Parcelamento de 1 a ${MAX_PARCELAS}x.`);
    bandeira = ['Visa', 'Mastercard', 'Elo'].includes(c.bandeira) ? c.bandeira : 'Cartão';
  }
  const taxa = Math.round(b.valor_centavos * TAXA_PLATAFORMA);
  const base = {
    codigo: codigo(), pedido_id: b.pedido_id, descricao: String(b.descricao || 'Serviço Biko').slice(0, 120),
    pagador_id: b.pagador_id, pagador_nome: b.pagador_nome || null, recebedor_id: b.recebedor_id, recebedor_nome: b.recebedor_nome || null,
    valor_centavos: b.valor_centavos, taxa_centavos: taxa, liquido_centavos: b.valor_centavos - taxa,
  };
  const t = now();
  let status, motivo = null, autorizacao = null, pix = null, expira = null, pagoEm = null;
  if (b.metodo === 'pix') {
    status = 'aguardando'; expira = t + PIX_VALIDADE_MS; pix = pixFake(base);
  } else if (final === CARTAO_RECUSADO) {
    status = 'recusado'; motivo = 'Cartão recusado pelo banco emissor (simulação)';
  } else {
    status = 'aprovado'; autorizacao = String(crypto.randomInt(100000, 999999)); pagoEm = t;
  }
  const info = db.prepare(`INSERT INTO cobrancas (codigo, pedido_id, descricao, pagador_id, pagador_nome, recebedor_id, recebedor_nome,
      valor_centavos, taxa_centavos, liquido_centavos, metodo, parcelas, cartao_final, cartao_bandeira, pix_copia_cola, autorizacao, status, motivo, criada_em, expira_em, pago_em)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`).run(base.codigo, base.pedido_id, base.descricao, base.pagador_id, base.pagador_nome, base.recebedor_id, base.recebedor_nome,
    base.valor_centavos, base.taxa_centavos, base.liquido_centavos, b.metodo, parcelas, final, bandeira, pix, autorizacao, status, motivo, t, expira, pagoEm);
  return [201, { cobranca: view(carregar(Number(info.lastInsertRowid))) }];
});

// "O banco avisou que o Pix caiu" — aqui quem aciona é o botão Simular pagamento.
route('POST', '/cobrancas/:id/confirmar', (ctx) => {
  const c = carregar(Number(ctx.params.id));
  if (c.status === 'aprovado') return [200, { cobranca: view(c) }]; // repetir não faz mal
  if (c.status !== 'aguardando') fail(409, c.status === 'expirado' ? 'Este Pix expirou. Gere um novo.' : `Cobrança está "${c.status}".`);
  db.prepare("UPDATE cobrancas SET status = 'aprovado', autorizacao = ?, pago_em = ? WHERE id = ?").run(String(crypto.randomInt(100000, 999999)), now(), c.id);
  return [200, { cobranca: view(carregar(c.id)) }];
});

// Devolve o dinheiro (pedido pago que foi cancelado)
route('POST', '/cobrancas/:id/estornar', (ctx) => {
  const c = carregar(Number(ctx.params.id));
  if (c.status === 'estornado') return [200, { cobranca: view(c) }];
  if (c.status !== 'aprovado') fail(409, 'Só dá para estornar pagamento aprovado.');
  db.prepare("UPDATE cobrancas SET status = 'estornado', estornado_em = ?, motivo = ? WHERE id = ?").run(now(), String(ctx.body.motivo || 'Pedido cancelado').slice(0, 200), c.id);
  return [200, { cobranca: view(carregar(c.id)) }];
});

route('GET', '/cobrancas/:id', (ctx) => [200, { cobranca: view(carregar(Number(ctx.params.id))) }]);

// Lista + resumo de vendas. Filtros: pedido_id, pagador_id, recebedor_id.
route('GET', '/cobrancas', (ctx) => {
  expirar();
  const where = [], params = [];
  for (const k of ['pedido_id', 'pagador_id', 'recebedor_id']) {
    if (ctx.query[k] !== undefined) { if (!/^\d+$/.test(ctx.query[k])) fail(400, `${k} inválido.`); where.push(`${k} = ?`); params.push(Number(ctx.query[k])); }
  }
  const w = where.length ? 'WHERE ' + where.join(' AND ') : '';
  const limit = Math.min(Math.max(parseInt(ctx.query.limit, 10) || 20, 1), 100);
  const offset = Math.max(parseInt(ctx.query.offset, 10) || 0, 0);
  const total = db.prepare(`SELECT COUNT(*) AS n FROM cobrancas ${w}`).get(...params).n;
  const rows = db.prepare(`SELECT * FROM cobrancas ${w} ORDER BY id DESC LIMIT ? OFFSET ?`).all(...params, limit, offset);
  const r = db.prepare(`SELECT COUNT(*) AS q, COALESCE(SUM(valor_centavos),0) AS bruto, COALESCE(SUM(taxa_centavos),0) AS taxa,
      COALESCE(SUM(liquido_centavos),0) AS liquido, COALESCE(SUM(metodo = 'pix'),0) AS pix, COALESCE(SUM(metodo = 'cartao'),0) AS cartao
    FROM cobrancas ${w ? w + " AND status = 'aprovado'" : "WHERE status = 'aprovado'"}`).get(...params);
  const estornos = db.prepare(`SELECT COUNT(*) AS n FROM cobrancas ${w ? w + " AND status = 'estornado'" : "WHERE status = 'estornado'"}`).get(...params).n;
  return [200, {
    cobrancas: rows.map(view), total, limit, offset, has_more: offset + limit < total,
    resumo: { vendas: Number(r.q), bruto: r.bruto / 100, taxa: r.taxa / 100, liquido: r.liquido / 100, pix: Number(r.pix), cartao: Number(r.cartao), estornos },
  }];
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
    const [status, data] = matched.handler(ctx);
    send(res, status, data);
  } catch (err) {
    if (err instanceof HttpError) return send(res, err.status, { error: err.message });
    console.error(err);
    send(res, 500, { error: 'Erro interno do serviço de pagamentos.' });
  }
});

const PORT = Number(process.env.PAG_PORT || 3002);
const HOST = process.env.PAG_HOST || '127.0.0.1';
if (require.main === module) {
  server.listen(PORT, HOST, () => console.log(`Microsserviço de pagamentos (SIMULADO) em http://${HOST}:${PORT}`));
}
module.exports = server;
