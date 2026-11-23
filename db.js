// Banco da API principal: Firebase / Cloud Firestore (antes era SQLite).
// Cada tabela antiga virou uma coleção:
//   users, sessions (id do documento = token), password_resets (id = código), user_photos (id = usuário),
//   services, orders, order_events, notification_outbox
// A conexão fica em firebase.js e o acesso genérico em store.js.
const crypto = require('crypto');
const { colecao, exclusivo } = require('./store');

const T = {
  users: colecao('users'),
  sessions: colecao('sessions'),
  resets: colecao('password_resets'),
  photos: colecao('user_photos'),
  services: colecao('services'),
  orders: colecao('orders'),
  events: colecao('order_events'),
  outbox: colecao('notification_outbox'),
};

// ---- hash de senha (scrypt + salt aleatório) ----
function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(password, salt, 64).toString('hex');
  return `scrypt$${salt}$${hash}`;
}
function verifyPassword(password, stored) {
  const [, salt, hash] = String(stored).split('$');
  if (!salt || !hash) return false;
  const test = crypto.scryptSync(password, salt, 64);
  const real = Buffer.from(hash, 'hex');
  return test.length === real.length && crypto.timingSafeEqual(test, real);
}

// Usuário novo com os mesmos campos padrão que a tabela tinha no SQLite
const newUser = (name, email, phone, password, role) => ({
  name, email, phone: phone || null, password_hash: hashPassword(password), role, active: 1,
  created_at: new Date().toISOString().slice(0, 19).replace('T', ' '), photo_v: 0,
});

// Dados de demonstração (só se o banco estiver vazio). Roda uma vez quando a API sobe.
async function seed() {
  if ((await T.users.all()).length === 0) {
    await T.users.insert(newUser('Administrador Biko', 'admin@biko.com', '(47) 99999-0001', 'Admin@123', 'admin'));
    await T.users.insert(newUser('Maria Cliente', 'cliente@biko.com', '(47) 99999-0002', 'Cliente@123', 'cliente'));
    await T.users.insert(newUser('Carlos Silva', 'prestador@biko.com', '(47) 99999-0003', 'Prestador@123', 'prestador'));
  }
  if ((await T.services.all()).length > 0) return;
  const carlos = await T.users.first('email', '==', 'prestador@biko.com');
  const maria = await T.users.first('email', '==', 'cliente@biko.com');
  if (!carlos || !maria) return;
  let joana = await T.users.first('email', '==', 'joana@biko.com');
  if (!joana) joana = { id: await T.users.insert(newUser('Joana Pereira', 'joana@biko.com', '(47) 99999-0004', 'Joana@123', 'prestador')) };

  const svc = (provider_id, title, category, description, price_cents, duration_min) =>
    T.services.insert({ provider_id, title, category, description, price_cents, duration_min, active: 1, created_at: new Date().toISOString() });
  const s1 = await svc(carlos.id, 'Reparo de vazamentos', 'Encanador', 'Torneiras, canos e descargas com vazamento.', 12000, 60);
  await svc(carlos.id, 'Instalação de chuveiro elétrico', 'Eletricista', 'Instalação e troca de chuveiro, com fiação segura.', 15000, 90);
  await svc(joana.id, 'Reparo de telhado e goteiras', 'Telhado & Reparador', 'Troca de telhas e vedação de goteiras.', 28000, 180);
  await svc(joana.id, 'Pintura de quarto ou sala', 'Pintor', 'Pintura interna com acabamento limpo.', 35000, 240);
  await svc(joana.id, 'Faxina completa', 'Limpeza', 'Limpeza geral de casa ou apartamento.', 20000, 240);

  // Pedido antigo já confirmado (o prestador consegue marcar como concluído) e um pendente no futuro.
  const at = (days, h, m) => { const d = new Date(); d.setDate(d.getDate() + days); d.setHours(h, m, 0, 0); return d.getTime(); };
  const order = (o) => T.orders.insert({
    client_id: maria.id, provider_id: carlos.id, service_id: s1, service_title: 'Reparo de vazamentos', category: 'Encanador',
    price_cents: 12000, address: 'Rua das Flores, 120 - Centro', status_reason: null, completed_ts: null,
    started_ts: null, planned_end_ts: null, extended_min: 0, delay_min: 0, delay_reason: null,
    payment_status: null, payment_id: null, payment_code: null, ...o,
  });
  const event = (order_id, status, actor_id, note, created_at) => T.events.insert({ order_id, status, actor_id, note, created_at });
  const t0 = at(-3, 9, 0);
  const past = await order({ start_ts: at(-1, 10, 0), end_ts: at(-1, 11, 0), notes: 'Vazamento na pia da cozinha.', status: 'confirmado', created_at: t0, updated_at: t0 + 3600e3 });
  await event(past, 'pendente', maria.id, 'Pedido criado', t0);
  await event(past, 'confirmado', carlos.id, null, t0 + 3600e3);
  const t1 = Date.now();
  const next = await order({ start_ts: at(3, 14, 0), end_ts: at(3, 15, 0), notes: 'Descarga do banheiro não para de pingar.', status: 'pendente', created_at: t1, updated_at: t1 });
  await event(next, 'pendente', maria.id, 'Pedido criado', t1);
}

const pronto = seed();
pronto.catch((e) => console.error('[firestore] não foi possível preparar o banco:', e.message));

module.exports = { T, pronto, newUser, hashPassword, verifyPassword, tx: exclusivo };
