// Testes do microsserviço SOZINHO (sem a API principal). Rodar dentro de notificacoes/:  npm test
const os = require('os');
const path = require('path');
const fs = require('fs');
const assert = require('assert');

const tmp = path.join(os.tmpdir(), `notif-ms-test-${Date.now()}.db`);
process.env.NOTIF_DB = tmp;
process.env.BIKO_FIRESTORE = 'memoria';
const server = require('./server');
const KEY = { 'X-Service-Key': 'biko-dev-key' };

let base, passed = 0;
const results = [];
async function t(name, fn) {
  try { await fn(); passed++; results.push(`  ✔ ${name}`); }
  catch (e) { results.push(`  ✘ ${name}\n      ${e.message}`); process.exitCode = 1; }
}
async function call(method, url, body, headers = KEY) {
  const r = await fetch(base + url, { method, headers: { ...headers, ...(body ? { 'Content-Type': 'application/json' } : {}) }, body: body ? JSON.stringify(body) : undefined });
  return { status: r.status, data: await r.json() };
}
let seq = 1;
const evento = (acao, extra = {}) => ({
  evento_id: seq++, acao, pedido: { id: 10, servico: 'Reparo de vazamentos', data: '2030-05-20', hora: '14:00', hora_fim: '15:00' },
  cliente_id: 2, prestador_id: 3, ator_id: 3, ator_nome: 'Carlos Silva', nota: null, ...extra,
});

(async () => {
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;

  await t('saúde responde sem chave', async () => assert.strictEqual((await call('GET', '/saude', null, {})).data.ok, true));
  await t('sem chave -> 401', async () => assert.strictEqual((await call('POST', '/eventos', evento('confirmado'), {})).status, 401));
  await t('evento inválido -> 400', async () => {
    assert.strictEqual((await call('POST', '/eventos', { acao: 'confirmado' })).status, 400);
    assert.strictEqual((await call('POST', '/eventos', { evento_id: 1, acao: 'confirmado' })).status, 400);
  });
  await t('ação desconhecida é aceita e ignorada', async () => assert.strictEqual((await call('POST', '/eventos', evento('xyz'))).data.criadas, 0));
  await t('confirmado -> só o cliente recebe, título é o nome da ação', async () => {
    assert.strictEqual((await call('POST', '/eventos', evento('confirmado'))).data.criadas, 1);
    const c = (await call('GET', '/usuarios/2/notificacoes')).data;
    assert.strictEqual(c.notificacoes[0].titulo, 'Pedido confirmado');
    assert.ok(/20\/05\/2030 às 14:00/.test(c.notificacoes[0].mensagem));
    assert.strictEqual((await call('GET', '/usuarios/3/notificacoes')).data.total, 0);
  });
  await t('novo pedido (cliente fez) -> prestador recebe', async () => {
    await call('POST', '/eventos', evento('pendente', { ator_id: 2, ator_nome: 'Maria Cliente' }));
    const n = (await call('GET', '/usuarios/3/notificacoes')).data.notificacoes[0];
    assert.strictEqual(n.titulo, 'Novo pedido');
    assert.ok(/Maria Cliente/.test(n.mensagem));
  });
  await t('cancelado pelo admin -> cliente e prestador recebem', async () => {
    assert.strictEqual((await call('POST', '/eventos', evento('cancelado', { ator_id: 1, ator_nome: 'Admin', nota: 'Duplicado' }))).data.criadas, 2);
  });
  await t('remarcado em cascata (sem autor) -> cliente recebe', async () => {
    assert.strictEqual((await call('POST', '/eventos', evento('remarcado', { ator_id: null, ator_nome: null, nota: 'Novo horário 14:15–15:15' }))).data.criadas, 1);
  });
  await t('mesmo evento 2x não duplica', async () => {
    const e = evento('concluido');
    assert.strictEqual((await call('POST', '/eventos', e)).data.criadas, 1);
    assert.strictEqual((await call('POST', '/eventos', e)).data.criadas, 0);
  });
  await t('contagem, marcar lida e marcar todas', async () => {
    const antes = (await call('GET', '/usuarios/2/notificacoes/contagem')).data.nao_lidas;
    const id = (await call('GET', '/usuarios/2/notificacoes')).data.notificacoes[0].id;
    assert.strictEqual((await call('POST', `/usuarios/3/notificacoes/${id}/lida`, {})).status, 404); // não é dele
    assert.strictEqual((await call('POST', `/usuarios/2/notificacoes/${id}/lida`, {})).data.nao_lidas, antes - 1);
    assert.strictEqual((await call('GET', '/usuarios/2/notificacoes?nao_lidas=1')).data.total, antes - 1);
    await call('POST', '/usuarios/2/notificacoes/lidas', {});
    assert.strictEqual((await call('GET', '/usuarios/2/notificacoes/contagem')).data.nao_lidas, 0);
  });

  console.log('\nResultados:\n' + results.join('\n'));
  console.log(`\n${passed}/${results.length} testes passaram`);
  server.close();
  for (const f of [tmp, tmp + '-wal', tmp + '-shm']) { try { fs.rmSync(f, { force: true }); } catch (e) { /* ok */ } }
  process.exit(process.exitCode || 0);
})();
