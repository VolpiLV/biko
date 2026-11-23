// Monta a pasta demo/ (página estática que roda o Biko inteiro no navegador).
const fs = require('fs');
const path = require('path');

const SRC = path.join(__dirname, '..');
const OUT = path.join(__dirname, 'saida');
fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT);

// 1) backend: os módulos do projeto, sem mudar uma linha
const mods = ['server.js', 'db.js', 'notificador.js', 'servicos.js', 'firebase.js', 'firestore-memoria.js', 'store.js',
  'notificacoes/server.js', 'notificacoes/db.js', 'pagamentos/server.js', 'pagamentos/db.js'];
let bundle = '// Código do backend do Biko (copiado sem alterações) empacotado para rodar no navegador.\nwindow.__BikoModules = {\n';
for (const m of mods) {
  const code = fs.readFileSync(path.join(SRC, m), 'utf8');
  bundle += `${JSON.stringify('/' + m)}: function (require, module, exports, process, Buffer, setInterval, clearInterval, __dirname, __filename) {\n${code}\n},\n`;
}
bundle += '};\n';

// 2) Buffer mínimo (escrito para a demo)
const buf = fs.readFileSync(path.join(__dirname, 'buffer-lite.js'), 'utf8');

fs.writeFileSync(path.join(OUT, 'backend.js'), buf + bundle + fs.readFileSync(path.join(__dirname, 'shims.js'), 'utf8'));
fs.copyFileSync(path.join(SRC, 'public/app.js'), path.join(OUT, 'app.js'));

// 3) página
const css = fs.readFileSync(path.join(SRC, 'public/style.css'), 'utf8');
const demoCss = `
/* ---------- painel da demonstração ---------- */
.demo-fab { position: fixed; left: 50%; top: 6px; transform: translateX(-50%); z-index: 50; border: 0; border-radius: 999px; padding: 4px 10px; opacity: .92; background: #5a3fb5; color: #fff; font: 600 12px system-ui, sans-serif; box-shadow: 0 4px 14px rgba(0,0,0,.2); cursor: pointer; }
.demo-panel { position: fixed; left: 50%; top: 40px; transform: translateX(-50%); width: min(360px, calc(100vw - 24px)); box-sizing: border-box; z-index: 51; background: #fff; color: #1c2430; border-radius: 16px; padding: 14px 16px; box-shadow: 0 10px 30px rgba(0,0,0,.25); font: 13px/1.4 system-ui, sans-serif; }
.demo-panel h4 { margin: 0 0 6px; font-size: 14px; }
.demo-panel p { margin: 0 0 10px; color: #5e6878; }
.demo-panel label { display: flex; align-items: center; gap: 8px; margin: 8px 0; font-weight: 600; }
.demo-panel .row { display: flex; gap: 8px; margin-top: 12px; }
.demo-panel button { flex: 1; border: 1.5px solid #1677f2; background: #fff; color: #1677f2; border-radius: 10px; padding: 8px; font-weight: 700; cursor: pointer; }
.demo-panel .users { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; margin-top: 8px; }
.demo-panel .users button { font-size: 12px; }
.boot { display: grid; place-items: center; min-height: 60vh; color: #5e6878; font: 15px system-ui, sans-serif; text-align: center; padding: 24px; }
`;
const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Biko — demonstração (TCC)</title>
  <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>${css}${demoCss}</style>
</head>
<body>
  <div id="app" class="phone"><div class="boot">Ligando a API e os microsserviços…</div></div>
  <div id="toast" class="toast" role="status" aria-live="polite"></div>
  <button type="button" class="demo-fab" id="demoFab">🧪 Demo</button>
  <div class="demo-panel" id="demoPanel" hidden>
    <h4>Painel da demonstração</h4>
    <p>A API e os dois microsserviços rodam dentro desta página. Os dados ficam só neste navegador.</p>
    <b>Entrar rápido como</b>
    <div class="users">
      <button type="button" data-login="cliente@biko.com|Cliente@123">Maria (cliente)</button>
      <button type="button" data-login="prestador@biko.com|Prestador@123">Carlos (prestador)</button>
      <button type="button" data-login="joana@biko.com|Joana@123">Joana (prestadora)</button>
      <button type="button" data-login="admin@biko.com|Admin@123">Admin</button>
    </div>
    <label><input type="checkbox" id="dn3001"> Desligar microsserviço de notificações</label>
    <label><input type="checkbox" id="dn3002"> Desligar microsserviço de pagamentos</label>
    <div class="row"><button type="button" id="demoReset">Recomeçar do zero</button><button type="button" id="demoClose">Fechar</button></div>
  </div>
  <script>
  (function () {
    function load(src) { return new Promise(function (ok, bad) { var s = document.createElement('script'); s.src = src; s.onload = ok; s.onerror = bad; document.body.appendChild(s); }); }
    load('backend.js').then(function () { return load('app.js'); }).then(function () {
      var panel = document.getElementById('demoPanel');
      document.getElementById('demoFab').onclick = function () { panel.hidden = !panel.hidden; };
      document.getElementById('demoClose').onclick = function () { panel.hidden = true; };
      document.getElementById('demoReset').onclick = function () { BikoDemo.reset(); };
      ['3001', '3002'].forEach(function (p) {
        var cb = document.getElementById('dn' + p);
        cb.checked = BikoDemo.isDown(p);
        cb.onchange = function () { BikoDemo.setDown(p, cb.checked); toast(cb.checked ? 'Microsserviço desligado. O resto do Biko continua funcionando.' : 'Microsserviço ligado de novo.'); };
      });
      panel.querySelectorAll('[data-login]').forEach(function (b) {
        b.onclick = async function () {
          var parts = b.dataset.login.split('|');
          try { await fetch('/api/auth/logout', { method: 'POST' }); } catch (e) {}
          try { var r = await api('POST', '/api/auth/login', { email: parts[0], password: parts[1] }); panel.hidden = true; state.loginMode = r.user.role === 'prestador' ? 'prestador' : 'cliente'; enterApp(r.user); }
          catch (e) { toast(e.message, true); }
        };
      });
    }).catch(function (e) {
      document.getElementById('app').innerHTML = '<div class="boot">Não deu para ligar a demonstração neste navegador.<br><small>' + String(e && e.message || e) + '</small></div>';
    });
  })();
  </script>
</body>
</html>
`;
fs.writeFileSync(path.join(OUT, 'index.html'), html);
console.log('ok', fs.readdirSync(OUT).map((f) => `${f} ${(fs.statSync(path.join(OUT, f)).size / 1024).toFixed(0)}KB`).join(', '));
