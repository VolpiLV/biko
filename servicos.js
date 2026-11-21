// Chamada HTTP da API principal para um microsserviço (notificações, pagamentos).
// Sempre manda a chave X-Service-Key, tem tempo limite e transforma "fora do ar" em ServicoForaDoAr.
class ServicoForaDoAr extends Error {}

async function chamarServico(baseUrl, key, method, path, body, timeoutMs = 3000) {
  let res;
  try {
    res = await fetch(baseUrl.replace(/\/$/, '') + path, {
      method,
      headers: { 'X-Service-Key': key, ...(body ? { 'Content-Type': 'application/json' } : {}) },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (e) {
    throw new ServicoForaDoAr(e.message);
  }
  let data = {};
  try { data = await res.json(); } catch { /* sem corpo */ }
  if (res.status >= 500) throw new ServicoForaDoAr(data.error || `HTTP ${res.status}`);
  return { status: res.status, data };
}

module.exports = { chamarServico, ServicoForaDoAr };
