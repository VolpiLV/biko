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

  // ---------- push (pop-up no celular) ----------
  const TOK = (s) => `tok-${s}-` + 'x'.repeat(40);
  const enviados = [];
  let respostaFalsa = null;
  server.push.usarEnviador(async (msg) => {
    enviados.push(msg);
    return respostaFalsa ? respostaFalsa(msg) : { successCount: msg.tokens.length, responses: msg.tokens.map(() => ({ success: true })) };
  });
  const esperarPush = async (n) => { for (let i = 0; i < 50 && enviados.length < n; i++) await new Promise((r) => setTimeout(r, 10)); };
  const pausa = () => new Promise((r) => setTimeout(r, 50));

  await t('dispositivo: token inválido, usuário inválido ou sem chave -> recusa', async () => {
    assert.strictEqual((await call('POST', '/dispositivos', { usuario_id: 2, token: 'curto' })).status, 400);
    assert.strictEqual((await call('POST', '/dispositivos', { usuario_id: 2, token: 'tem espaço ' + 'x'.repeat(30) })).status, 400);
    assert.strictEqual((await call('POST', '/dispositivos', { usuario_id: 0, token: TOK('a') })).status, 400);
    assert.strictEqual((await call('POST', '/dispositivos', { usuario_id: 2, token: TOK('a') }, {})).status, 401);
  });
  await t('push: notificação nova vai para o aparelho de quem recebe (título, texto, pedido e tag)', async () => {
    assert.strictEqual((await call('POST', '/dispositivos', { usuario_id: 2, token: TOK('maria') })).data.push_ligado, true);
    await call('POST', '/dispositivos', { usuario_id: 3, token: TOK('carlos') });
    enviados.length = 0;
    const ev = evento('confirmado');
    assert.strictEqual((await call('POST', '/eventos', ev)).data.criadas, 1);
    await esperarPush(1);
    assert.strictEqual(enviados.length, 1, 'só o cliente recebe; o prestador fez a ação');
    const m = enviados[0];
    assert.deepStrictEqual(m.tokens, [TOK('maria')]);
    assert.strictEqual(m.notification.title, 'Pedido confirmado');
    assert.ok(/Carlos Silva/.test(m.notification.body));
    assert.strictEqual(m.data.pedido_id, '10');
    assert.strictEqual(m.android.priority, 'high');
    assert.strictEqual(m.android.notification.channelId, 'biko_pedidos');
    assert.match(m.android.notification.tag, /^notif-\d+$/);
    // o mesmo evento reenviado não cria notificação nem manda push de novo
    assert.strictEqual((await call('POST', '/eventos', ev)).data.criadas, 0);
    await pausa();
    assert.strictEqual(enviados.length, 1);
  });
  await t('push: aparelho que troca de conta passa a avisar só a conta nova', async () => {
    await call('POST', '/dispositivos', { usuario_id: 3, token: TOK('maria') }); // Carlos entrou no celular da Maria
    enviados.length = 0;
    await call('POST', '/eventos', evento('confirmado'));
    await pausa();
    assert.strictEqual(enviados.length, 0, 'Maria não tem mais aparelho');
    await call('POST', '/eventos', evento('pendente', { ator_id: 2, ator_nome: 'Maria' }));
    await esperarPush(1);
    assert.deepStrictEqual(enviados[0].tokens.sort(), [TOK('carlos'), TOK('maria')].sort());
  });
  await t('push: token morto (app desinstalado) é apagado; erro do Firebase não derruba a notificação', async () => {
    respostaFalsa = (msg) => ({ successCount: 0, responses: msg.tokens.map(() => ({ success: false, error: { code: 'messaging/registration-token-not-registered' } })) });
    enviados.length = 0;
    await call('POST', '/eventos', evento('pendente', { ator_id: 2 }));
    await esperarPush(1);
    await pausa();
    assert.deepStrictEqual(await server.push.doUsuario(3), []);
    respostaFalsa = () => { throw new Error('Firebase fora do ar'); };
    await call('POST', '/dispositivos', { usuario_id: 3, token: TOK('novo') });
    const r = await call('POST', '/eventos', evento('pendente', { ator_id: 2 }));
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.data.criadas, 1);
    await pausa();
    respostaFalsa = null;
  });
  await t('dispositivo: remover desliga o push daquele aparelho', async () => {
    await call('POST', '/dispositivos/remover', { token: TOK('novo') });
    assert.deepStrictEqual(await server.push.doUsuario(3), []);
  });
  await t('push desligado (sem chave do Firebase): nada é enviado e nada quebra', async () => {
    server.push.usarEnviador(null);
    assert.strictEqual((await call('POST', '/dispositivos', { usuario_id: 2, token: TOK('z') })).data.push_ligado, false);
    assert.strictEqual((await call('POST', '/eventos', evento('confirmado'))).data.criadas, 1);
  });

  console.log('\nResultados:\n' + results.join('\n'));
  console.log(`\n${passed}/${results.length} testes passaram`);
  server.close();
  for (const f of [tmp, tmp + '-wal', tmp + '-shm']) { try { fs.rmSync(f, { force: true }); } catch (e) { /* ok */ } }
  process.exit(process.exitCode || 0);
})();
