// Banco PRÓPRIO do microsserviço de pagamentos: coleção "cobrancas" no Firebase (Cloud Firestore).
// Não lê as coleções da API principal. Do cartão só guarda os 4 últimos dígitos.
// Campos: id, codigo, pedido_id, descricao, pagador_id/nome, recebedor_id/nome, valor_centavos, taxa_centavos,
// liquido_centavos, metodo, parcelas, cartao_final, cartao_bandeira, pix_copia_cola, autorizacao, status,
// motivo, criada_em, expira_em, pago_em, estornado_em.
const { colecao, exclusivo } = require('../store');

module.exports = { C: colecao('cobrancas'), exclusivo };
