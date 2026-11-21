// Sobe os DOIS processos de uma vez (atalho para a apresentação):
//   - microsserviço de notificações  -> http://127.0.0.1:3001
//   - API principal + site do Biko   -> http://localhost:3000
// Cada um continua sendo um processo separado; dá para derrubar um sem derrubar o outro.
const { spawn } = require('child_process');
const path = require('path');

const procs = [
  { nome: 'notificacoes', script: path.join(__dirname, 'notificacoes', 'server.js') },
  { nome: 'api', script: path.join(__dirname, 'server.js') },
].map(({ nome, script }) => {
  const p = spawn(process.execPath, ['--disable-warning=ExperimentalWarning', script], { stdio: ['ignore', 'pipe', 'pipe'] });
  const out = (buf) => buf.toString().split('\n').filter(Boolean).forEach((l) => console.log(`[${nome}] ${l}`));
  p.stdout.on('data', out); p.stderr.on('data', out);
  p.on('exit', (code) => console.log(`[${nome}] parou (código ${code})`));
  return p;
});

const sair = () => { procs.forEach((p) => p.kill()); process.exit(0); };
process.on('SIGINT', sair);
process.on('SIGTERM', sair);
