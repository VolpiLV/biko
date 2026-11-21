// Testes do microsserviço de pagamentos SOZINHO. Rodar dentro de pagamentos/:  npm test
const os = require('os');
const path = require('path');
const fs = require('fs');
const assert = require('assert');

const tmp = path.join(os.tmpdir(), `pag-ms-test-${Date.now()}.db`);
process.env.PAG_DB = tmp;
const server = require('./server');
const { db } = require('./db');
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
const cob = (pedido, extra = {}) => ({ pedido_id: pedido, descricao: 'Reparo de vazamentos', valor_centavos: 12000, pagador_id: 2, pagador_nome: 'Maria', recebedor_id: 3, recebedor_nome: 'Carlos', metodo: 'pix', ...extra });

(async () => {
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;

  await t('saúde responde sem chave e avisa que é simulado', async () => assert.strictEqual((await call('GET', '/saude', null, {})).data.simulado, true));
  await t('sem chave -> 401', async () => assert.strictEqual((await call('POST', '/cobrancas', cob(1), {})).status, 401));
  await t('dados inválidos -> 400', async () => {
    assert.strictEqual((await call('POST', '/cobrancas', cob(1, { valor_centavos: 0 }))).status, 400);
    assert.strictEqual((await call('POST', '/cobrancas', cob(1, { metodo: 'boleto' }))).status, 400);
    assert.strictEqual((await call('POST', '/cobrancas', cob(1, { metodo: 'cartao', cartao: { final: '1' } }))).status, 400);
    assert.strictEqual((await call('POST', '/cobrancas', cob(1, { metodo: 'cartao', cartao: { final: '4242', parcelas: 7 } }))).status, 400);
  });
  let pix;
  await t('Pix: aguardando, com código, taxa de 10%', async () => {
    const r = await call('POST', '/cobrancas', cob(1));
    pix = r.data.cobranca;
    assert.strictEqual(r.status, 201);
    assert.strictEqual(pix.status, 'aguardando');
    assert.ok(pix.pix_copia_cola.includes('BR.GOV.BCB.PIX'));
    assert.deepStrictEqual([pix.valor, pix.taxa, pix.liquido], [120, 12, 108]);
  });
  await t('Pix novo para o mesmo pedido substitui o antigo', async () => {
    const novo = (await call('POST', '/cobrancas', cob(1))).data.cobranca;
    assert.strictEqual((await call('GET', `/cobrancas/${pix.id}`)).data.cobranca.status, 'expirado');
    pix = novo;
  });
  await t('confirmar aprova; repetir não muda nada; pagar de novo -> 409', async () => {
    const c = (await call('POST', `/cobrancas/${pix.id}/confirmar`, {})).data.cobranca;
    assert.strictEqual(c.status, 'aprovado');
    assert.ok(c.autorizacao && c.pago_em);
    assert.strictEqual(c.pix_copia_cola, null);
    assert.strictEqual((await call('POST', `/cobrancas/${pix.id}/confirmar`, {})).data.cobranca.autorizacao, c.autorizacao);
    assert.strictEqual((await call('POST', '/cobrancas', cob(1))).status, 409);
  });
  await t('Pix vencido vira expirado e não confirma mais', async () => {
    const p = (await call('POST', '/cobrancas', cob(2))).data.cobranca;
    db.prepare('UPDATE cobrancas SET expira_em = 1 WHERE id = ?').run(p.id);
    assert.strictEqual((await call('POST', `/cobrancas/${p.id}/confirmar`, {})).status, 409);
  });
  await t('cartão aprova na hora (só guarda o final); final 0002 recusa', async () => {
    const ok = (await call('POST', '/cobrancas', cob(3, { metodo: 'cartao', cartao: { final: '4242', bandeira: 'Elo', parcelas: 2 } }))).data.cobranca;
    assert.strictEqual(ok.status, 'aprovado');
    assert.deepStrictEqual(ok.cartao, { final: '4242', bandeira: 'Elo' });
    const no = (await call('POST', '/cobrancas', cob(4, { metodo: 'cartao', cartao: { final: '0002' } }))).data.cobranca;
    assert.strictEqual(no.status, 'recusado');
    assert.ok(/recusado/.test(no.motivo));
  });
  await t('estorno só de aprovado', async () => {
    const p = (await call('POST', '/cobrancas', cob(5))).data.cobranca;
    assert.strictEqual((await call('POST', `/cobrancas/${p.id}/estornar`, {})).status, 409);
    assert.strictEqual((await call('POST', `/cobrancas/${pix.id}/estornar`, { motivo: 'Cancelado' })).data.cobranca.status, 'estornado');
  });
  await t('lista e resumo por recebedor', async () => {
    const d = (await call('GET', '/cobrancas?recebedor_id=3')).data;
    assert.ok(d.total >= 5);
    assert.strictEqual(d.resumo.vendas, 1);      // só o cartão 4242 continua aprovado
    assert.strictEqual(d.resumo.estornos, 1);
    assert.strictEqual(d.resumo.liquido, 108);
    assert.strictEqual((await call('GET', '/cobrancas?recebedor_id=abc')).status, 400);
  });

  console.log('\nResultados:\n' + results.join('\n'));
  console.log(`\n${passed}/${results.length} testes passaram`);
  server.close();
  for (const f of [tmp, tmp + '-wal', tmp + '-shm']) { try { fs.rmSync(f, { force: true }); } catch (e) { /* ok */ } }
  process.exit(process.exitCode || 0);
})();
