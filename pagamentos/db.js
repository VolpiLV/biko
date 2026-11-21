// Banco PRÓPRIO do microsserviço de pagamentos (pagamentos.db). Não enxerga o biko.db.
const { DatabaseSync } = require('node:sqlite');
const path = require('path');

const db = new DatabaseSync(process.env.PAG_DB || path.join(__dirname, 'pagamentos.db'));
db.exec('PRAGMA journal_mode = WAL');

db.exec(`
CREATE TABLE IF NOT EXISTS cobrancas (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  codigo          TEXT NOT NULL UNIQUE,     -- código da transação mostrado no comprovante (ex.: BKP-7F3A9C21)
  pedido_id       INTEGER NOT NULL,
  descricao       TEXT NOT NULL,
  pagador_id      INTEGER NOT NULL,         -- cliente
  pagador_nome    TEXT,
  recebedor_id    INTEGER NOT NULL,         -- prestador
  recebedor_nome  TEXT,
  valor_centavos  INTEGER NOT NULL CHECK (valor_centavos > 0),
  taxa_centavos   INTEGER NOT NULL,         -- taxa da plataforma (10%)
  liquido_centavos INTEGER NOT NULL,        -- o que o prestador recebe
  metodo          TEXT NOT NULL CHECK (metodo IN ('pix','cartao')),
  parcelas        INTEGER NOT NULL DEFAULT 1,
  cartao_final    TEXT,                     -- só os 4 últimos dígitos (nunca o número inteiro)
  cartao_bandeira TEXT,
  pix_copia_cola  TEXT,
  autorizacao     TEXT,
  status          TEXT NOT NULL CHECK (status IN ('aguardando','aprovado','recusado','expirado','estornado')),
  motivo          TEXT,
  criada_em       INTEGER NOT NULL,
  expira_em       INTEGER,
  pago_em         INTEGER,
  estornado_em    INTEGER
);
CREATE INDEX IF NOT EXISTS idx_cob_pedido ON cobrancas(pedido_id, id);
CREATE INDEX IF NOT EXISTS idx_cob_pagador ON cobrancas(pagador_id, id);
CREATE INDEX IF NOT EXISTS idx_cob_recebedor ON cobrancas(recebedor_id, id);
`);

module.exports = { db };
