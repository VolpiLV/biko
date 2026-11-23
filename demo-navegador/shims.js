// ===== Biko DEMO no navegador =====
// Roda o MESMO código do backend (server.js, notificador.js e os dois microsserviços) dentro da
// página, trocando só o que é do Node: http -> fetch interceptado, crypto -> Web Crypto.
// Sem chave do Firebase, o firebase.js usa o Firestore em memória (o mesmo dos testes). Os três "servidores" continuam separados, com bancos separados,
// e conversam por fetch como no projeto de verdade.
(function () {
  'use strict';
  const Buffer = window.__BikoBuffer;
  const STORE_KEY = 'biko-demo-v2';

  // ---------- persistência leve (só neste navegador) ----------
  let saved = {};
  try { saved = JSON.parse(localStorage.getItem(STORE_KEY) || '{}', (k, v) => v); } catch (e) { saved = {}; }
  function b64(u8) { let s = ''; for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000)); return btoa(s); }
  function unb64(s) { const bin = atob(s); const u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); return u; }
  let saveTimer = null;
  let fsdb = null; // Firestore em memória (preenchido depois que os módulos carregam)
  // Uint8Array (fotos) vira { __b64 } no JSON
  const enc = (k, v) => (v instanceof Uint8Array ? { __b64: b64(v) } : v);
  const dec = (k, v) => (v && typeof v === 'object' && typeof v.__b64 === 'string' ? Buffer.from(unb64(v.__b64)) : v);
  function scheduleSave() {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      try { localStorage.setItem(STORE_KEY, JSON.stringify({ cookie: jar.cookie, firestore: fsdb ? fsdb._dump() : null }, enc)); }
      catch (e) { /* sem localStorage: a demo só não lembra ao recarregar */ }
    }, 300);
  }

  // ---------- crypto ----------
  const rand = (n) => { const u = new Uint8Array(n); crypto.getRandomValues(u); return u; };
  const nodeCrypto = {
    randomBytes: (n) => Buffer.from(rand(n)),
    randomInt: (a, b) => a + Math.floor((crypto.getRandomValues(new Uint32Array(1))[0] / 4294967296) * (b - a)),
    // Só para a demonstração: um "hash" rápido no lugar do scrypt (o projeto real usa scrypt do Node).
    scryptSync: (pw, salt, len) => {
      const out = Buffer.alloc(len); let h = 2166136261;
      const src = String(salt) + '|' + String(pw);
      for (let r = 0; r < len; r++) {
        for (let i = 0; i < src.length; i++) { h ^= src.charCodeAt(i) + r; h = Math.imul(h, 16777619) >>> 0; }
        out[r] = h & 0xff;
      }
      return out;
    },
    timingSafeEqual: (a, b) => { if (a.length !== b.length) throw new Error('length'); let d = 0; for (let i = 0; i < a.length; i++) d |= a[i] ^ b[i]; return d === 0; },
  };

  // ---------- path / fs / process ----------
  const pathMod = {
    sep: '/',
    join: (...p) => pathMod.normalize(p.join('/')),
    normalize: (p) => { const out = []; for (const seg of String(p).split('/')) { if (!seg || seg === '.') continue; if (seg === '..') out.pop(); else out.push(seg); } return '/' + out.join('/'); },
    dirname: (p) => p.slice(0, p.lastIndexOf('/')) || '/',
    extname: (p) => { const m = /\.[^./]+$/.exec(p); return m ? m[0] : ''; },
  };
  const fsMod = { readFile: (f, cb) => cb(new Error('sem arquivos na demo')), existsSync: () => false, readFileSync: () => { throw new Error('sem arquivos na demo'); } };
  const processShim = { env: {}, execPath: '', exitCode: 0, on() {}, exit() {} };

  // setInterval do Node tem .unref(); o do navegador não
  const nodeTimer = (id) => ({ id, unref() { return this; }, ref() { return this; } });
  const sInt = (fn, ms) => nodeTimer(window.setInterval(fn, ms));
  const cInt = (t) => window.clearInterval(t && typeof t === 'object' ? t.id : t);

  // ---------- http: cada createServer vira um "servidor" chamado pelo fetch ----------
  const servers = [];
  const httpMod = {
    createServer(handler) {
      const listeners = {};
      const srv = {
        handler,
        on(ev, cb) { (listeners[ev] = listeners[ev] || []).push(cb); return srv; },
        emit(ev) { (listeners[ev] || []).forEach((cb) => cb()); },
        listen() { return srv; }, close() { srv.emit('close'); }, address() { return { port: 0 }; },
      };
      servers.push(srv);
      return srv;
    },
  };

  // ---------- registro de módulos (CommonJS simples) ----------
  const defs = window.__BikoModules;
  const cache = {};
  function resolve(from, req) {
    if (!req.startsWith('.')) return req;
    let p = pathMod.join(pathMod.dirname(from), req);
    if (!p.endsWith('.js')) p += '.js';
    return p;
  }
  function makeRequire(from) {
    return (req) => {
      const core = { http: httpMod, fs: fsMod, path: pathMod, crypto: nodeCrypto }[req];
      if (core) return core;
      const id = resolve(from, req);
      if (cache[id]) return cache[id].exports;
      const def = defs[id];
      if (!def) throw new Error('Módulo não encontrado: ' + id);
      const module = { exports: {}, id };
      cache[id] = module;
      def(makeRequire(id), module, module.exports, processShim, Buffer, sInt, cInt, pathMod.dirname(id), id);
      return module.exports;
    };
  }

  // Firestore em memória: restaura o que estava salvo neste navegador ANTES de a API gravar os dados de exemplo
  const req = makeRequire('/');
  fsdb = req('./firebase.js').firestore();
  if (saved.firestore) {
    try { fsdb._load(JSON.parse(JSON.stringify(saved.firestore), dec)); } catch (e) { /* dados antigos: começa do zero */ }
  }
  // Ordem de inicialização: microsserviços primeiro, depois a API
  const notifServer = req('./notificacoes/server.js');
  const pagServer = req('./pagamentos/server.js');
  const apiServer = req('./server.js');
  const byPort = { '3000': apiServer, '3001': notifServer, '3002': pagServer };

  // Painel da demo pode "derrubar" um microsserviço para mostrar que o resto continua
  const down = { '3001': false, '3002': false };
  window.BikoDemo = {
    setDown(port, value) { down[port] = !!value; },
    isDown: (port) => down[port],
    reset() { try { localStorage.removeItem(STORE_KEY); } catch (e) { /* ok */ } location.reload(); },
  };

  // ---------- cookies (o navegador não guarda cookie de um fetch interceptado) ----------
  const jar = { cookie: saved.cookie || '' };

  function callServer(srv, method, url, headers, bodyText) {
    return new Promise((resolve, reject) => {
      const listeners = {};
      const reqObj = {
        method, url, headers, socket: { remoteAddress: '127.0.0.1' },
        on(ev, cb) { (listeners[ev] = listeners[ev] || []).push(cb); return reqObj; },
        destroy() {},
      };
      let status = 200, resHeaders = {};
      const chunks = [];
      const resObj = {
        writeHead(s, h) { status = s; resHeaders = h || {}; },
        end(b) {
          if (b !== undefined && b !== null) chunks.push(typeof b === 'string' ? new TextEncoder().encode(b) : new Uint8Array(b));
          resolve({ status, headers: resHeaders, body: chunks });
        },
      };
      try { Promise.resolve(srv.handler(reqObj, resObj)).catch(reject); } catch (e) { reject(e); }
      setTimeout(() => {
        if (bodyText) (listeners.data || []).forEach((cb) => cb(Buffer.from(bodyText)));
        (listeners.end || []).forEach((cb) => cb());
      }, 0);
    });
  }

  const realFetch = window.fetch.bind(window);
  window.fetch = async function (input, init = {}) {
    const raw = typeof input === 'string' ? input : input.url;
    const u = new URL(raw, location.href);
    let port = null;
    if (u.origin === location.origin) port = u.pathname.startsWith('/api/') ? '3000' : null;
    else if (u.hostname === '127.0.0.1' || u.hostname === 'localhost') port = u.port;
    if (!port || !byPort[port]) return realFetch(input, init);
    if (down[port]) {
      await new Promise((r) => setTimeout(r, 300));
      throw new TypeError('fetch failed (microsserviço desligado no painel da demo)');
    }
    const headers = {};
    new Headers(init.headers || {}).forEach((v, k) => { headers[k] = v; });
    if (port === '3000' && jar.cookie) headers.cookie = jar.cookie;
    const r = await callServer(byPort[port], (init.method || 'GET').toUpperCase(), u.pathname + u.search, headers, init.body || '');
    if (port === '3000') {
      const sc = r.headers['Set-Cookie'] || r.headers['set-cookie'];
      if (sc) { const first = String(sc).split(';')[0]; jar.cookie = first.endsWith('=') ? '' : first; }
    }
    scheduleSave();
    const total = r.body.reduce((n, c) => n + c.length, 0);
    const body = new Uint8Array(total); let off = 0;
    for (const c of r.body) { body.set(c, off); off += c.length; }
    const h = new Headers();
    for (const [k, v] of Object.entries(r.headers)) if (!/^set-cookie$/i.test(k) && !/^content-length$/i.test(k)) h.set(k, String(v));
    return new Response(r.status === 204 ? null : body, { status: r.status, headers: h });
  };

  // Foto de perfil: <img src="/api/photo/..."> não passa pelo fetch, então troca por blob
  const photoCache = new Map();
  async function fixPhotos(root) {
    for (const img of root.querySelectorAll('img[src^="/api/photo/"]')) {
      const src = img.getAttribute('src');
      if (!photoCache.has(src)) {
        photoCache.set(src, window.fetch(src).then((r) => (r.ok ? r.blob() : null)).then((b) => (b ? URL.createObjectURL(b) : '')));
      }
      const url = await photoCache.get(src);
      if (url && img.getAttribute('src') === src) img.src = url;
    }
  }
  new MutationObserver(() => fixPhotos(document)).observe(document.documentElement, { childList: true, subtree: true });

  // "Liga" os servidores: começa a entregar a fila de notificações e os estornos
  servers.forEach((s) => s.emit('listening'));
})();
