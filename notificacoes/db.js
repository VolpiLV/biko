// Banco PRÓPRIO do microsserviço de notificações: coleção "notificacoes" no Firebase (Cloud Firestore).
// Ele não lê as coleções da API principal: tudo o que precisa saber chega pelos eventos que a API publica.
// Campos de cada documento: id, evento_id, usuario_id, acao, titulo (nome da ação), mensagem, pedido_id, lida, criada_em.
const { colecao, exclusivo } = require('../store');

module.exports = { N: colecao('notificacoes'), exclusivo };
