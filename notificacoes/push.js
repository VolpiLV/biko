// Notificação PUSH (pop-up no celular mesmo com o app fechado), pelo Firebase Cloud Messaging (FCM).
//
// - O app manda o "token do aparelho" para a API, que repassa para cá (POST /dispositivos).
// - Quando uma notificação é criada (POST /eventos), este módulo envia o push para os aparelhos
//   de quem recebeu. Falha no push nunca derruba a notificação: ela continua no sino do app.
// - Só funciona com a chave do Firebase (mesma do Firestore). Sem chave (Firestore em memória),
//   o envio é desligado e o app continua mostrando os pop-ups enquanto está aberto.
const crypto = require('crypto');
const { colecao } = require('../store');
const { firebaseAdmin } = require('../firebase');

// Banco próprio: um documento por aparelho (id = hash do token, que pode ser longo e ter ":").
const D = colecao('notif_dispositivos');
const docId = (token) => crypto.createHash('sha256').update(token).digest('hex');
const tokenValido = (t) => typeof t === 'string' && t.length >= 20 && t.length <= 4096 && /^[\w:.\-]+$/.test(t);

// O mesmo aparelho trocando de conta passa a ser do novo usuário (não avisa a conta antiga).
async function registrar(usuarioId, token, plataforma = 'android') {
  await D.set(docId(token), { token, usuario_id: usuarioId, plataforma: String(plataforma).slice(0, 20), atualizado_em: Date.now() });
}
async function remover(token) { await D.remove(docId(token)); }
const doUsuario = async (uid) => (await D.where('usuario_id', '==', uid)).map((d) => d.token);

// Erros do FCM que significam "este token morreu" (app desinstalado, dados apagados...).
const TOKEN_MORTO = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']);

// Quem envia de verdade. Trocável nos testes (usarEnviador). null = push desligado.
let enviador = null;
let enviadorPadraoCarregado = false;
function enviadorPadrao() {
  if (!enviadorPadraoCarregado) {
    enviadorPadraoCarregado = true;
    const admin = firebaseAdmin();
    if (admin) enviador = (msg) => admin.messaging().sendEachForMulticast(msg);
  }
  return enviador;
}
function usarEnviador(fn) { enviador = fn; enviadorPadraoCarregado = true; }
const ligado = () => !!enviadorPadrao();

// Monta a mensagem. "tag" igual à do pop-up do app: se os dois chegarem, um substitui o outro.
function mensagem(n, tokens) {
  return {
    tokens,
    notification: { title: n.titulo, body: n.mensagem },
    data: { notificacao_id: String(n.id), pedido_id: n.pedido_id ? String(n.pedido_id) : '', acao: n.acao },
    android: {
      priority: 'high',
      notification: { channelId: 'biko_pedidos', tag: `notif-${n.id}`, icon: 'ic_stat_biko', color: '#0A84FF' },
    },
  };
}

// Envia uma notificação já gravada (n tem id, usuario_id, titulo, mensagem, pedido_id, acao).
// Devolve quantos aparelhos receberam. Nunca lança erro.
async function enviar(n) {
  const send = enviadorPadrao();
  if (!send) return 0;
  try {
    const tokens = await doUsuario(n.usuario_id);
    if (!tokens.length) return 0;
    const r = await send(mensagem(n, tokens));
    const mortos = [];
    (r.responses || []).forEach((resp, i) => { if (!resp.success && TOKEN_MORTO.has(resp.error?.code)) mortos.push(tokens[i]); });
    await Promise.all(mortos.map(remover));
    return r.successCount || 0;
  } catch (e) {
    console.error('push falhou:', e.message);
    return 0;
  }
}

module.exports = { registrar, remover, doUsuario, enviar, tokenValido, usarEnviador, ligado, mensagem };
