// Banco PRÓPRIO do microsserviço de notificações (notificacoes.db).
// Ele não enxerga o biko.db: tudo o que precisa saber chega pelos eventos que a API principal publica.
const { DatabaseSync } = require('node:sqlite');
const path = require('path');

const db = new DatabaseSync(process.env.NOTIF_DB || path.join(__dirname, 'notificacoes.db'));
db.exec('PRAGMA journal_mode = WAL');

db.exec(`
CREATE TABLE IF NOT EXISTS notificacoes (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  evento_id  INTEGER NOT NULL,            -- id do evento na API principal (order_events.id)
  usuario_id INTEGER NOT NULL,            -- quem recebe
  acao       TEXT NOT NULL,               -- pendente, confirmado, atrasado, remarcado...
  titulo     TEXT NOT NULL,               -- nome da ação, ex.: "Pedido confirmado"
  mensagem   TEXT NOT NULL,
  pedido_id  INTEGER,
  lida       INTEGER NOT NULL DEFAULT 0,
  criada_em  INTEGER NOT NULL,
  UNIQUE (evento_id, usuario_id)          -- o mesmo evento chegando 2x não duplica a notificação
);
CREATE INDEX IF NOT EXISTS idx_notif_usuario ON notificacoes(usuario_id, lida, id);
`);

module.exports = { db };
