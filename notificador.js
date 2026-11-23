// Ponte entre a API principal e o MICROSSERVIÇO DE NOTIFICAÇÕES (pasta notificacoes/).
//
// 1) publicar(): grava o evento na caixa de saída (coleção notification_outbox do Firestore)
//    junto com a mudança do pedido. Não faz chamada de rede aqui: mudar um pedido nunca fica
//    esperando nem falha por causa das notificações.
// 2) flush(): entrega o que está pendente para o microsserviço (POST /eventos). Se ele estiver
//    fora do ar, tenta de novo depois (espera 2 s, 4 s, 8 s... até 60 s).
// 3) chamar(): usado pelas rotas /api/notificacoes para consultar o microsserviço.
const { T } = require('./db');
const { chamarServico, ServicoForaDoAr } = require('./servicos');

const notifUrl = () => (process.env.NOTIF_URL || 'http://127.0.0.1:3001').replace(/\/$/, '');
const NOTIF_KEY = process.env.NOTIF_KEY || 'biko-dev-key';
const TIMEOUT_MS = 3000;
const INTERVALO_MS = 3000;

const chamar = (method, path, body) => chamarServico(notifUrl(), NOTIF_KEY, method, path, body, TIMEOUT_MS);

// Chamado por addEvent no server.js, logo depois de gravar o evento do pedido
async function publicar(eventoId, orderId, acao, atorId, nota) {
  const o = await T.orders.get(orderId);
  if (!o) return;
  const ator = atorId ? await T.users.get(atorId) : null;
  const pad = (n) => String(n).padStart(2, '0');
  const d = new Date(o.start_ts), f = new Date(o.end_ts);
  const payload = {
    evento_id: Number(eventoId), acao,
    pedido: { id: o.id, servico: o.service_title, data: `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`, hora: `${pad(d.getHours())}:${pad(d.getMinutes())}`, hora_fim: `${pad(f.getHours())}:${pad(f.getMinutes())}` },
    cliente_id: o.client_id, prestador_id: o.provider_id,
    ator_id: atorId ?? null, ator_nome: ator ? ator.name : null,
    nota: nota || null,
  };
  await T.outbox.insert({ payload: JSON.stringify(payload), attempts: 0, next_try_at: Date.now(), sent_at: null, last_error: null });
}

// Primeira vez que o banco é usado: a caixa de saída está vazia, então os eventos dos últimos
// 7 dias (inclusive os pedidos de exemplo) viram notificações. Assim ninguém começa com o sino vazio.
async function preencherInicial() {
  if ((await T.outbox.all()).length > 0) return 0;
  const evs = (await T.events.where('created_at', '>=', Date.now() - 7 * 24 * 3600e3)).sort((a, b) => a.id - b.id);
  for (const e of evs) await publicar(e.id, e.order_id, e.status, e.actor_id, e.note);
  return evs.length;
}

let rodando = null;
// Entrega os eventos pendentes, em ordem. Para no primeiro erro de rede (o serviço caiu: não adianta insistir agora).
// forcar = true ignora a espera entre tentativas (usado quando sabemos que o serviço voltou).
function flush(forcar = false) {
  if (rodando) return rodando;
  rodando = (async () => {
    const agora = Date.now();
    const pend = (await T.outbox.where('sent_at', '==', null))
      .filter((i) => forcar || i.next_try_at <= agora)
      .sort((a, b) => a.id - b.id)
      .slice(0, 50);
    let enviados = 0;
    for (const item of pend) {
      try {
        const r = await chamar('POST', '/eventos', JSON.parse(item.payload));
        // 2xx = entregue. 4xx = evento com defeito: marca como enviado para não travar a fila, e guarda o erro.
        await T.outbox.update(item.id, { sent_at: Date.now(), attempts: item.attempts + 1, last_error: r.status >= 400 ? String(r.data.error || r.status) : null });
        enviados++;
      } catch (e) {
        const espera = Math.min(60000, 2000 * 2 ** item.attempts);
        await T.outbox.update(item.id, { attempts: item.attempts + 1, next_try_at: Date.now() + espera, last_error: String(e.message).slice(0, 200) });
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
const pendentes = async () => (await T.outbox.where('sent_at', '==', null)).length;

module.exports = { publicar, preencherInicial, flush, chamar, iniciar, parar, pendentes, ServicoForaDoAr };
