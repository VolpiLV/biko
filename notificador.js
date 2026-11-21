// Ponte entre a API principal e o MICROSSERVIÇO DE NOTIFICAÇÕES (pasta notificacoes/).
//
// 1) publicar(): grava o evento na caixa de saída (tabela notification_outbox), dentro da mesma
//    transação do pedido. Não faz chamada de rede aqui: mudar um pedido nunca fica esperando
//    nem falha por causa das notificações.
// 2) flush(): entrega o que está pendente para o microsserviço (POST /eventos). Se ele estiver
//    fora do ar, tenta de novo depois (espera 2 s, 4 s, 8 s... até 60 s).
// 3) chamar(): usado pelas rotas /api/notificacoes para consultar o microsserviço.
const { db } = require('./db');
const { chamarServico, ServicoForaDoAr } = require('./servicos');

const notifUrl = () => (process.env.NOTIF_URL || 'http://127.0.0.1:3001').replace(/\/$/, '');
const NOTIF_KEY = process.env.NOTIF_KEY || 'biko-dev-key';
const TIMEOUT_MS = 3000;
const INTERVALO_MS = 2000;

const chamar = (method, path, body) => chamarServico(notifUrl(), NOTIF_KEY, method, path, body, TIMEOUT_MS);

// Chamado dentro da transação de quem muda o pedido (addEvent no server.js)
function publicar(eventoId, orderId, acao, atorId, nota) {
  const o = db.prepare(`SELECT o.id, o.client_id, o.provider_id, o.service_title, o.start_ts, o.end_ts, u.name AS ator_nome
    FROM orders o LEFT JOIN users u ON u.id = ? WHERE o.id = ?`).get(atorId ?? null, orderId);
  if (!o) return;
  const pad = (n) => String(n).padStart(2, '0');
  const d = new Date(o.start_ts), f = new Date(o.end_ts);
  const payload = {
    evento_id: Number(eventoId), acao,
    pedido: { id: o.id, servico: o.service_title, data: `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`, hora: `${pad(d.getHours())}:${pad(d.getMinutes())}`, hora_fim: `${pad(f.getHours())}:${pad(f.getMinutes())}` },
    cliente_id: o.client_id, prestador_id: o.provider_id,
    ator_id: atorId ?? null, ator_nome: atorId ? o.ator_nome : null,
    nota: nota || null,
  };
  db.prepare('INSERT INTO notification_outbox (payload, next_try_at) VALUES (?, ?)').run(JSON.stringify(payload), Date.now());
}

// Primeira vez que esta versão roda: a caixa de saída está vazia, então os eventos dos últimos
// 7 dias (inclusive os pedidos de exemplo) viram notificações. Assim ninguém começa com o sino vazio.
function preencherInicial() {
  if (db.prepare('SELECT COUNT(*) AS n FROM notification_outbox').get().n > 0) return 0;
  const evs = db.prepare('SELECT id, order_id, status, actor_id, note FROM order_events WHERE created_at >= ? ORDER BY id').all(Date.now() - 7 * 24 * 3600e3);
  for (const e of evs) publicar(e.id, e.order_id, e.status, e.actor_id, e.note);
  return evs.length;
}

let rodando = null;
// Entrega os eventos pendentes, em ordem. Para no primeiro erro de rede (o serviço caiu: não adianta insistir agora).
// forcar = true ignora a espera entre tentativas (usado quando sabemos que o serviço voltou).
function flush(forcar = false) {
  if (rodando) return rodando;
  rodando = (async () => {
    const pend = db.prepare('SELECT * FROM notification_outbox WHERE sent_at IS NULL AND next_try_at <= ? ORDER BY id LIMIT 50').all(forcar ? Infinity : Date.now());
    let enviados = 0;
    for (const item of pend) {
      try {
        const r = await chamar('POST', '/eventos', JSON.parse(item.payload));
        // 2xx = entregue. 4xx = evento com defeito: marca como enviado para não travar a fila, e guarda o erro.
        db.prepare('UPDATE notification_outbox SET sent_at = ?, attempts = attempts + 1, last_error = ? WHERE id = ?')
          .run(Date.now(), r.status >= 400 ? String(r.data.error || r.status) : null, item.id);
        enviados++;
      } catch (e) {
        const espera = Math.min(60000, 2000 * 2 ** item.attempts);
        db.prepare('UPDATE notification_outbox SET attempts = attempts + 1, next_try_at = ?, last_error = ? WHERE id = ?')
          .run(Date.now() + espera, String(e.message).slice(0, 200), item.id);
        break;
      }
    }
    return enviados;
  })().finally(() => { rodando = null; });
  return rodando;
}

let timer = null;
function iniciar() {
  if (timer) return;
  timer = setInterval(() => { flush().catch(() => {}); }, INTERVALO_MS);
  timer.unref(); // não impede o Node de encerrar
}
function parar() { clearInterval(timer); timer = null; }
const pendentes = () => db.prepare('SELECT COUNT(*) AS n FROM notification_outbox WHERE sent_at IS NULL').get().n;

module.exports = { publicar, preencherInicial, flush, chamar, iniciar, parar, pendentes, ServicoForaDoAr };
