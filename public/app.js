// Biko - frontend (JS puro), no visual do protótipo do Figma (telas "Usua" e "Prest").
// Toda regra de segurança real está no backend (server.js); aqui a interface só se adapta ao perfil.

const $app = document.getElementById('app');
const state = {
  user: null, view: 'login', loginMode: 'cliente', tab: 'home', stack: [], resetEmail: '',
  users: [], filters: { search: '', role: '', status: '' },                          // admin
  search: { q: '', category: '', maxPrice: '', sort: '' }, results: [], total: 0, categories: null,
  orders: [], orderFilter: '', myServices: [], notifCount: 0, chatUnread: 0, agendaDay: null, clientAgenda: 'proximos',
};

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const initials = (n) => String(n || '?').split(' ').filter(Boolean).slice(0, 2).map((p) => p[0]).join('').toUpperCase();
const first = (n) => String(n || '').split(' ')[0];
const ROLE_LABEL = { admin: 'Admin', cliente: 'Cliente', prestador: 'Prestador' };

function toast(msg, isError) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.className = 'toast show' + (isError ? ' error' : '');
  clearTimeout(toast._t);
  toast._t = setTimeout(() => (t.className = 'toast'), 3200);
}

async function api(method, url, body) {
  const res = await fetch(url, {
    method, headers: body ? { 'Content-Type': 'application/json' } : {},
    body: body ? JSON.stringify(body) : undefined, credentials: 'same-origin',
  });
  let data = {};
  try { data = await res.json(); } catch (e) { /* sem corpo */ }
  if (!res.ok) {
    // Sessão expirada / conta desativada no meio do uso -> volta para o login
    if ((res.status === 401 || res.status === 403) && state.user && url !== '/api/auth/login' && /Sess|desativada|autenticado/i.test(data.error || '')) {
      state.user = null; state.view = 'login'; render();
      toast(data.error || 'Sessão encerrada.', true);
    }
    const err = new Error(data.error || 'Erro inesperado.');
    err.fields = data.fields || {}; err.status = res.status;
    throw err;
  }
  return data;
}

function showFieldErrors(form, fields) {
  form.querySelectorAll('.field-error').forEach((e) => (e.textContent = ''));
  form.querySelectorAll('.invalid').forEach((i) => i.classList.remove('invalid'));
  Object.entries(fields || {}).forEach(([name, msg]) => {
    const el = form.querySelector(`[data-err="${name}"]`);
    const input = form.querySelector(`[name="${name}"]`);
    if (el) el.textContent = msg;
    if (input) input.classList.add('invalid');
  });
}
function formAlert(form, msg, type = '') {
  let a = form.querySelector('.alert');
  if (!msg) { if (a) a.remove(); return; }
  if (!a) { a = document.createElement('div'); form.insertBefore(a, form.querySelector('button[type=submit]')); }
  a.className = 'alert ' + type;
  a.textContent = msg;
}

// ---------- validação no cliente (espelha o backend) ----------
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
function pwError(p) {
  if (p.length < 8) return 'A senha deve ter no mínimo 8 caracteres.';
  if (!/[A-Za-z]/.test(p) || !/\d/.test(p)) return 'A senha deve conter letras e números.';
  return '';
}
function cpfOk(cpf) {
  cpf = String(cpf).replace(/\D/g, '');
  if (!/^\d{11}$/.test(cpf) || /^(\d)\1{10}$/.test(cpf)) return false;
  const dig = (n) => { let s = 0; for (let i = 0; i < n; i++) s += Number(cpf[i]) * (n + 1 - i); const r = (s * 10) % 11; return r === 10 ? 0 : r; };
  return dig(9) === Number(cpf[9]) && dig(10) === Number(cpf[10]);
}
function ageOf(br) {
  const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(br || '');
  if (!m) return null;
  const [d, mo, y] = [m[1], m[2], m[3]].map(Number);
  const dt = new Date(y, mo - 1, d);
  if (dt.getMonth() !== mo - 1 || dt > new Date() || y < 1900) return null;
  const t = new Date(); let a = t.getFullYear() - y;
  if (t.getMonth() < mo - 1 || (t.getMonth() === mo - 1 && t.getDate() < d)) a--;
  return a;
}
const maskCpf = (v) => { const d = v.replace(/\D/g, '').slice(0, 11); let o = d.slice(0, 3); if (d.length > 3) o += '.' + d.slice(3, 6); if (d.length > 6) o += '.' + d.slice(6, 9); if (d.length > 9) o += '-' + d.slice(9); return o; };
const maskDate = (v) => { const d = v.replace(/\D/g, '').slice(0, 8); return d.length > 4 ? `${d.slice(0, 2)}/${d.slice(2, 4)}/${d.slice(4)}` : d.length > 2 ? `${d.slice(0, 2)}/${d.slice(2)}` : d; };

// ---------- formatação ----------
const brl = (v) => Number(v).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
const dateBR = (d) => String(d).split('-').reverse().join('/');
const fmtDur = (m) => (m < 60 ? `${m} min` : m % 60 === 0 ? `${m / 60} h` : `${Math.floor(m / 60)} h ${m % 60} min`);
const dateTimeBR = (ms) => new Date(ms).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
const hhmmOf = (ms) => new Date(ms).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
const pad2 = (n) => String(n).padStart(2, '0');
const ymd = (d) => `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
const toMin = (hhmm) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5));
const DOW = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];
const MONTHS = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
const parseYmd = (s) => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };
// "Hoje", "Amanhã" ou "Qua, 26/11"
function dayLabel(dateStr) {
  const d = parseYmd(dateStr), t = new Date(); t.setHours(0, 0, 0, 0);
  const diff = Math.round((d - t) / 86400000);
  if (diff === 0) return 'Hoje';
  if (diff === 1) return 'Amanhã';
  if (diff === -1) return 'Ontem';
  return `${DOW[d.getDay()][0]}${DOW[d.getDay()].slice(1).toLowerCase()}, ${pad2(d.getDate())}/${pad2(d.getMonth() + 1)}`;
}
// "Hoje, 23/11" / "Qui, 26/11"
const fullDay = (d) => { const l = dayLabel(d); return /,/.test(l) ? l : `${l}, ${dateBR(d).slice(0, 5)}`; };
const fmtRating = (r) => Number(r).toFixed(1).replace('.', ',');
const STATUS_LABEL = { pendente: 'Pendente', confirmado: 'Confirmado', recusado: 'Recusado', concluido: 'Concluído', cancelado: 'Cancelado' };
const STATUS_PILL = { pendente: 'orange', confirmado: 'green', recusado: 'red', concluido: 'blue', cancelado: 'red' };
const CATS = [
  { nome: 'Telhado & Reparador', chip: 'Telhados', icon: '🏠', bg: '#fff6dd' },
  { nome: 'Encanador', chip: 'Hidráulica', icon: '🔧', bg: '#e7f1ff' },
  { nome: 'Eletricista', chip: 'Elétrica', icon: '⚡', bg: '#fff6dd' },
  { nome: 'Pintor', chip: 'Pintura', icon: '🎨', bg: '#f3e8ff' },
  { nome: 'Limpeza', chip: 'Limpeza', icon: '🧹', bg: '#e3f7ec' },
  { nome: 'Jardinagem', chip: 'Jardim', icon: '🌿', bg: '#e3f7ec' },
];
const CAT_ICON = Object.fromEntries(CATS.map((c) => [c.nome, c.icon]));
const ACTION_LABEL = { confirmar: 'Aceitar pedido', recusar: 'Recusar', atrasar: 'Avisar atraso / imprevisto', iniciar: 'Cheguei ao local / Iniciar', estender: 'Preciso de mais tempo', concluir: 'Concluir serviço', cancelar: 'Cancelar pedido' };
const ACTION_DONE = { confirmar: 'Pedido aceito. O cliente foi avisado.', recusar: 'Pedido recusado.', atrasar: 'Cliente avisado. O horário foi adiado.', iniciar: 'Atendimento iniciado. O cliente foi avisado.', estender: 'Tempo prorrogado. A agenda foi ajustada.', concluir: 'Serviço concluído!', cancelar: 'Pedido cancelado.' };
const EVENT_LABEL = { ...STATUS_LABEL, atrasado: 'Aviso de atraso', iniciado: 'Atendimento iniciado', prorrogado: 'Tempo prorrogado', remarcado: 'Horário remarcado', pago: 'Pagamento aprovado', estornado: 'Pagamento estornado' };
const OPEN_MIN = 7 * 60, CLOSE_MIN = 20 * 60;

// ---------- ícones (SVG em linha, traço) ----------
const P = {
  home: '<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
  chat: '<path d="M4 5h16v11H8l-4 4z"/><path d="M8 9h8M8 12h5"/>',
  cal: '<rect x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/><path d="m9 15 2 2 4-4"/>',
  wallet: '<rect x="3" y="6" width="18" height="14" rx="3"/><path d="M3 10h18M16 15h2"/><path d="M6 6V5a2 2 0 0 1 2-2h9"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0M16 4.5a3.5 3.5 0 0 1 0 7M21.5 20a6.5 6.5 0 0 0-4-6"/>',
  list: '<path d="M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01"/>',
  bell: '<path d="M6 16V11a6 6 0 1 1 12 0v5l2 2H4z"/><path d="M10 21h4"/>',
  back: '<path d="M19 12H5M11 6l-6 6 6 6"/>',
  arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
  chev: '<path d="m9 6 6 6-6 6"/>',
  mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3.5 6.5 8.5 6 8.5-6"/>',
  lock: '<rect x="5" y="10.5" width="14" height="10" rx="2"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/>',
  phone: '<path d="M5 3h4l2 5-2.5 1.5a11 11 0 0 0 6 6L16 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 5a2 2 0 0 1 2-2"/>',
  pin: '<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  star: '<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z" fill="currentColor" stroke="none"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  checkCircle: '<circle cx="12" cy="12" r="9"/><path d="m8 12.3 2.8 2.8L16 9.8"/>',
  badge: '<path d="M12 2.5 14.6 4.4 17.8 4.2 18.8 7.3 21.5 9.1 20.3 12.1 21.5 15.1 18.8 16.9 17.8 20 14.6 19.8 12 21.7 9.4 19.8 6.2 20 5.2 16.9 2.5 15.1 3.7 12.1 2.5 9.1 5.2 7.3 6.2 4.2 9.4 4.4z" fill="currentColor" stroke="none"/><path d="m8.5 12.2 2.4 2.4 4.6-4.8" stroke="#fff"/>',
  send: '<path d="M21 3 10 14M21 3l-7 18-4-7-7-4z"/>',
  clip: '<path d="m20 12-8.5 8.5a5 5 0 0 1-7-7L13 5a3.5 3.5 0 0 1 5 5l-8.5 8.5a2 2 0 0 1-3-3L14 8"/>',
  image: '<rect x="3" y="4" width="18" height="16" rx="2.5"/><circle cx="9" cy="10" r="2"/><path d="m21 16-5-5-9 9"/>',
  filter: '<path d="M4 6h16M7 12h10M10 18h4"/>',
  sliders: '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="17" r="2"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3h.1a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8v.1a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
  help: '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6v.3M12 17h.01"/>',
  shield: '<path d="M12 3 4.5 6v6c0 4.4 3.2 7.8 7.5 9 4.3-1.2 7.5-4.6 7.5-9V6z"/><path d="m9 12 2 2 4-4"/>',
  idcard: '<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="11" r="2"/><path d="M6 16a3 3 0 0 1 6 0M14 10h4M14 13h3"/>',
  bolt: '<path d="M13 2 4 14h7l-1 8 9-12h-7z" fill="currentColor" stroke="none"/>',
  map: '<path d="M9 4 3 6v14l6-2 6 2 6-2V4l-6 2z" fill="currentColor" stroke="none" opacity=".25"/><path d="M12 15s-4-3.4-4-6.3A4 4 0 0 1 16 8.7c0 2.9-4 6.3-4 6.3z" fill="currentColor" stroke="none"/><circle cx="12" cy="8.8" r="1.4" fill="#fff" stroke="none"/>',
  nav: '<path d="m3 11 18-8-8 18-2-8z" fill="currentColor" stroke="none"/>',
  down: '<path d="M12 5v14M6 13l6 6 6-6"/>',
  up: '<path d="M12 19V5M6 11l6-6 6 6"/>',
  pix: '<path d="m12 3 4 4-4 4-4-4zM12 13l4 4-4 4-4-4zM3 12l4-4 4 4-4 4zM13 12l4-4 4 4-4 4z" fill="currentColor" stroke="none"/>',
  card: '<rect x="2.5" y="5" width="19" height="14" rx="2.5"/><path d="M2.5 10h19M6 15h4"/>',
  copy: '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/>',
  dots: '<circle cx="12" cy="5" r="1.6" fill="currentColor"/><circle cx="12" cy="12" r="1.6" fill="currentColor"/><circle cx="12" cy="19" r="1.6" fill="currentColor"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  hammer: '<path d="m15 12-8.5 8.5a2.1 2.1 0 0 1-3-3L12 9"/><path d="M17.6 15 22 10.6l-6.6-6.6a5 5 0 0 0-7 0L11 6.6 17.6 13.2z" fill="currentColor" stroke="none"/>',
  logout: '<path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 17l5-5-5-5M15 12H3"/>',
  receipt: '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6"/>',
  google: '<path d="M21.6 12.2c0-.7-.1-1.4-.2-2H12v3.8h5.4a4.6 4.6 0 0 1-2 3v2.5h3.2c1.9-1.7 3-4.3 3-7.3z" fill="#4285F4" stroke="none"/><path d="M12 22c2.7 0 5-.9 6.6-2.5l-3.2-2.5c-.9.6-2 1-3.4 1-2.6 0-4.8-1.8-5.6-4.1H3.1v2.6A10 10 0 0 0 12 22z" fill="#34A853" stroke="none"/><path d="M6.4 13.9a6 6 0 0 1 0-3.8V7.5H3.1a10 10 0 0 0 0 9z" fill="#FBBC05" stroke="none"/><path d="M12 6c1.5 0 2.8.5 3.8 1.5l2.9-2.9A10 10 0 0 0 3.1 7.5l3.3 2.6C7.2 7.8 9.4 6 12 6z" fill="#EA4335" stroke="none"/>',
  apple: '<path d="M16.4 12.6c0-2.4 2-3.5 2-3.6-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.8-3.5.8s-1.8-.8-3-.8A4.5 4.5 0 0 0 4.7 9.6c-1.6 2.8-.4 6.9 1.1 9.1.8 1.1 1.7 2.3 2.8 2.3 1.1-.1 1.6-.7 2.9-.7s1.7.7 2.9.7c1.2 0 2-1.1 2.7-2.2a9.6 9.6 0 0 0 1.2-2.5 3.9 3.9 0 0 1-1.9-3.7zM14.2 5.6A3.9 3.9 0 0 0 15.1 2.8a4 4 0 0 0-2.6 1.3 3.7 3.7 0 0 0-.9 2.7 3.3 3.3 0 0 0 2.6-1.2z" fill="currentColor" stroke="none"/>',
};
const ic = (name, cls = '') => `<svg class="i ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${P[name] || ''}</svg>`;
const LOGO = `<div class="app-logo blue">B</div>`; // logo do Biko como no Figma: quadrado azul com o "B" branco
const logoSm = (size = 40) => `<div class="app-logo blue" style="width:${size}px;height:${size}px;border-radius:${Math.round(size * 0.28)}px;font-size:${Math.round(size * 0.46)}px;box-shadow:none">B</div>`;

// Avatar: foto (se houver) ou iniciais do nome
function avatarHtml(u, cls = '') {
  const inner = u && u.photo_url ? `<img src="${esc(u.photo_url)}" alt="Foto de ${esc(u.name)}">` : esc(initials(u && u.name));
  return `<div class="avatar ${cls}">${inner}</div>`;
}
const stars = (r, n) => (r ? `<span class="star">${ic('star')}</span><b>${fmtRating(r)}</b> <span>·</span> <span>(${n} ${n === 1 ? 'avaliação' : 'avaliações'})</span>` : `<span class="pill blue">Novo no Biko</span>`);

// =====================================================================
// LOGIN / CADASTRO (telas "Usua 1" e "Prest 1/2" do Figma)
// =====================================================================
const DEMO_ACCOUNTS = `<div class="demo-accounts">Contas de teste: cliente@biko.com / Cliente@123 · prestador@biko.com / Prestador@123<br>joana@biko.com / Joana@123 · admin@biko.com / Admin@123</div>`;
const socialSoon = (name) => toast(`Entrar com ${name} ainda não está disponível nesta versão. Use e-mail ou telefone.`);

function viewLogin() {
  const prest = state.loginMode === 'prestador';
  const form = `
    <form id="f" novalidate>
      <label class="lbl" for="email">E-mail ou Telefone</label>
      <div class="field">${ic('mail')}<input id="email" name="email" autocomplete="username" placeholder="${prest ? 'carlos.silva@biko.com.br' : 'cliente@biko.com.br'}"></div>
      <div class="field-error" data-err="email"></div>
      <div class="row-between"><label class="lbl" for="password">Senha</label><button type="button" class="link" id="forgot">Esqueceu?</button></div>
      <div class="field">${ic('lock')}<input id="password" name="password" type="password" autocomplete="current-password" placeholder="••••••••"></div>
      <div class="field-error" data-err="password"></div>
      <button class="btn" type="submit" style="margin-top:22px">${prest ? 'Entrar na Conta' : 'Entrar'} ${ic('arrow')}</button>
    </form>
    <div class="divider">OU CONTINUE COM</div>
    <div class="social ${prest ? 'stack' : ''}">
      <button type="button" class="btn outline" data-social="Google">${ic('google')} ${prest ? 'Entrar com Google' : 'Google'}</button>
      <button type="button" class="btn outline" data-social="Apple">${ic('apple')} ${prest ? 'Entrar com Apple' : 'Apple'}</button>
    </div>`;
  $app.innerHTML = prest ? `<div class="screen"><div class="auth prest">
      <div class="logo-wrap"><div class="app-logo blue">B</div></div>
      <div class="brand">biko</div>
      <div class="tagline" style="margin-bottom:10px">Trabalhe onde e quando quiser</div>
      <div class="center" style="margin-bottom:22px"><span class="area-badge">💼 ÁREA DO PRESTADOR</span></div>
      <div class="auth-card">${form}</div>
      <div class="auth-foot">Ainda não oferece seus serviços?<br><button class="link" id="goReg" style="font-size:14px">Cadastre-se como Profissional</button>
        <div style="margin-top:12px"><button class="link" id="switchMode" style="color:var(--muted)">← Sou cliente</button></div>${DEMO_ACCOUNTS}</div>
    </div></div>`
    : `<div class="screen white"><div class="auth">
      <div class="logo-wrap">${LOGO}</div>
      <div class="brand">biko</div>
      <div class="tagline">O serviço que você precisa, no preço<br>e tempo que você pode.</div>
      ${form}
      <div class="center" style="margin-top:18px"><button class="link" id="switchMode">💼 Sou profissional · Área do Prestador</button></div>
      <div class="auth-foot" style="margin-top:22px">Não tem uma conta? <button class="link" id="goReg" style="font-size:14px">Cadastre-se</button>${DEMO_ACCOUNTS}</div>
    </div></div>`;
  const f = document.getElementById('f');
  document.getElementById('goReg').onclick = () => { state.view = prest ? 'registerPro' : 'register'; render(); };
  document.getElementById('forgot').onclick = () => { state.view = 'forgot'; render(); };
  document.getElementById('switchMode').onclick = () => { state.loginMode = prest ? 'cliente' : 'prestador'; render(); };
  $app.querySelectorAll('[data-social]').forEach((b) => (b.onclick = () => socialSoon(b.dataset.social)));
  f.onsubmit = async (e) => {
    e.preventDefault();
    const email = f.email.value.trim(), password = f.password.value;
    const fields = {};
    if (!EMAIL_RE.test(email) && email.replace(/\D/g, '').length < 10) fields.email = 'Informe um e-mail ou telefone válido.';
    if (!password) fields.password = 'Informe a senha.';
    showFieldErrors(f, fields); formAlert(f, '');
    if (Object.keys(fields).length) return;
    const btn = f.querySelector('button[type=submit]'); btn.disabled = true;
    try {
      const { user } = await api('POST', '/api/auth/login', { email, password });
      enterApp(user);
    } catch (err) { formAlert(f, err.message); btn.disabled = false; }
  };
}

function authTop(title, step, total) {
  return `<div class="row-between" style="margin-bottom:18px"><button type="button" class="link" id="back" style="color:#1f2937;font-size:16px;display:flex;align-items:center;gap:8px">${ic('back')} ${esc(title)}</button>
    ${total ? `<div class="steps">${Array.from({ length: total }, (_, i) => `<span class="${i + 1 === step ? 'on' : ''}"></span>`).join('')}</div>` : ''}</div>`;
}

function viewRegister() {
  $app.innerHTML = `<div class="screen white"><div class="auth" style="padding-top:28px">
    ${authTop('Criar conta')}
    <div class="title-xl">Crie sua conta</div>
    <p class="muted" style="margin:6px 0 4px">Encontre profissionais perto de você e agende em poucos toques.</p>
    <form id="f" novalidate>
      <label class="lbl" for="name">Nome completo</label>
      <div class="field">${ic('user')}<input id="name" name="name" autocomplete="name" placeholder="Seu nome"></div><div class="field-error" data-err="name"></div>
      <label class="lbl" for="email">E-mail</label>
      <div class="field">${ic('mail')}<input id="email" name="email" type="email" autocomplete="username" placeholder="exemplo@email.com"></div><div class="field-error" data-err="email"></div>
      <label class="lbl" for="phone">Telefone</label>
      <div class="field">${ic('phone')}<input id="phone" name="phone" type="tel" placeholder="(47) 99999-9999"></div><div class="field-error" data-err="phone"></div>
      <label class="lbl" for="password">Senha</label>
      <div class="field">${ic('lock')}<input id="password" name="password" type="password" autocomplete="new-password" placeholder="Mín. 8 caracteres, letras e números"></div><div class="field-error" data-err="password"></div>
      <label class="lbl" for="confirm">Confirmar senha</label>
      <div class="field">${ic('lock')}<input id="confirm" name="confirm" type="password" autocomplete="new-password"></div><div class="field-error" data-err="confirm"></div>
      <button class="btn" type="submit" style="margin-top:22px">Criar conta ${ic('arrow')}</button>
    </form>
    <div class="auth-foot" style="margin-top:22px">Já tem conta? <button class="link" id="goLogin">Entrar</button></div>
  </div></div>`;
  const f = document.getElementById('f');
  const toLogin = () => { state.view = 'login'; render(); };
  document.getElementById('goLogin').onclick = toLogin;
  document.getElementById('back').onclick = toLogin;
  f.onsubmit = async (e) => {
    e.preventDefault();
    const v = Object.fromEntries(new FormData(f));
    const fields = {};
    if (v.name.trim().length < 3) fields.name = 'Informe o nome completo (mín. 3 caracteres).';
    if (!EMAIL_RE.test(v.email.trim())) fields.email = 'Informe um e-mail válido.';
    const pe = pwError(v.password); if (pe) fields.password = pe;
    if (v.password !== v.confirm) fields.confirm = 'As senhas não conferem.';
    showFieldErrors(f, fields); formAlert(f, '');
    if (Object.keys(fields).length) return;
    const btn = f.querySelector('button[type=submit]'); btn.disabled = true;
    try {
      const { user } = await api('POST', '/api/auth/register', { name: v.name, email: v.email, phone: v.phone, password: v.password, role: 'cliente' });
      toast('Conta criada com sucesso!');
      enterApp(user);
    } catch (err) { showFieldErrors(f, err.fields); formAlert(f, err.message); btn.disabled = false; }
  };
}

// Cadastro do profissional em 2 passos: 1) Verificação (nome, CPF, nascimento, termos)  2) Dados de acesso
const proDraft = { step: 1 };
function viewRegisterPro() {
  const d = proDraft;
  const toLogin = () => { state.view = 'login'; state.loginMode = 'prestador'; render(); };
  if (d.step === 1) {
    $app.innerHTML = `<div class="screen"><div class="auth prest" style="padding-top:28px">
      ${authTop('Identificação', 1, 3)}
      <div class="title-xl">Verificação do Profissional</div>
      <p class="muted" style="margin:6px 0 0;line-height:1.5">Precisamos do seu CPF para validar seu cadastro e garantir a segurança do app.</p>
      <div class="info-box">${ic('shield')}<div><b style="color:#0b4a8f">Requisito Biko:</b> Apenas pessoas maiores de 18 anos podem prestar serviços na plataforma. Seus dados estão protegidos pela LGPD.</div></div>
      <form id="f" class="auth-card" novalidate>
        <label class="lbl" for="name">Nome Completo</label>
        <div class="field">${ic('user')}<input id="name" name="name" autocomplete="name" value="${esc(d.name || '')}" placeholder="Seu nome completo"></div><div class="field-error" data-err="name"></div>
        <label class="lbl" for="cpf">CPF (Apenas números)</label>
        <div class="field">${ic('idcard')}<input id="cpf" name="cpf" inputmode="numeric" value="${esc(d.cpf || '')}" placeholder="000.000.000-00"></div><div class="field-error" data-err="cpf"></div>
        <label class="lbl" for="birth">Data de Nascimento</label>
        <div class="field">${ic('cal')}<input id="birth" name="birth_date" inputmode="numeric" value="${esc(d.birth || '')}" placeholder="DD/MM/AAAA"></div><div class="field-error" data-err="birth_date"></div>
        <div id="ageOk"></div>
        <label class="check-row"><input type="checkbox" name="terms" ${d.terms ? 'checked' : ''}><span>Declaro que os dados pertencem a mim e aceito os <b style="color:var(--blue)">Termos do Prestador</b>.</span></label>
        <div class="field-error" data-err="terms"></div>
        <button class="btn" type="submit" style="margin-top:20px">Validar e Continuar ${ic('arrow')}</button>
        <p class="small muted center" style="margin:12px 0 0">Para testar: CPF 529.982.247-25</p>
      </form>
      <div class="auth-foot">Já tem conta? <button class="link" id="goLogin">Entrar</button></div>
    </div></div>`;
    const f = document.getElementById('f');
    document.getElementById('back').onclick = toLogin;
    document.getElementById('goLogin').onclick = toLogin;
    const ageBox = document.getElementById('ageOk');
    const showAge = () => {
      const a = ageOf(f.birth_date.value);
      ageBox.innerHTML = a === null ? '' : a >= 18 ? `<div class="ok-text">${ic('checkCircle')} Maioridade confirmada (${a} anos).</div>` : `<div class="field-error">Menor de 18 anos: não é possível prestar serviços.</div>`;
    };
    f.cpf.oninput = () => (f.cpf.value = maskCpf(f.cpf.value));
    f.birth_date.oninput = () => { f.birth_date.value = maskDate(f.birth_date.value); showAge(); };
    showAge();
    f.onsubmit = (e) => {
      e.preventDefault();
      const fields = {};
      if (f.name.value.trim().length < 3) fields.name = 'Informe o nome completo.';
      if (!cpfOk(f.cpf.value)) fields.cpf = 'CPF inválido. Confira os números.';
      const a = ageOf(f.birth_date.value);
      if (a === null) fields.birth_date = 'Informe a data no formato DD/MM/AAAA.'; else if (a < 18) fields.birth_date = 'Apenas maiores de 18 anos podem prestar serviços no Biko.';
      if (!f.terms.checked) fields.terms = 'Aceite os Termos do Prestador para continuar.';
      showFieldErrors(f, fields);
      if (Object.keys(fields).length) return;
      Object.assign(d, { name: f.name.value.trim(), cpf: f.cpf.value, birth: f.birth_date.value, terms: true, step: 2 });
      render();
    };
    return;
  }
  $app.innerHTML = `<div class="screen"><div class="auth prest" style="padding-top:28px">
    ${authTop('Acesso', 2, 3)}
    <div class="title-xl">Dados de acesso</div>
    <p class="muted" style="margin:6px 0 16px">Com eles você entra no app e recebe os chamados.</p>
    <form id="f" class="auth-card" novalidate>
      <label class="lbl" for="email">E-mail</label>
      <div class="field">${ic('mail')}<input id="email" name="email" type="email" autocomplete="username" placeholder="voce@email.com"></div><div class="field-error" data-err="email"></div>
      <label class="lbl" for="phone">Telefone</label>
      <div class="field">${ic('phone')}<input id="phone" name="phone" type="tel" placeholder="(47) 99999-9999"></div><div class="field-error" data-err="phone"></div>
      <label class="lbl" for="password">Senha</label>
      <div class="field">${ic('lock')}<input id="password" name="password" type="password" autocomplete="new-password" placeholder="Mín. 8 caracteres, letras e números"></div><div class="field-error" data-err="password"></div>
      <label class="lbl" for="confirm">Confirmar senha</label>
      <div class="field">${ic('lock')}<input id="confirm" name="confirm" type="password" autocomplete="new-password"></div><div class="field-error" data-err="confirm"></div>
      <button class="btn" type="submit" style="margin-top:20px">Criar conta profissional ${ic('arrow')}</button>
    </form>
  </div></div>`;
  const f = document.getElementById('f');
  document.getElementById('back').onclick = () => { d.step = 1; render(); };
  f.onsubmit = async (e) => {
    e.preventDefault();
    const v = Object.fromEntries(new FormData(f));
    const fields = {};
    if (!EMAIL_RE.test(v.email.trim())) fields.email = 'Informe um e-mail válido.';
    const pe = pwError(v.password); if (pe) fields.password = pe;
    if (v.password !== v.confirm) fields.confirm = 'As senhas não conferem.';
    showFieldErrors(f, fields); formAlert(f, '');
    if (Object.keys(fields).length) return;
    const btn = f.querySelector('button[type=submit]'); btn.disabled = true;
    try {
      const { user } = await api('POST', '/api/auth/register', { name: d.name, email: v.email, phone: v.phone, password: v.password, role: 'prestador', cpf: d.cpf, birth_date: d.birth, terms: true });
      Object.assign(proDraft, { step: 1, name: '', cpf: '', birth: '', terms: false });
      toast('Cadastro verificado! Agora cadastre seus serviços no Perfil.');
      enterApp(user);
    } catch (err) {
      if (err.fields && (err.fields.cpf || err.fields.birth_date || err.fields.terms)) { d.step = 1; render(); toast(err.message, true); return; }
      showFieldErrors(f, err.fields); formAlert(f, err.message); btn.disabled = false;
    }
  };
}

function viewForgot() {
  $app.innerHTML = `<div class="screen white"><div class="auth" style="padding-top:28px">
    ${authTop('Recuperar senha')}
    <div class="title-xl">Esqueceu a senha?</div>
    <p class="muted" style="margin:6px 0 4px">Informe o e-mail da sua conta para receber um código.</p>
    <form id="f" novalidate>
      <label class="lbl" for="email">E-mail</label>
      <div class="field">${ic('mail')}<input id="email" name="email" type="email" placeholder="exemplo@email.com"></div><div class="field-error" data-err="email"></div>
      <button class="btn" type="submit" style="margin-top:20px">Enviar código</button>
    </form>
    <div class="auth-foot" style="margin-top:22px"><button class="link" id="hasCode">Já tenho um código</button></div>
  </div></div>`;
  const f = document.getElementById('f');
  document.getElementById('back').onclick = () => { state.view = 'login'; render(); };
  document.getElementById('hasCode').onclick = () => { state.view = 'reset'; render(); };
  f.onsubmit = async (e) => {
    e.preventDefault();
    const email = f.email.value.trim();
    if (!EMAIL_RE.test(email)) return showFieldErrors(f, { email: 'Informe um e-mail válido.' });
    showFieldErrors(f, {});
    try {
      const r = await api('POST', '/api/auth/forgot', { email });
      formAlert(f, r.message, 'ok');
      if (r.devToken) {
        const d = document.createElement('div');
        d.className = 'alert info';
        d.innerHTML = `Modo demonstração (em produção iria por e-mail). Seu código:<br><b>${esc(r.devToken)}</b>`;
        f.insertBefore(d, f.querySelector('button[type=submit]'));
        state.resetToken = r.devToken;
        f.querySelector('button[type=submit]').textContent = 'Continuar';
        f.onsubmit = (ev) => { ev.preventDefault(); state.view = 'reset'; render(); };
      }
    } catch (err) { formAlert(f, err.message); }
  };
}

function viewReset() {
  $app.innerHTML = `<div class="screen white"><div class="auth" style="padding-top:28px">
    ${authTop('Nova senha')}
    <div class="title-xl">Defina uma nova senha</div>
    <form id="f" novalidate>
      <label class="lbl" for="token">Código de recuperação</label>
      <input id="token" name="token" value="${esc(state.resetToken || '')}"><div class="field-error" data-err="token"></div>
      <label class="lbl" for="password">Nova senha</label>
      <div class="field">${ic('lock')}<input id="password" name="password" type="password" autocomplete="new-password"></div><div class="field-error" data-err="password"></div>
      <label class="lbl" for="confirm">Confirmar nova senha</label>
      <div class="field">${ic('lock')}<input id="confirm" name="confirm" type="password" autocomplete="new-password"></div><div class="field-error" data-err="confirm"></div>
      <button class="btn" type="submit" style="margin-top:20px">Redefinir senha</button>
    </form>
  </div></div>`;
  const f = document.getElementById('f');
  document.getElementById('back').onclick = () => { state.view = 'login'; render(); };
  f.onsubmit = async (e) => {
    e.preventDefault();
    const v = Object.fromEntries(new FormData(f));
    const fields = {};
    if (!v.token.trim()) fields.token = 'Informe o código.';
    const pe = pwError(v.password); if (pe) fields.password = pe;
    if (v.password !== v.confirm) fields.confirm = 'As senhas não conferem.';
    showFieldErrors(f, fields); formAlert(f, '');
    if (Object.keys(fields).length) return;
    try {
      await api('POST', '/api/auth/reset', { token: v.token.trim(), password: v.password });
      state.resetToken = ''; state.view = 'login'; render();
      toast('Senha redefinida! Faça login.');
    } catch (err) { formAlert(f, err.message); }
  };
}

// =====================================================================
// NAVEGAÇÃO: abas por perfil + telas empilhadas (voltar)
// =====================================================================
const SCREENS = {};
function screen(name, def) { SCREENS[name] = def; }

function enterApp(user) {
  state.user = user;
  state.view = 'app';
  state.tab = 'home';
  state.stack = [];
  state.notifCount = 0; state.chatUnread = 0;
  render();
  refreshBadges();
}

function navItems() {
  const r = state.user.role;
  if (r === 'cliente') return [['home', 'home', 'Início'], ['search', 'search', 'Buscar'], ['chats', 'chat', 'Conversas'], ['agenda', 'cal', 'Agenda']];
  if (r === 'prestador') return [['home', 'home', 'Início'], ['pagenda', 'cal', 'Agenda'], ['chats', 'chat', 'Conversas'], ['wallet', 'wallet', 'Ganhos'], ['profile', 'user', 'Perfil']];
  return [['home', 'home', 'Início'], ['users', 'users', 'Usuários'], ['orders', 'list', 'Pedidos'], ['sales', 'wallet', 'Vendas'], ['account', 'user', 'Conta']];
}
const navHtml = () => `<nav class="nav">${navItems().map(([id, icon, label]) => `<button data-tab="${id}" class="${state.tab === id && !state.stack.length ? 'on' : state.tab === id ? 'on' : ''}">${ic(icon)}${label}${id === 'chats' && state.chatUnread ? `<span class="nbadge">${state.chatUnread > 9 ? '9+' : state.chatUnread}</span>` : ''}</button>`).join('')}</nav>`;

function go(name, params = {}) { state.stack.push({ name, params }); renderApp(); }
function back() { state.stack.pop(); renderApp(); }
function goTab(tab) { state.tab = tab; state.stack = []; renderApp(); }
// substitui a tela atual (ex.: pagamento -> confirmado, sem voltar para o pagamento)
function replace(name, params = {}) { state.stack.pop(); go(name, params); }

let stopScreen = null; // tela com atualização periódica (chat) registra aqui como parar
async function renderApp() {
  const seq = (renderApp.seq = (renderApp.seq || 0) + 1);
  if (stopScreen) { stopScreen(); stopScreen = null; }
  const top = state.stack[state.stack.length - 1];
  const name = top ? top.name : state.tab;
  const params = top ? top.params : {};
  const scr = SCREENS[name] || SCREENS.home;
  const withNav = true; // como no Figma, a barra de baixo aparece em todas as telas
  const frame = (inner) => `<div class="screen ${scr.cls || ''}" id="scr">${inner}</div>${withNav ? navHtml() : ''}`;
  $app.innerHTML = frame(scr.loading === false ? '' : '<div class="spinner">Carregando…</div>');
  bindNav();
  try {
    const html = await scr.html(params);
    if (seq !== renderApp.seq) return;
    $app.innerHTML = frame(html);
    bindNav();
    bindCommon();
    if (scr.bind) await scr.bind(params);
  } catch (err) {
    if (!state.user || seq !== renderApp.seq) return;
    $app.innerHTML = frame(`${state.stack.length ? topbar('') : ''}<div class="empty">${esc(err.message)}</div>`);
    bindNav(); bindCommon();
  }
}
function bindNav() {
  $app.querySelectorAll('.nav button').forEach((b) => (b.onclick = () => goTab(b.dataset.tab)));
}
// botões comuns: voltar, sino, abrir conversa, abrir pedido
function bindCommon() {
  $app.querySelectorAll('[data-back]').forEach((b) => (b.onclick = back));
  const bell = $app.querySelector('#bell');
  if (bell) bell.onclick = notifModal;
  $app.querySelectorAll('[data-chat]').forEach((b) => (b.onclick = (e) => { e.stopPropagation(); go('chat', { id: Number(b.dataset.chat) }); }));
  $app.querySelectorAll('[data-order]').forEach((el) => (el.onclick = () => openOrder(Number(el.dataset.order))));
}
const topbar = (title, right = '', cls = '') => `<div class="topbar"><button class="icon-btn" data-back aria-label="Voltar">${ic('back')}</button><div class="t ${cls}">${esc(title)}</div>${right}</div>`;

// Abre o pedido na tela certa para cada perfil
function openOrder(id) {
  if (state.user.role === 'prestador') go('request', { id });
  else go('order', { id });
}

// ---------- sino + contadores ----------
const bellHtml = (dark) => `<button type="button" class="bell ${dark ? 'dark' : ''}" id="bell" aria-label="Notificações">${ic('bell')}${state.notifCount ? `<span class="bell-count">${state.notifCount > 9 ? '9+' : state.notifCount}</span>` : ''}</button>`;
async function refreshBadges() {
  if (!state.user) return;
  try { state.notifCount = (await api('GET', '/api/notificacoes/contagem')).nao_lidas; } catch (e) { state.notifCount = 0; }
  if (state.user.role !== 'admin') {
    try { state.chatUnread = (await api('GET', '/api/conversas')).nao_lidas; } catch (e) { /* ok */ }
  }
  const bell = $app.querySelector('#bell');
  if (bell) { bell.outerHTML = bellHtml(bell.classList.contains('dark')); $app.querySelector('#bell').onclick = notifModal; }
  const nav = $app.querySelector('.nav');
  if (nav) { nav.outerHTML = navHtml(); bindNav(); }
}
setInterval(() => { if (state.user && !document.hidden) refreshBadges(); }, 20000);

const NOTIF_ICON = { pendente: '🆕', confirmado: '✅', recusado: '⛔', cancelado: '✖️', concluido: '🏁', atrasado: '⏰', iniciado: '▶️', prorrogado: '⏳', remarcado: '🔁', pago: '💰', estornado: '↩️' };
async function notifModal() {
  const ov = sheet('<h3>Notificações</h3><div class="spinner">Carregando…</div>');
  let d;
  try { d = await api('GET', '/api/notificacoes?limit=30'); }
  catch (err) { ov.body(`<h3>Notificações</h3><div class="alert">${esc(err.message)}</div><button class="btn light" data-close style="margin-top:14px">Fechar</button>`); return; }
  state.notifCount = d.nao_lidas;
  const item = (n) => `<li class="notif ${n.lida ? '' : 'unread'}" data-id="${n.id}" data-ord="${n.pedido_id || ''}"><span class="notif-ico">${NOTIF_ICON[n.acao] || '🔔'}</span><div><b>${esc(n.titulo)}</b><small>${esc(n.mensagem)}</small></div></li>`;
  ov.body(`<div class="row-between"><h3>Notificações</h3>${d.nao_lidas ? '<button class="link" id="nAll">Marcar todas como lidas</button>' : ''}</div>
    ${d.notificacoes.length ? `<ul class="notif-list">${d.notificacoes.map(item).join('')}</ul>` : '<div class="empty">Nenhuma notificação por enquanto.</div>'}
    <button class="btn light" data-close style="margin-top:14px">Fechar</button>`);
  const all = ov.el.querySelector('#nAll');
  if (all) all.onclick = async () => {
    try { await api('POST', '/api/notificacoes/lidas'); } catch (err) { return toast(err.message, true); }
    ov.el.querySelectorAll('.notif.unread').forEach((li) => li.classList.remove('unread'));
    all.remove(); state.notifCount = 0; refreshBadges();
  };
  ov.el.querySelectorAll('.notif').forEach((li) => (li.onclick = async () => {
    if (li.classList.contains('unread')) { try { await api('POST', `/api/notificacoes/${li.dataset.id}/lida`); } catch (e) { /* segue */ } }
    ov.close(); refreshBadges();
    if (li.dataset.ord) openOrder(Number(li.dataset.ord));
  }));
}

// ---------- folha que sobe do rodapé ----------
function sheet(inner) {
  const el = document.createElement('div');
  el.className = 'overlay';
  el.innerHTML = `<div class="sheet">${inner}</div>`;
  $app.appendChild(el);
  const close = () => el.remove();
  el.onclick = (e) => { if (e.target === el) close(); };
  const wire = () => el.querySelectorAll('[data-close]').forEach((b) => (b.onclick = close));
  wire();
  return { el, close, body(html) { el.querySelector('.sheet').innerHTML = html; wire(); } };
}
// Pede um motivo (e minutos, para atraso/prorrogação) e devolve { reason, minutes } ou null
function askReason(action, order) {
  return new Promise((resolve) => {
    const timed = action === 'estender' || action === 'atrasar';
    const optional = action === 'cancelar' && state.user.id === order.client.id;
    const title = { recusar: 'Recusar pedido', cancelar: 'Cancelar pedido', atrasar: 'Avisar atraso / imprevisto', estender: 'Preciso de mais tempo' }[action];
    const ov = sheet(`<h3>${title}</h3>
      ${timed ? `<label class="lbl">${action === 'atrasar' ? `Quanto vai atrasar? (hoje o horário é ${order.time})` : 'Quanto tempo a mais?'}</label>
        <div class="chips" style="padding:0">${[15, 30, 45, 60].map((m, i) => `<button type="button" class="chip ${i === 0 ? 'on' : ''}" data-min="${m}">+${m} min</button>`).join('')}</div>
        <p class="small muted" style="margin:10px 0 0">${action === 'atrasar' ? 'O cliente vê o aviso com o motivo e o novo horário, e pode cancelar sem custo.' : 'Os próximos clientes afetados são remarcados automaticamente.'}</p>` : ''}
      <label class="lbl">${timed ? 'O que aconteceu? (ex.: acabou a energia)' : optional ? 'Motivo (opcional)' : 'Motivo'}</label>
      <textarea id="reason" rows="2" maxlength="200"></textarea><div class="field-error" id="rErr"></div>
      <div class="actions"><button class="btn light" data-close>Voltar</button><button class="btn ${timed ? '' : 'danger'}" id="ok">Confirmar</button></div>`);
    let minutes = 15;
    ov.el.querySelectorAll('[data-min]').forEach((b) => (b.onclick = () => { minutes = Number(b.dataset.min); ov.el.querySelectorAll('[data-min]').forEach((x) => x.classList.toggle('on', x === b)); }));
    ov.el.querySelectorAll('[data-close]').forEach((b) => (b.onclick = () => { ov.close(); resolve(null); }));
    ov.el.querySelector('#ok').onclick = () => {
      const reason = ov.el.querySelector('#reason').value.trim();
      if (!optional && reason.length < 3) { ov.el.querySelector('#rErr').textContent = 'Informe o motivo (mín. 3 caracteres).'; return; }
      ov.close(); resolve({ reason, minutes: timed ? minutes : undefined });
    };
  });
}
// O pedido começa daqui a mais de 30 min? Então "iniciar" é uma antecipação.
function isEarly(o) {
  const d = parseYmd(o.date);
  d.setHours(Math.floor(toMin(o.time) / 60), toMin(o.time) % 60);
  return d.getTime() - Date.now() > 30 * 60000;
}
function confirmSheet(title, text, okLabel, cls = '') {
  return new Promise((resolve) => {
    const ov = sheet(`<h3>${title}</h3><p class="muted" style="line-height:1.5">${text}</p><div class="actions"><button class="btn light" id="no">Voltar</button><button class="btn ${cls}" id="yes">${okLabel}</button></div>`);
    ov.el.querySelector('#no').onclick = () => { ov.close(); resolve(false); };
    ov.el.querySelector('#yes').onclick = () => { ov.close(); resolve(true); };
  });
}
// Executa uma ação do pedido (pede motivo quando precisa). Devolve o pedido atualizado ou null.
async function runAction(order, action) {
  let extra = {};
  if (['recusar', 'cancelar', 'atrasar', 'estender'].includes(action)) {
    const r = await askReason(action, order);
    if (!r) return null;
    extra = r;
  }
  if (action === 'iniciar' && isEarly(order)) {
    const ok = await confirmSheet('Antecipar o atendimento?', `Está marcado para ${dateBR(order.date)} às ${order.time}. Se iniciar agora, o pedido passa a começar neste momento (${fmtDur(order.duration_min)} de serviço), o horário antigo fica livre na agenda e o cliente é avisado.`, 'Iniciar agora');
    if (!ok) return null;
  }
  try {
    const r = await api('POST', `/api/orders/${order.id}/status`, { action, ...extra });
    toast(ACTION_DONE[action]);
    refreshBadges();
    return r.order;
  } catch (err) { toast(err.message, true); return null; }
}

function render() {
  if (stopScreen) { stopScreen(); stopScreen = null; }
  if (state.view === 'app' && state.user) return renderApp();
  if (state.view === 'register') return viewRegister();
  if (state.view === 'registerPro') return viewRegisterPro();
  if (state.view === 'forgot') return viewForgot();
  if (state.view === 'reset') return viewReset();
  return viewLogin();
}

async function logout() {
  try { await api('POST', '/api/auth/logout'); } catch (e) { /* sessão já inválida */ }
  state.loginMode = state.user && state.user.role === 'prestador' ? 'prestador' : 'cliente';
  state.user = null; state.view = 'login'; render();
  toast('Você saiu da conta.');
}

// =====================================================================
// CLIENTE: Início ("Usua 2")
// =====================================================================
screen('home', {
  async html() {
    const r = state.user.role;
    if (r === 'prestador') return SCREENS.phome.html();
    if (r === 'admin') return SCREENS.ahome.html();
    const d = await api('GET', '/api/cliente/home');
    const u = state.user;
    const avisos = (d.avisos || []).map((o) => `<div class="notice warn" data-order="${o.id}" style="cursor:pointer">⏰ <div><b>${esc(o.provider.name)} avisou um atraso</b> em "${esc(o.service_title)}": era ${o.original_time} e agora é <b>${o.time}</b> (${dayLabel(o.date)}).<br>Motivo: ${esc(o.delay_reason)}.</div></div>`).join('');
    const counts = Object.fromEntries(d.categorias.map((c) => [c.nome, c]));
    const sel = state.homeCat || '';
    const list = CATS.filter((c) => !sel || c.nome === sel);
    return `<div class="hero">
        <div class="who"><button class="icon-btn" id="me" style="background:rgba(255,255,255,.16);border:0;padding:0;overflow:hidden" aria-label="Minha conta">${u.photo_url ? avatarHtml(u, 'sq') : logoSm(42)}</button>
          <div><b>Olá, ${esc(first(u.name))} 👋</b><small>O que precisa arrumar hoje?</small></div>${bellHtml()}</div>
        <form class="search-box" id="hs">${ic('search')}<input id="hq" type="search" placeholder="Busque ex: Arrumar telha, encanador..." maxlength="80"></form>
      </div>
      <div class="promo"><span class="tag">SERVIÇO RÁPIDO</span><h3>Goteiras ou Telhas Quebradas?</h3><p>Profissionais qualificados com atendimento hoje.</p>
        <button class="btn white" id="promo">Encontrar Mão de Obra</button><svg class="deco" viewBox="0 0 24 24" fill="#fff">${P.hammer}</svg></div>
      ${avisos ? `<div class="section"><h3>Avisos</h3></div>${avisos}` : ''}
      <div class="section"><h3>Categorias Populares</h3><button class="link" id="all">Ver todas</button></div>
      <div class="chips"><button class="chip ${!sel ? 'on' : ''}" data-hcat="">Todos</button>${CATS.slice(0, 5).map((c) => `<button class="chip ${sel === c.nome ? 'on' : ''}" data-hcat="${esc(c.nome)}">${c.chip}</button>`).join('')}</div>
      <div style="height:14px"></div>
      ${list.map((c) => `<div class="card cat-row" data-cat="${esc(c.nome)}"><div class="ci" style="background:${c.bg}">${c.icon}</div><div class="info"><b>${esc(c.nome)}</b><small>${esc((counts[c.nome] || {}).desc || '')}</small></div><div class="chev">${ic('chev')}</div></div>`).join('')}`;
  },
  bind() {
    const r = state.user.role;
    if (r === 'prestador') return SCREENS.phome.bind();
    if (r === 'admin') return SCREENS.ahome.bind();
    document.getElementById('me').onclick = () => go('account');
    document.getElementById('hs').onsubmit = (e) => { e.preventDefault(); state.search = { q: document.getElementById('hq').value.trim(), category: '', maxPrice: '', sort: '' }; goTab('search'); };
    document.getElementById('promo').onclick = () => { state.search = { q: '', category: 'Telhado & Reparador', maxPrice: '', sort: '' }; goTab('search'); };
    document.getElementById('all').onclick = () => { state.search = { q: '', category: '', maxPrice: '', sort: '' }; goTab('search'); };
    $app.querySelectorAll('[data-hcat]').forEach((b) => (b.onclick = () => { state.homeCat = b.dataset.hcat; renderApp(); }));
    $app.querySelectorAll('[data-cat]').forEach((el) => (el.onclick = () => { state.search = { q: '', category: el.dataset.cat, maxPrice: '', sort: '' }; goTab('search'); }));
  },
});

// =====================================================================
// CLIENTE: Busca ("Usua 3")
// =====================================================================
async function runSearch() {
  const s = state.search, q = new URLSearchParams();
  if (s.q) q.set('q', s.q);
  if (s.category) q.set('category', s.category);
  if (s.maxPrice !== '') q.set('max_price', s.maxPrice);
  if (s.sort) q.set('sort', s.sort);
  const d = await api('GET', '/api/search?' + q.toString());
  state.results = d.results; state.total = d.total;
}
function resultCard(r, i) {
  const best = i === 0 && r.provider_rating && state.results.length > 1;
  return `<div class="card ${best ? 'hl' : ''}">${best ? '<span class="ribbon">MAIS BEM AVALIADO</span>' : ''}
    <div class="pro" data-prov="${r.provider_id}" style="cursor:pointer">${avatarHtml({ name: r.provider_name, photo_url: r.provider_photo_url }, 'lg sq')}
      <div class="info"><div class="name">${esc(r.provider_name)} ${r.provider_verified ? ic('badge', 'verified') : ''}</div>
        <div class="spec">${esc(r.provider_specialty || r.category)}</div><div class="rating">${stars(r.provider_rating, r.provider_reviews)}</div></div></div>
    <div class="sep"></div>
    <div class="price-row"><div><small>${esc(r.title)}</small><b>${brl(r.price)}</b></div>
      <div class="right"><span class="g">${ic('clock')} ${fmtDur(r.duration_min)}</span><br>Disponível hoje</div></div>
    <div class="btn-row"><button class="btn light" data-chat="${r.provider_id}">${ic('chat')} Conversar</button><button class="btn" data-book="${r.id}">${ic('cal')} Agendar</button></div>
  </div>`;
}
screen('search', {
  async html() {
    if (state.user.role !== 'cliente') return '<div class="empty">A busca é para clientes.</div>';
    await runSearch();
    const s = state.search;
    const cats = CATS.map((c) => `<option value="${esc(c.nome)}" ${s.category === c.nome ? 'selected' : ''}>${esc(c.nome)}</option>`).join('');
    return `<div class="topbar" style="padding-bottom:12px"><button class="icon-btn" id="sBack" aria-label="Voltar">${ic('back')}</button>
        <form id="sf" class="field" style="flex:1">${ic('search')}<input id="q" type="search" value="${esc(s.q)}" placeholder="${s.category ? esc(s.category) : 'O que você procura?'}" maxlength="80" style="background:#fff;padding-top:12px;padding-bottom:12px"></form></div>
      <div class="chips"><button class="chip soft" id="fBtn">${ic('sliders')} Filtros</button>
        <button class="chip ${s.sort === 'preco_asc' ? 'on' : ''}" data-sort="preco_asc">Menor Preço</button>
        <button class="chip ${s.sort === 'nota' ? 'on' : ''}" data-sort="nota">Melhor Nota ⭐</button>
        ${s.category ? `<button class="chip on" id="clrCat">${esc(s.category)} ✕</button>` : ''}</div>
      <div class="filters-panel ${state.showFilters ? '' : 'hide'}" id="fp">
        <select id="sCat"><option value="">Todas as categorias</option>${cats}</select>
        <input id="sMax" type="number" inputmode="decimal" min="0" step="1" placeholder="Preço máximo (R$)" value="${esc(s.maxPrice)}">
      </div>
      <div class="section"><h3 style="font-size:15px">Profissionais disponíveis</h3><span class="small" style="color:var(--green);font-weight:600">${ic('bolt')} ${state.total} encontrado(s)</span></div>
      <div id="results">${state.results.length ? state.results.map(resultCard).join('')
        : `<div class="empty">Nenhum resultado encontrado${s.q ? ` para “${esc(s.q)}”` : ''}.<br>Tente outras palavras ou ajuste os filtros.<br><button class="link" id="clearAll" style="margin-top:10px">Limpar filtros</button></div>`}</div>`;
  },
  bind() {
    if (state.user.role !== 'cliente') return;
    const s = state.search;
    const again = () => renderApp();
    document.getElementById('sBack').onclick = () => goTab('home');
    document.getElementById('sf').onsubmit = (e) => { e.preventDefault(); s.q = document.getElementById('q').value.trim(); again(); };
    let t; document.getElementById('q').oninput = (e) => { clearTimeout(t); t = setTimeout(() => { s.q = e.target.value.trim(); again(); }, 500); };
    document.getElementById('fBtn').onclick = () => { state.showFilters = !state.showFilters; document.getElementById('fp').classList.toggle('hide'); };
    $app.querySelectorAll('[data-sort]').forEach((b) => (b.onclick = () => { s.sort = s.sort === b.dataset.sort ? '' : b.dataset.sort; again(); }));
    const clr = document.getElementById('clrCat'); if (clr) clr.onclick = () => { s.category = ''; again(); };
    const ca = document.getElementById('clearAll'); if (ca) ca.onclick = () => { state.search = { q: '', category: '', maxPrice: '', sort: '' }; again(); };
    document.getElementById('sCat').onchange = (e) => { s.category = e.target.value; again(); };
    let t2; document.getElementById('sMax').oninput = (e) => { clearTimeout(t2); t2 = setTimeout(() => { s.maxPrice = e.target.value.trim(); again(); }, 600); };
    $app.querySelectorAll('[data-book]').forEach((b) => (b.onclick = () => go('book', { service: state.results.find((r) => r.id === Number(b.dataset.book)) })));
    $app.querySelectorAll('[data-prov]').forEach((b) => (b.onclick = () => go('provider', { id: Number(b.dataset.prov) })));
  },
});

// Perfil público do prestador (visto pelo cliente)
screen('provider', {
  async html({ id }) {
    const p = (await api('GET', `/api/prestadores/${id}`)).prestador;
    this.p = p;
    return `${topbar('Profissional')}
      <div class="card profile-head">${avatarHtml(p, 'xl ring')}<h3>${esc(p.name)} ${p.verified ? ic('badge', 'verified') : ''}</h3>
        <p>${esc(p.specialty || 'Prestador Biko')}</p>${p.rating ? `<span class="rating-pill">⭐ ${fmtRating(p.rating)} (${p.reviews_count} avaliações)</span>` : '<span class="pill blue">Novo no Biko</span>'}
        <div class="btn-row" style="margin-top:16px"><button class="btn light" data-chat="${p.id}">${ic('chat')} Conversar</button><button class="btn" id="bookFirst" ${p.services.length ? '' : 'disabled'}>${ic('cal')} Agendar</button></div></div>
      <div class="card"><div class="card-title">Serviços</div>${p.services.length ? p.services.map((s) => `<div class="svc-line"><div class="info"><b>${esc(s.title)}</b><small>${esc(s.category)} · ${fmtDur(s.duration_min)}</small></div><b>${brl(s.price)}</b><button class="btn sm" data-svc="${s.id}">Agendar</button></div>`).join('') : '<div class="muted small">Nenhum serviço disponível agora.</div>'}</div>
      ${p.portfolio.length ? `<div class="card"><div class="card-title">Portfólio de Trabalhos</div><div class="portfolio">${p.portfolio.map((f) => `<div class="ph"><img src="${f.url}" alt="Trabalho de ${esc(p.name)}"></div>`).join('')}</div></div>` : ''}
      ${p.reviews.length ? `<div class="card"><div class="card-title">O que dizem os clientes</div>${p.reviews.map((r) => `<div class="review"><span class="star">${'★'.repeat(r.stars)}</span> <b>${esc(first(r.client_name))}</b>${r.comment ? `<div class="muted">${esc(r.comment)}</div>` : ''}</div>`).join('')}</div>` : ''}`;
  },
  bind({ id }) {
    const p = this.p;
    const book = (sid) => { const s = p.services.find((x) => x.id === sid); go('book', { service: { ...s, provider_id: p.id, provider_name: p.name, provider_photo_url: p.photo_url } }); };
    $app.querySelectorAll('[data-svc]').forEach((b) => (b.onclick = () => book(Number(b.dataset.svc))));
    const bf = document.getElementById('bookFirst'); if (bf && p.services[0]) bf.onclick = () => book(p.services[0].id);
  },
});

// =====================================================================
// CLIENTE: Escolha Data e Horário ("Usua 4")
// =====================================================================
screen('book', {
  async html({ service: sv }) {
    if (!this.date || this.svcId !== sv.id) { this.date = null; this.time = null; this.svcId = sv.id; }
    const today = new Date();
    const days = Array.from({ length: 14 }, (_, i) => { const d = new Date(today); d.setDate(d.getDate() + i); return d; });
    // hoje já não cabe o serviço (atendimento até 20:00)? começa em amanhã
    const nowMin = today.getHours() * 60 + today.getMinutes() + 60;
    if (!this.date) this.date = ymd(nowMin + sv.duration_min > CLOSE_MIN ? days[1] : days[0]);
    const sel = parseYmd(this.date);
    return `${topbar('Escolha Data e Horário')}
      <div class="card" style="margin-top:10px"><div class="pro" style="align-items:center">${avatarHtml({ name: sv.provider_name, photo_url: sv.provider_photo_url }, 'lg sq')}
        <div class="info"><div class="name">${esc(sv.provider_name)}</div><div class="spec" style="color:var(--blue);margin:0">${esc(sv.title)}</div><small class="muted">${brl(sv.price)} · ${fmtDur(sv.duration_min)}</small></div>
        <button class="chip soft" data-chat="${sv.provider_id}">${ic('chat')} Chat</button></div></div>
      <div class="card"><div class="row-between" style="margin-bottom:14px"><b style="color:var(--ink)">Dia do Atendimento</b><span class="link">${MONTHS[sel.getMonth()]} ${sel.getFullYear()}</span></div>
        <div class="days">${days.map((d) => `<button class="day ${ymd(d) === this.date ? 'on' : ''}" data-day="${ymd(d)}"><small>${DOW[d.getDay()]}</small><b>${d.getDate()}</b><span class="dot"></span></button>`).join('')}</div></div>
      <div class="card"><b style="color:var(--ink);display:block;margin-bottom:14px">Horários Disponíveis</b><div class="slots" id="slots"><div class="muted small">Carregando…</div></div></div>
      <form class="card" id="bf" novalidate><b style="color:var(--ink)">Onde será o serviço?</b>
        <div class="field" style="margin-top:12px">${ic('pin')}<input name="address" maxlength="200" placeholder="Rua, número, bairro" value="${esc(this.address || '')}"></div><div class="field-error" data-err="address"></div>
        <textarea name="notes" rows="2" maxlength="500" placeholder="Conte o que precisa ser feito (opcional)" style="margin-top:10px">${esc(this.notes || '')}</textarea><div class="field-error" data-err="notes"></div>
        <div class="field-error" data-err="time"></div><div class="field-error" data-err="date"></div>
        <button class="btn" type="submit" style="margin-top:16px">Avançar para Pagamento ${ic('arrow')}</button></form>`;
  },
  async bind({ service: sv }) {
    const self = this;
    const f = document.getElementById('bf');
    f.address.oninput = () => (self.address = f.address.value);
    f.notes.oninput = () => (self.notes = f.notes.value);
    $app.querySelectorAll('[data-day]').forEach((b) => (b.onclick = () => { self.date = b.dataset.day; self.time = null; renderApp(); }));
    const box = document.getElementById('slots');
    let busy = [];
    try { busy = (await api('GET', `/api/providers/${sv.provider_id}/agenda?date=${self.date}`)).busy; } catch (err) { box.innerHTML = `<div class="field-error">${esc(err.message)}</div>`; return; }
    const earliest = Date.now() + 60 * 60000;
    const out = [];
    for (let m = OPEN_MIN; m + sv.duration_min <= CLOSE_MIN; m += 30) {
      const hhmm = `${pad2(Math.floor(m / 60))}:${pad2(m % 60)}`;
      const d = parseYmd(self.date); d.setHours(Math.floor(m / 60), m % 60);
      const taken = busy.some((b) => m < toMin(b.end) && m + sv.duration_min > toMin(b.start));
      out.push(`<button type="button" class="slot ${self.time === hhmm ? 'on' : ''}" data-t="${hhmm}" ${taken || d.getTime() < earliest ? 'disabled' : ''}>${hhmm}</button>`);
    }
    box.innerHTML = out.join('') || '<div class="muted small">Sem horários neste dia.</div>';
    if (!box.querySelector('.slot:not(:disabled)')) box.insertAdjacentHTML('beforeend', '<div class="muted small" style="grid-column:1/-1">Sem horários livres neste dia. Escolha outro.</div>');
    box.querySelectorAll('[data-t]').forEach((b) => (b.onclick = () => { self.time = b.dataset.t; box.querySelectorAll('.slot').forEach((x) => x.classList.toggle('on', x === b)); }));
    f.onsubmit = async (e) => {
      e.preventDefault();
      const fields = {};
      if (!self.time) fields.time = 'Escolha um horário.';
      if (f.address.value.trim().length < 5) fields.address = 'Informe o endereço do serviço.';
      showFieldErrors(f, fields); formAlert(f, '');
      if (Object.keys(fields).length) return;
      const btn = f.querySelector('button[type=submit]'); btn.disabled = true;
      try {
        const { order } = await api('POST', '/api/orders', { service_id: sv.id, date: self.date, time: self.time, address: f.address.value, notes: f.notes.value });
        self.date = null; self.time = null; self.address = ''; self.notes = '';
        replace('pay', { id: order.id });
      } catch (err) { showFieldErrors(f, err.fields); formAlert(f, err.message); btn.disabled = false; if (err.status === 409) renderApp(); }
    };
  },
});

// =====================================================================
// CLIENTE: Pagamento Seguro ("Usua 5") — SIMULADO
// =====================================================================
// "QR Code" de enfeite: desenho gerado a partir do código (não é um QR de verdade)
function fakeQr(text, color = '#fff') {
  const n = 25; let h = 2166136261;
  for (const ch of text) { h ^= ch.charCodeAt(0); h = Math.imul(h, 16777619); }
  const rnd = () => { h ^= h << 13; h ^= h >>> 17; h ^= h << 5; return (h >>> 0) / 4294967296; };
  const finder = (x, y) => [[0, 0], [n - 7, 0], [0, n - 7]].some(([fx, fy]) => x >= fx && x < fx + 7 && y >= fy && y < fy + 7);
  const finderOn = (x, y) => { const fx = x < 7 ? 0 : n - 7, fy = y < 7 ? 0 : n - 7; const dx = x - fx, dy = y - fy; return dx === 0 || dy === 0 || dx === 6 || dy === 6 || (dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4); };
  let rects = '';
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) if (finder(x, y) ? finderOn(x, y) : rnd() > 0.52) rects += `<rect x="${x}" y="${y}" width="1" height="1"/>`;
  return `<svg viewBox="0 0 ${n} ${n}" shape-rendering="crispEdges" aria-label="QR Code Pix (demonstração)"><g fill="${color}">${rects}</g></svg>`;
}
const bandeiraDe = (num) => (/^4/.test(num) ? 'Visa' : /^5[1-5]/.test(num) ? 'Mastercard' : /^(4011|4312|4389|5041|5066|5067|6277|6362|6363|6504|6505|6516)/.test(num) ? 'Elo' : 'Cartão');
screen('pay', {
  async html({ id }) {
    const o = (await api('GET', `/api/orders/${id}`)).order;
    this.o = o; if (this.orderId !== o.id) { this.method = null; this.orderId = o.id; } this.pix = null;
    if (!o.can_pay) return `${topbar('Pagamento Seguro')}<div class="empty">Este pedido já foi pago ou não pode mais ser pago.</div><div class="pad"><button class="btn" data-order="${o.id}">Ver pedido</button></div>`;
    const m = this.method;
    return `${topbar('Pagamento Seguro')}
      <div class="card" style="margin-top:10px"><div class="card-title">Resumo do Pedido</div>
        <div class="kv"><span>${esc(o.service_title)} (${esc(o.provider.name)})</span><b>${brl(o.price)}</b></div>
        <div class="kv"><span>Taxa de Proteção Biko</span><b>${brl(o.protection_fee)}</b></div>
        <div class="kv total"><b style="color:var(--ink);font-size:16px">Total</b><b>${brl(o.total)}</b></div></div>
      <div class="section" style="margin-top:6px"><h3 style="font-size:15px">Escolha como pagar</h3></div>
      <div class="radio-card ${m === 'pix' ? 'on' : ''}" data-m="pix"><div class="head"><span class="ic" style="background:var(--green-soft);color:var(--green)">${ic('pix')}</span>Pix (Instantâneo)<span class="radio"></span></div>
        ${m === 'pix' ? `<div class="body center"><div class="qr-dark" id="qr"><span class="small" style="color:#fff">Gerando…</span></div><div class="pix-code hide" id="pixCode"></div>
          <button class="btn light sm" id="copyPix" style="margin:0 auto">${ic('copy')} Copiar Código Pix</button></div>` : ''}</div>
      <div class="radio-card ${m === 'cartao' ? 'on' : ''}" data-m="cartao"><div class="head"><span class="ic" style="background:var(--blue-soft);color:var(--blue)">${ic('card')}</span>Cartão de Crédito<span class="radio"></span></div>
        ${m === 'cartao' ? `<form class="body" id="cardForm" novalidate>
          <div class="card-preview"><span id="cpBrand">Cartão</span><b id="cpNum">•••• •••• •••• ••••</b><small id="cpName">NOME NO CARTÃO</small></div>
          <input name="cNum" inputmode="numeric" autocomplete="off" placeholder="Número do cartão" maxlength="19"><div class="field-error" data-err="cNum"></div>
          <input name="cName" autocomplete="off" placeholder="Nome no cartão" style="margin-top:10px"><div class="field-error" data-err="cName"></div>
          <div class="two" style="margin-top:10px"><div><input name="cExp" inputmode="numeric" placeholder="MM/AA" maxlength="5"><div class="field-error" data-err="cExp"></div></div>
            <div><input name="cCvv" inputmode="numeric" placeholder="CVV" maxlength="4"><div class="field-error" data-err="cCvv"></div></div></div>
          <select name="cParc" style="margin-top:10px">${[1, 2, 3].map((n) => `<option value="${n}">${n}x de ${brl(o.total / n)} sem juros</option>`).join('')}</select>
          <p class="small muted" style="margin:10px 0 0">Teste: 4242 4242 4242 4242 aprova; final 0002 é recusado. Só os 4 últimos dígitos saem do aparelho.</p>
        </form>` : ''}</div>
      <div class="demo-note">🧪 Ambiente de demonstração (TCC): nenhum valor é cobrado. Não use dados reais.</div>
      <div class="pad"><button class="btn green" id="confirmPay" ${m ? '' : 'disabled'}>${ic('lock')} ${m ? `Confirmar Pagamento ${brl(o.total)}` : 'Escolha como pagar'}</button>
        <button class="link" id="later" style="display:block;margin:14px auto 0;color:var(--muted)">Pagar depois</button></div>`;
  },
  async bind({ id }) {
    const self = this, o = this.o;
    if (!o.can_pay) return;
    // tocar na forma já aberta fecha ela de novo
    $app.querySelectorAll('[data-m] .head').forEach((h) => (h.onclick = () => { const m = h.parentElement.dataset.m; self.method = self.method === m ? null : m; renderApp(); }));
    document.getElementById('later').onclick = () => replace('confirmed', { id, paid: false });
    const btn = document.getElementById('confirmPay');
    const done = () => { self.method = null; replace('confirmed', { id, paid: true }); };
    if (!self.method) return;
    if (self.method === 'pix') {
      try {
        // Reaproveita um Pix que já esteja aguardando; senão gera um novo
        let c = o.payment && o.payment.status === 'aguardando' ? (await api('GET', `/api/orders/${id}/pagamento`)).cobranca : null;
        if (!c || c.status !== 'aguardando') c = (await api('POST', `/api/orders/${id}/pagamento`, { metodo: 'pix' })).cobranca;
        self.pix = c;
        document.getElementById('qr').innerHTML = fakeQr(c.pix_copia_cola);
        const pc = document.getElementById('pixCode'); pc.textContent = c.pix_copia_cola; pc.classList.remove('hide');
      } catch (err) { document.getElementById('qr').innerHTML = `<span class="small" style="color:#fff">${esc(err.message)}</span>`; btn.disabled = true; }
      document.getElementById('copyPix').onclick = async () => {
        try { await navigator.clipboard.writeText(self.pix.pix_copia_cola); toast('Código Pix copiado.'); } catch (e) { toast('Não deu para copiar automaticamente.', true); }
      };
      btn.onclick = async () => {
        btn.disabled = true; btn.textContent = 'Confirmando com o banco…';
        try { await new Promise((r) => setTimeout(r, 900)); await api('POST', `/api/orders/${id}/pagamento/confirmar`); done(); }
        catch (err) { toast(err.message, true); btn.disabled = false; btn.textContent = `Confirmar Pagamento ${brl(o.total)}`; }
      };
      return;
    }
    const f = document.getElementById('cardForm');
    const digits = () => f.cNum.value.replace(/\D/g, '');
    f.cNum.oninput = () => {
      const d = digits().slice(0, 16);
      f.cNum.value = d.replace(/(\d{4})(?=\d)/g, '$1 ');
      document.getElementById('cpNum').textContent = (d + '•'.repeat(16 - d.length)).replace(/(.{4})(?=.)/g, '$1 ');
      document.getElementById('cpBrand').textContent = bandeiraDe(d);
    };
    f.cName.oninput = () => (document.getElementById('cpName').textContent = f.cName.value.toUpperCase() || 'NOME NO CARTÃO');
    f.cExp.oninput = () => { const d = f.cExp.value.replace(/\D/g, '').slice(0, 4); f.cExp.value = d.length > 2 ? `${d.slice(0, 2)}/${d.slice(2)}` : d; };
    btn.onclick = async () => {
      const d = digits(), fields = {};
      if (d.length < 13) fields.cNum = 'Número do cartão incompleto.';
      if (f.cName.value.trim().length < 3) fields.cName = 'Informe o nome como está no cartão.';
      const m = /^(\d{2})\/(\d{2})$/.exec(f.cExp.value);
      if (!m || Number(m[1]) < 1 || Number(m[1]) > 12) fields.cExp = 'Validade inválida.';
      if (!/^\d{3,4}$/.test(f.cCvv.value)) fields.cCvv = 'CVV inválido.';
      showFieldErrors(f, fields);
      if (Object.keys(fields).length) return;
      btn.disabled = true; btn.textContent = 'Processando…';
      try {
        // Só o final, a bandeira e as parcelas vão para o servidor (o CVV e o número inteiro nunca saem daqui)
        const r = await api('POST', `/api/orders/${id}/pagamento`, { metodo: 'cartao', cartao: { final: d.slice(-4), bandeira: bandeiraDe(d), parcelas: Number(f.cParc.value) } });
        if (r.cobranca.status === 'recusado') { formAlert(f, `❌ ${r.cobranca.motivo}. Tente outro cartão ou pague com Pix.`); btn.disabled = false; btn.textContent = `Confirmar Pagamento ${brl(o.total)}`; return; }
        done();
      } catch (err) { toast(err.message, true); btn.disabled = false; btn.textContent = `Confirmar Pagamento ${brl(o.total)}`; }
    };
  },
});

// =====================================================================
// CLIENTE: Pedido Confirmado ("Usua 6")
// =====================================================================
screen('confirmed', {
  cls: 'white',
  async html({ id, paid }) {
    const o = (await api('GET', `/api/orders/${id}`)).order;
    const pill = o.status === 'pendente' ? '<span class="pill orange">Aguardando o profissional</span>' : `<span class="pill ${STATUS_PILL[o.status]}">${STATUS_LABEL[o.status]}</span>`;
    return `<div class="success"><div class="check">${ic('check')}</div><h2>${paid ? 'Pedido Confirmado!' : 'Pedido Enviado!'}</h2>
        <p>${paid ? 'Pagamento aprovado. O serviço foi agendado e o profissional notificado.' : 'O profissional foi notificado. Você pode pagar depois pela Agenda.'}</p></div>
      <div class="card" style="margin-top:22px"><div class="pro" style="align-items:center">${avatarHtml(o.provider, 'lg sq')}<div class="info"><div class="name">${esc(o.provider.name)}</div>${pill}</div></div>
        <div class="sep"></div><div class="line-ic">${ic('clock')} ${dayLabel(o.date)} às <b>${o.time}</b></div><div class="line-ic">${ic('pin')} ${esc(o.address)}</div></div>
      <div class="pad"><button class="btn" data-chat="${o.provider.id}">${ic('chat')} Abrir Conversa com ${esc(first(o.provider.name))}</button></div>
      <div class="pad" style="margin-top:auto;padding-top:40px"><button class="btn light" id="home">Voltar para a Home</button></div>`;
  },
  bind() { document.getElementById('home').onclick = () => goTab('home'); },
});

// =====================================================================
// CLIENTE: Agenda (os pedidos do cliente)
// =====================================================================
function agendaCardClient(o) {
  const color = o.in_progress ? 'blue' : { confirmado: '', pendente: 'orange', concluido: 'gray', cancelado: 'gray', recusado: 'gray' }[o.status];
  const label = o.in_progress ? 'EM ANDAMENTO' : o.status === 'pendente' ? 'AGUARDANDO' : STATUS_LABEL[o.status].toUpperCase();
  const lc = o.in_progress ? 'var(--blue)' : o.status === 'confirmado' ? 'var(--green)' : o.status === 'pendente' ? '#e07a00' : 'var(--muted)';
  return `<div class="card agenda-card ${color} click" data-order="${o.id}">
    <div class="row-between"><span class="when" style="color:${lc}">${dayLabel(o.date).toUpperCase()} · ${o.time} - ${label}</span>${o.payment && o.payment.status === 'pago' ? '<span class="pill green">✓ Pago</span>' : o.can_pay ? '<span class="pill orange">A pagar</span>' : ''}</div>
    <h4>${esc(o.service_title)}</h4><div class="muted small">${state.user.role === 'cliente' ? 'Profissional' : 'Cliente'}: ${esc(state.user.role === 'cliente' ? o.provider.name : o.client.name)}</div>
    ${o.delay_min ? `<div class="small" style="color:#c2410c;margin-top:6px">⏰ Horário mudou: era ${o.original_time}</div>` : ''}</div>`;
}
screen('agenda', {
  async html() {
    const d = await api('GET', '/api/orders?limit=100');
    const now = Date.now();
    const active = d.orders.filter((o) => ['pendente', 'confirmado'].includes(o.status)).sort((a, b) => (a.date + a.time).localeCompare(b.date + b.time));
    const past = d.orders.filter((o) => !['pendente', 'confirmado'].includes(o.status));
    const tab = state.clientAgenda;
    const list = tab === 'proximos' ? active : past;
    void now;
    return `<div class="page-title"><h2>Sua Agenda</h2>${bellHtml(true)}</div>
      <div class="chips"><button class="chip ${tab === 'proximos' ? 'on' : ''}" data-ag="proximos">Próximos (${active.length})</button><button class="chip ${tab === 'historico' ? 'on' : ''}" data-ag="historico">Histórico (${past.length})</button><button class="chip" id="pays">${ic('receipt')} Pagamentos</button></div>
      <div style="height:14px"></div>
      ${list.length ? list.map(agendaCardClient).join('') : `<div class="empty">${tab === 'proximos' ? 'Nenhum serviço agendado.<br>Use a aba Buscar para encontrar um profissional.' : 'Nada no histórico ainda.'}</div>`}`;
  },
  bind() {
    $app.querySelectorAll('[data-ag]').forEach((b) => (b.onclick = () => { state.clientAgenda = b.dataset.ag; renderApp(); }));
    document.getElementById('pays').onclick = () => go('payments');
  },
});

// Detalhe do pedido (cliente e admin)
screen('order', {
  async html({ id }) {
    const o = (await api('GET', `/api/orders/${id}`)).order;
    this.o = o;
    const isClient = state.user.id === o.client.id;
    const other = isClient ? o.provider : o.client;
    const statusPill = o.in_progress ? '<span class="pill blue">Em andamento</span>' : `<span class="pill ${STATUS_PILL[o.status]}">${o.status === 'pendente' ? 'Aguardando o profissional' : STATUS_LABEL[o.status]}</span>`;
    const pay = o.payment && o.payment.status !== 'recusado' ? `<div class="kv"><span>Pagamento</span><b>${{ pago: '✓ Pago', aguardando: 'Aguardando Pix', estornado: 'Estornado', estorno_pendente: 'Estorno em andamento', expirado: 'Pix expirado' }[o.payment.status] || esc(o.payment.status)}<br><button class="link" id="receipt">Ver comprovante</button></b></div>` : '';
    const acts = o.actions.filter((a) => a === 'cancelar');
    return `${topbar('Detalhes do Pedido')}
      <div class="card" style="margin-top:10px"><div class="pro" style="align-items:center">${avatarHtml(other, 'lg sq')}<div class="info"><div class="name">${esc(other.name)}</div><div class="spec" style="margin:2px 0">${esc(o.service_title)}</div>${statusPill}</div>
        ${state.user.role !== 'admin' ? `<button class="icon-btn soft round" data-chat="${other.id}" aria-label="Conversar">${ic('chat')}</button>` : ''}</div></div>
      ${o.delay_min ? `<div class="notice warn">⏰ <div><b>Aviso de atraso:</b> o horário era ${o.original_time} e agora é ${o.time} (+${o.delay_min} min).<br>Motivo: ${esc(o.delay_reason)}.</div></div>` : ''}
      <div class="card"><div class="line-ic">${ic('clock')} ${fullDay(o.date)} · <b>${o.time}–${o.end_time}</b></div>
        <div class="line-ic">${ic('pin')} ${esc(o.address)}</div>${other.phone ? `<div class="line-ic">${ic('phone')} ${esc(other.phone)}</div>` : ''}
        ${o.notes ? `<div class="sep"></div><div class="muted small">“${esc(o.notes)}”</div>` : ''}</div>
      <div class="card"><div class="kv"><span>Serviço</span><b>${brl(o.price)}</b></div><div class="kv"><span>Taxa de Proteção Biko</span><b>${brl(o.protection_fee)}</b></div>${pay}
        ${o.status_reason ? `<div class="kv"><span>Motivo</span><b>${esc(o.status_reason)}</b></div>` : ''}</div>
      ${o.review ? `<div class="card"><div class="card-title">Sua avaliação</div><span class="star" style="font-size:20px">${'★'.repeat(o.review.stars)}${'☆'.repeat(5 - o.review.stars)}</span>${o.review.comment ? `<div class="muted">${esc(o.review.comment)}</div>` : ''}</div>` : ''}
      <div class="card"><div class="card-title">Histórico</div><ul class="hist">${o.history.map((h) => `<li><span class="d"></span><div><b>${EVENT_LABEL[h.status] || esc(h.status)}</b> <small>${dateTimeBR(h.created_at)}</small><br><small>${esc(h.actor_name || 'Sistema')}${h.note ? ` — ${esc(h.note)}` : ''}</small></div></li>`).join('')}</ul></div>
      <div class="pad" style="display:grid;gap:10px">
        ${o.can_pay && isClient ? `<button class="btn green" id="pay">${ic('lock')} Pagar ${brl(o.total)}</button>` : ''}
        ${o.can_review ? `<button class="btn orange" id="rate">⭐ Avaliar o serviço</button>` : ''}
        ${acts.map((a) => `<button class="btn outline" data-act="${a}" style="color:var(--danger)">${ACTION_LABEL[a]}</button>`).join('')}</div>`;
  },
  bind({ id }) {
    const o = this.o;
    const p = document.getElementById('pay'); if (p) p.onclick = () => go('pay', { id });
    const r = document.getElementById('receipt'); if (r) r.onclick = async () => { try { receiptModal((await api('GET', `/api/orders/${id}/pagamento`)).cobranca); } catch (err) { toast(err.message, true); } };
    const rt = document.getElementById('rate'); if (rt) rt.onclick = () => rateModal(o);
    $app.querySelectorAll('[data-act]').forEach((b) => (b.onclick = async () => { if (await runAction(o, b.dataset.act)) renderApp(); }));
  },
});

function rateModal(o) {
  let nota = 5;
  const ov = sheet(`<h3>Como foi o serviço?</h3><p class="muted">${esc(o.service_title)} com ${esc(o.provider.name)}</p>
    <div class="stars-pick">${[1, 2, 3, 4, 5].map((n) => `<button data-n="${n}" class="on">★</button>`).join('')}</div>
    <textarea id="cm" rows="3" maxlength="300" placeholder="Conte como foi (opcional)"></textarea>
    <div class="actions"><button class="btn light" data-close>Agora não</button><button class="btn" id="send">Enviar avaliação</button></div>`);
  ov.el.querySelectorAll('[data-n]').forEach((b) => (b.onclick = () => { nota = Number(b.dataset.n); ov.el.querySelectorAll('[data-n]').forEach((x) => x.classList.toggle('on', Number(x.dataset.n) <= nota)); }));
  ov.el.querySelector('#send').onclick = async () => {
    try { await api('POST', `/api/orders/${o.id}/avaliacao`, { nota, comentario: ov.el.querySelector('#cm').value }); ov.close(); toast('Obrigado pela avaliação!'); renderApp(); }
    catch (err) { toast(err.message, true); }
  };
}

// =====================================================================
// CONVERSAS ("Usua 7") — lista e chat (cliente e prestador)
// =====================================================================
const timeOf = (ms) => new Date(ms).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
function dayOf(ms) { const d = new Date(ms); return dayLabel(ymd(d)); }

screen('chats', {
  async html() {
    if (state.user.role === 'admin') return '<div class="empty">O admin não participa das conversas.</div>';
    const d = await api('GET', '/api/conversas');
    state.chatUnread = d.nao_lidas;
    const empty = state.user.role === 'cliente' ? 'Nenhuma conversa ainda.<br>Na busca, toque em <b>Conversar</b> para falar com um profissional.' : 'Nenhuma conversa ainda.<br>Quando um cliente mandar mensagem, ela aparece aqui.';
    return `<div class="page-title"><h2>Conversas</h2>${bellHtml(true)}</div>
      ${d.conversas.length ? `<div style="border-top:1px solid var(--line)">${d.conversas.map((c) => `<div class="conv" data-chat="${c.user.id}">
        <div class="avatar-wrap">${avatarHtml(c.user, 'lg')}${c.user.role === 'prestador' && c.user.online ? '<span class="online-dot"></span>' : ''}</div>
        <div class="info"><b>${esc(c.user.name)}</b><small>${c.last.mine ? 'Você: ' : ''}${esc(c.last.text)}</small></div>
        <div style="text-align:right"><small class="muted" style="font-size:11.5px">${dayOf(c.last.created_at) === 'Hoje' ? timeOf(c.last.created_at) : dayOf(c.last.created_at)}</small>${c.unread ? `<div class="badge-n" style="margin:4px 0 0 auto;width:max-content">${c.unread}</div>` : ''}</div></div>`).join('')}</div>`
        : `<div class="empty">${empty}</div>`}`;
  },
});

screen('chat', {
  cls: 'chat-screen', loading: false,
  async html({ id }) {
    const d = await api('GET', `/api/conversas/${id}`);
    this.d = d;
    const o = d.other;
    let lastDay = '';
    const rows = d.messages.map((m) => {
      const day = dayOf(m.created_at);
      const sep = day !== lastDay ? `<div class="day-sep">${day}</div>` : '';
      lastDay = day;
      return `${sep}<div class="msg ${m.mine ? 'mine' : ''}">${m.mine ? '' : avatarHtml(o)}<div class="bubble">${esc(m.text)}</div></div><div class="msg-time ${m.mine ? 'mine' : ''}">${timeOf(m.created_at)}</div>`;
    }).join('');
    const sub = o.role === 'prestador' ? `<small class="${o.online ? '' : 'off'}">${o.online ? 'Online' : 'Offline'}${o.specialty ? ` • ${esc(o.specialty)}` : ''}</small>` : `<small class="off">Cliente</small>`;
    return `<div class="chat-top"><button class="icon-btn round" data-back aria-label="Voltar" style="background:#f1f4f8;border:0">${ic('back')}</button>
        <div class="avatar-wrap">${avatarHtml(o)}${o.role === 'prestador' && o.online ? '<span class="online-dot"></span>' : ''}</div>
        <div class="who"><b>${esc(o.name)}</b>${sub}</div>
        ${o.phone ? `<a class="icon-btn soft round" href="tel:${esc(o.phone.replace(/[^\d+]/g, ''))}" aria-label="Ligar (${esc(o.phone)})" title="${esc(o.phone)}">${ic('phone')}</a>` : ''}
        <button class="icon-btn soft-orange round" id="cal" aria-label="Agenda">${ic('cal')}</button></div>
      <div class="msgs" id="msgs">${rows || `<div class="empty">Comece a conversa com ${esc(first(o.name))}.<br><small>Conte o que precisa e combine os detalhes.</small></div>`}</div>
      ${d.next_order ? `<div class="small" style="background:#fff;padding:8px 16px;border-top:1px solid var(--line);cursor:pointer" data-order="${d.next_order.id}">📅 <b>${esc(d.next_order.title)}</b> · ${dayLabel(d.next_order.date)} às ${d.next_order.time} <span class="pill ${STATUS_PILL[d.next_order.status]}">${STATUS_LABEL[d.next_order.status]}</span></div>` : ''}
      <form class="composer" id="cf"><button type="button" class="plain" data-soon aria-label="Anexar">${ic('clip')}</button><button type="button" class="plain" data-soon aria-label="Foto">${ic('image')}</button>
        <input id="txt" autocomplete="off" maxlength="1000" placeholder="Digite uma mensagem..."><button class="send" aria-label="Enviar">${ic('send')}</button></form>`;
  },
  bind({ id }) {
    const self = this;
    const box = document.getElementById('msgs');
    box.scrollTop = box.scrollHeight;
    $app.querySelectorAll('[data-soon]').forEach((b) => (b.onclick = () => toast('Envio de fotos e arquivos ainda não está disponível nesta versão.')));
    document.getElementById('cal').onclick = () => {
      if (self.d.next_order) return openOrder(self.d.next_order.id);
      if (state.user.role === 'cliente') go('provider', { id });
      else toast('Nenhum pedido ativo com este cliente.');
    };
    const f = document.getElementById('cf');
    f.onsubmit = async (e) => {
      e.preventDefault();
      const text = f.txt.value.trim();
      if (!text) return;
      f.txt.value = '';
      try { await api('POST', `/api/conversas/${id}`, { texto: text }); await refresh(); }
      catch (err) { toast(err.message, true); f.txt.value = text; }
    };
    f.txt.focus();
    // Atualiza a conversa a cada 4 s enquanto ela estiver aberta
    let count = (self.d.messages || []).length;
    async function refresh() {
      try {
        const d = await api('GET', `/api/conversas/${id}`);
        if (d.messages.length !== count) {
          count = d.messages.length;
          const keep = f.txt.value;
          self.d = d;
          const html = await SCREENS.chat.html.call(self, { id });
          const scr = document.getElementById('scr'); if (!scr) return;
          scr.innerHTML = html; bindCommon(); SCREENS.chat.bind.call(self, { id });
          document.getElementById('cf').txt.value = keep;
        }
      } catch (e) { /* tenta de novo */ }
    }
    if (stopScreen) stopScreen();
    const timer = setInterval(refresh, 4000);
    stopScreen = () => clearInterval(timer);
  },
});

// =====================================================================
// CONTA (dados, senha, foto, sair) — todos os perfis
// =====================================================================
function fileToAvatar(file) {
  return new Promise((resolve, reject) => {
    if (!/^image\/(png|jpeg|webp)$/.test(file.type)) return reject(new Error('Escolha uma imagem PNG, JPG ou WEBP.'));
    if (file.size > 8 * 1024 * 1024) return reject(new Error('A imagem é muito grande (máx. 8 MB).'));
    const url = URL.createObjectURL(file), img = new Image();
    img.onload = () => {
      const size = 512, c = document.createElement('canvas'); c.width = c.height = size;
      const side = Math.min(img.width, img.height);
      c.getContext('2d').drawImage(img, (img.width - side) / 2, (img.height - side) / 2, side, side, 0, 0, size, size);
      URL.revokeObjectURL(url);
      let q = 0.85, out = c.toDataURL('image/jpeg', q);
      while (out.length > 260000 && q > 0.4) { q -= 0.1; out = c.toDataURL('image/jpeg', q); }
      resolve(out);
    };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error('Não foi possível ler essa imagem.')); };
    img.src = url;
  });
}
screen('account', {
  html() {
    const u = state.user;
    return `${state.stack.length ? topbar('Minha Conta') : '<div class="page-title"><h2>Minha Conta</h2></div>'}
      <div class="card profile-head" style="margin-top:10px">${avatarHtml(u, 'xl ring')}<h3>${esc(u.name)}</h3><p>${esc(u.email)}</p><span class="pill ${u.role === 'prestador' ? 'orange' : u.role === 'admin' ? 'purple' : 'blue'}">${ROLE_LABEL[u.role]}</span>
        <div style="display:flex;gap:14px;justify-content:center;margin-top:14px"><button class="btn sm light" id="pickPhoto" type="button">${u.photo_url ? 'Trocar foto' : 'Adicionar foto'}</button>${u.photo_url ? '<button class="link danger" id="rmPhoto" type="button">Remover</button>' : ''}</div>
        <input type="file" id="photoFile" accept="image/png,image/jpeg,image/webp" hidden></div>
      <form class="card" id="pf" novalidate><div class="card-title">Meus dados</div>
        <label class="lbl" for="pName">Nome completo</label><input id="pName" name="name" autocomplete="name" value="${esc(u.name)}"><div class="field-error" data-err="name"></div>
        <label class="lbl" for="pEmail">E-mail</label><input id="pEmail" name="email" type="email" value="${esc(u.email)}"><div class="field-error" data-err="email"></div>
        <label class="lbl" for="pPhone">Telefone</label><input id="pPhone" name="phone" type="tel" value="${esc(u.phone || '')}" placeholder="(47) 99999-9999"><div class="field-error" data-err="phone"></div>
        <div id="pwWrap" hidden><label class="lbl" for="pCur">Senha atual (para trocar o e-mail)</label><input id="pCur" name="currentPassword" type="password"><div class="field-error" data-err="currentPassword"></div></div>
        <button class="btn" type="submit" style="margin-top:18px">Salvar alterações</button></form>
      <form class="card" id="pwf" novalidate><div class="card-title">Alterar senha</div>
        <label class="lbl" for="cur">Senha atual</label><input id="cur" name="currentPassword" type="password"><div class="field-error" data-err="currentPassword"></div>
        <label class="lbl" for="nw">Nova senha</label><input id="nw" name="newPassword" type="password" placeholder="Mín. 8 caracteres, letras e números"><div class="field-error" data-err="newPassword"></div>
        <label class="lbl" for="cf2">Confirmar nova senha</label><input id="cf2" name="confirm" type="password"><div class="field-error" data-err="confirm"></div>
        <button class="btn" type="submit" style="margin-top:18px">Alterar senha</button></form>
      ${u.role === 'cliente' ? `<div class="card cat-row" id="myPays"><div class="ci" style="background:var(--green-soft)">🧾</div><div class="info"><b>Meus pagamentos</b><small>Comprovantes e estornos</small></div><div class="chev">${ic('chev')}</div></div>` : ''}
      <div class="pad"><button class="btn outline" id="logout" style="color:var(--danger)">${ic('logout')} Sair da conta</button></div>`;
  },
  bind() {
    document.getElementById('logout').onclick = logout;
    const mp = document.getElementById('myPays'); if (mp) mp.onclick = () => go('payments');
    const file = document.getElementById('photoFile');
    document.getElementById('pickPhoto').onclick = () => file.click();
    file.onchange = async () => {
      if (!file.files[0]) return;
      try { const image = await fileToAvatar(file.files[0]); const { user } = await api('PUT', '/api/me/photo', { image }); state.user = user; toast('Foto atualizada.'); renderApp(); }
      catch (err) { toast(err.message, true); }
    };
    const rm = document.getElementById('rmPhoto');
    if (rm) rm.onclick = async () => { try { const { user } = await api('DELETE', '/api/me/photo'); state.user = user; toast('Foto removida.'); renderApp(); } catch (err) { toast(err.message, true); } };
    const pf = document.getElementById('pf'), original = state.user.email;
    pf.email.oninput = () => { document.getElementById('pwWrap').hidden = pf.email.value.trim().toLowerCase() === original; };
    pf.onsubmit = async (e) => {
      e.preventDefault();
      const fields = {};
      if (pf.name.value.trim().length < 3) fields.name = 'Informe o nome completo (mín. 3 caracteres).';
      if (!EMAIL_RE.test(pf.email.value.trim())) fields.email = 'Informe um e-mail válido.';
      const changing = pf.email.value.trim().toLowerCase() !== original;
      if (changing && !pf.currentPassword.value) fields.currentPassword = 'Informe a senha atual para trocar o e-mail.';
      showFieldErrors(pf, fields); formAlert(pf, '');
      if (Object.keys(fields).length) return;
      const body = { name: pf.name.value, email: pf.email.value, phone: pf.phone.value };
      if (changing) body.currentPassword = pf.currentPassword.value;
      try { const { user } = await api('PATCH', '/api/me', body); state.user = user; toast('Dados atualizados.'); renderApp(); }
      catch (err) { showFieldErrors(pf, err.fields); formAlert(pf, err.message); }
    };
    const wf = document.getElementById('pwf');
    wf.onsubmit = async (e) => {
      e.preventDefault();
      const fields = {};
      if (!wf.currentPassword.value) fields.currentPassword = 'Informe a senha atual.';
      const pe = pwError(wf.newPassword.value); if (pe) fields.newPassword = pe;
      if (wf.newPassword.value !== wf.confirm.value) fields.confirm = 'As senhas não conferem.';
      showFieldErrors(wf, fields); formAlert(wf, '');
      if (Object.keys(fields).length) return;
      try { const r = await api('POST', '/api/me/password', { currentPassword: wf.currentPassword.value, newPassword: wf.newPassword.value }); wf.reset(); toast(r.message || 'Senha alterada.'); }
      catch (err) { showFieldErrors(wf, err.fields); formAlert(wf, err.fields && Object.keys(err.fields).length ? '' : err.message); }
    };
  },
});

// =====================================================================
// PAGAMENTOS / VENDAS (lista + comprovante) — cliente e admin
// =====================================================================
const PAY_LABEL = { aguardando: 'Aguardando Pix', pago: 'Pago', aprovado: 'Aprovado', recusado: 'Recusado', expirado: 'Expirado', estornado: 'Estornado', estorno_pendente: 'Estorno em andamento' };
const PAY_PILL = { aprovado: 'green', aguardando: 'orange', estornado: 'purple', recusado: 'red', expirado: 'red' };
async function salesHtml(withTop) {
  const d = await api('GET', '/api/pagamentos?limit=50');
  state.sales = d.cobrancas;
  const r = d.resumo, role = state.user.role;
  const stats = role === 'cliente'
    ? `<div class="stat"><b>${r.vendas}</b><small>Pagamentos</small></div><div class="stat"><b>${brl(r.bruto)}</b><small>Total pago</small></div><div class="stat"><b>${r.estornos}</b><small>Estornos</small></div>`
    : `<div class="stat"><b>${brl(r.bruto)}</b><small>Vendido</small></div><div class="stat"><b>${brl(r.taxa)}</b><small>Taxas Biko</small></div><div class="stat"><b>${brl(r.liquido)}</b><small>Repassado</small></div>`;
  return `${withTop ? topbar(role === 'cliente' ? 'Meus Pagamentos' : 'Vendas') : `<div class="page-title"><h2>Vendas</h2></div>`}
    <div class="demo-note" style="margin-top:8px">🧪 Pagamentos simulados (TCC): nenhum valor é cobrado de verdade.</div>
    <div class="stats" style="padding-top:0">${stats}</div><div class="count">${d.total} transação(ões) · ${r.pix} Pix · ${r.cartao} cartão</div>
    ${d.cobrancas.length ? d.cobrancas.map((c, i) => `<div class="card click tx" data-sale="${i}"><div class="ic ${c.status === 'aprovado' ? '' : 'out'}">${c.metodo === 'pix' ? ic('pix') : ic('card')}</div>
      <div class="info"><b>${esc(c.descricao)}</b><small>${role === 'cliente' ? esc(c.recebedor.nome || '') : `${esc(c.pagador.nome || '')} → ${esc(c.recebedor.nome || '')}`} · ${esc(c.codigo)}</small></div>
      <div style="text-align:right"><span class="pill ${PAY_PILL[c.status] || 'gray'}">${PAY_LABEL[c.status]}</span><br><b style="font-size:14px">${brl(c.valor)}</b></div></div>`).join('')
      : `<div class="empty">${role === 'cliente' ? 'Você ainda não pagou nenhum pedido.' : 'Nenhuma venda ainda.'}</div>`}`;
}
const bindSales = () => $app.querySelectorAll('[data-sale]').forEach((el) => (el.onclick = () => receiptModal(state.sales[Number(el.dataset.sale)])));
screen('payments', { html: () => salesHtml(true), bind: bindSales });
screen('sales', { html: () => salesHtml(false), bind: bindSales });

function receiptModal(c, justPaid) {
  const seller = state.user.role !== 'cliente';
  const forma = c.metodo === 'cartao' ? `${esc(c.cartao.bandeira)} •••• ${esc(c.cartao.final)}${c.parcelas > 1 ? ` · ${c.parcelas}x de ${brl(c.valor / c.parcelas)}` : ' · à vista'}` : 'Pix';
  sheet(`<div class="receipt-head ${c.status}"><div class="receipt-ico">${c.status === 'aprovado' ? '✓' : c.status === 'estornado' ? '↩' : c.status === 'aguardando' ? '…' : '✕'}</div>
      <h3>${c.status === 'aprovado' ? (justPaid ? 'Pagamento aprovado!' : 'Pagamento aprovado') : PAY_LABEL[c.status] || esc(c.status)}</h3><b class="receipt-value">${brl(c.valor)}</b></div>
    <div class="demo-note in">🧪 Ambiente de demonstração (TCC): nenhum valor é cobrado.</div>
    <div class="kv"><span>Serviço</span><b>${esc(c.descricao)}</b></div><div class="kv"><span>Pago por</span><b>${esc(c.pagador.nome || '—')}</b></div>
    <div class="kv"><span>Recebido por</span><b>${esc(c.recebedor.nome || '—')}</b></div><div class="kv"><span>Forma</span><b>${forma}</b></div>
    <div class="kv"><span>${c.pago_em ? 'Data do pagamento' : 'Criado em'}</span><b>${dateTimeBR(c.pago_em || c.criada_em)}</b></div>
    <div class="kv"><span>Transação</span><b>${esc(c.codigo)}</b></div>${c.autorizacao ? `<div class="kv"><span>Autorização</span><b>${esc(c.autorizacao)}</b></div>` : ''}
    ${seller ? `<div class="kv"><span>Taxas Biko</span><b>− ${brl(c.taxa)}</b></div><div class="kv"><span>Valor líquido</span><b>${brl(c.liquido)}</b></div>` : ''}
    ${c.motivo ? `<div class="kv"><span>Observação</span><b>${esc(c.motivo)}</b></div>` : ''}
    <button class="btn light" data-close style="margin-top:14px">Fechar</button>`);
}

// =====================================================================
// PRESTADOR: Início ("Prest 3")
// =====================================================================
function reqCard(o) {
  const today = dayLabel(o.date) === 'Hoje';
  const badge = o.status === 'pendente'
    ? `<span class="pill orange">${today ? `CHEGADA HOJE ${o.time}` : `NOVO · ${dayLabel(o.date).toUpperCase()} ${o.time}`}</span>`
    : `<span class="pill blue">AGENDADO (${dayLabel(o.date).toUpperCase()} ${o.time})</span>`;
  return `<div class="card req"><div class="top">${badge}<span class="price">${brl(o.price)}</span></div>
    <div data-order="${o.id}" style="cursor:pointer"><h4>${esc(o.service_title)}</h4><div class="where">${ic('pin')} ${esc(o.client.name)} • ${esc(o.address)}</div></div>
    ${o.status === 'pendente' ? `<div class="btn-row"><button class="btn outline" data-quick="recusar" data-id="${o.id}">Recusar</button><button class="btn" data-quick="confirmar" data-id="${o.id}">Aceitar</button></div>`
      : `<div class="btn-row"><button class="btn light" data-chat="${o.client.id}">${ic('chat')} Chat</button><button class="btn" data-svcgo="${o.id}">Atendimento</button></div>`}</div>`;
}
screen('phome', {
  async html() {
    const d = await api('GET', '/api/prestador/painel');
    this.d = d;
    const u = state.user, r = d.resumo;
    const online = u.online !== false;
    return `<div class="p-head">${avatarHtml(u, 'lg ring')}<div class="who"><small>Bem-vindo,</small><b>${esc(u.name)} 👋</b></div>
        <button class="online-pill ${online ? '' : 'off'}" id="online">${online ? 'Online' : 'Offline'}</button>${bellHtml(true)}</div>
      <div class="earn"><small>Ganhos desta semana</small><div class="big">${brl(r.ganhosSemana)}</div>
        <div class="meta"><span>${ic('checkCircle')} ${r.servicosSemana} Serviço${r.servicosSemana === 1 ? '' : 's'} feito${r.servicosSemana === 1 ? '' : 's'}</span><span>⭐ ${r.avaliacao ? fmtRating(r.avaliacao) : '—'} Avaliação</span></div></div>
      ${online ? `<div class="notice warn"><span style="color:#e07a00">${ic('bolt')}</span><div><b>Modo Rápido Ativo:</b> Recebendo chamados de clientes próximos a você.</div></div>`
        : `<div class="notice off">⏸ <div><b>Você está offline:</b> seus serviços não aparecem na busca dos clientes.</div></div>`}
      <div class="section"><h3>Solicitações Próximas (${d.pendentes.length})</h3><button class="link" id="all">Ver todas</button></div>
      ${d.pendentes.length ? d.pendentes.slice(0, 5).map(reqCard).join('') : '<div class="empty" style="padding-top:6px">Nenhuma solicitação nova agora.</div>'}
      ${d.proximos.length ? `<div class="section"><h3>Próximos atendimentos</h3></div>${d.proximos.map(reqCard).join('')}` : ''}`;
  },
  bind() {
    const d = this.d;
    document.getElementById('online').onclick = async () => {
      try { const r = await api('PATCH', '/api/me/profissional', { online: state.user.online === false }); state.user = r.user; toast(r.user.online ? 'Você está online.' : 'Você está offline: não aparece na busca.'); renderApp(); }
      catch (err) { toast(err.message, true); }
    };
    document.getElementById('all').onclick = () => go('porders');
    const all = [...d.pendentes, ...d.proximos];
    $app.querySelectorAll('[data-quick]').forEach((b) => (b.onclick = async () => { const o = all.find((x) => x.id === Number(b.dataset.id)); if (await runAction(o, b.dataset.quick)) renderApp(); }));
    $app.querySelectorAll('[data-svcgo]').forEach((b) => (b.onclick = () => go('service', { id: Number(b.dataset.svcgo) })));
  },
});

// Todos os pedidos do prestador (atalho "Ver todas")
screen('porders', {
  async html() {
    const f = state.orderFilter;
    const d = await api('GET', '/api/orders?limit=100' + (f ? `&status=${f}` : ''));
    return `${topbar('Meus Pedidos')}
      <div class="chips"><button class="chip ${!f ? 'on' : ''}" data-of="">Todos</button>${Object.entries(STATUS_LABEL).map(([v, l]) => `<button class="chip ${f === v ? 'on' : ''}" data-of="${v}">${l}</button>`).join('')}</div>
      <div class="count">${d.total} pedido(s)</div>${d.orders.length ? d.orders.map(agendaCardClient).join('') : '<div class="empty">Nenhum pedido.</div>'}`;
  },
  bind() { $app.querySelectorAll('[data-of]').forEach((b) => (b.onclick = () => { state.orderFilter = b.dataset.of; renderApp(); })); },
});

// =====================================================================
// PRESTADOR: Detalhes da Solicitação ("Prest 4")
// =====================================================================
screen('request', {
  async html({ id }) {
    const o = (await api('GET', `/api/orders/${id}`)).order;
    this.o = o;
    if (state.user.role !== 'prestador' || state.user.id !== o.provider.id) return SCREENS.order.html.call(this, { id });
    const since = o.client_since ? new Date(String(o.client_since).replace(' ', 'T') + 'Z') : null;
    const cat = CATS.find((c) => c.nome === o.category);
    const paid = o.payment && o.payment.status === 'pago';
    const st = o.in_progress ? '<span class="pill blue">Em andamento</span>' : `<span class="pill ${STATUS_PILL[o.status]}">${STATUS_LABEL[o.status]}</span>`;
    return `${topbar('Detalhes da Solicitação', '', 'left')}
      <div class="card" style="margin-top:10px"><div class="pro" style="align-items:center">${avatarHtml(o.client, 'lg ring')}<div class="info"><div class="name">${esc(o.client.name)}</div>
        <div class="small muted" style="margin:2px 0 6px">Pedido #${o.id} · ${st}</div><span class="pill green">Cliente Biko${since ? ` desde ${MONTHS[since.getMonth()].slice(0, 3).toLowerCase()}/${since.getFullYear()}` : ''}</span></div>
        <button class="icon-btn soft round" data-chat="${o.client.id}" aria-label="Conversar">${ic('chat')}</button></div></div>
      <div class="card"><div class="caps">Serviço solicitado</div><h3 style="margin:8px 0 6px;font-size:18px;color:var(--ink)">${cat ? cat.icon + ' ' : ''}${esc(o.service_title)}</h3>
        <div class="muted small">${esc(o.category)} · ${fmtDur(o.duration_min)} · <b style="color:var(--blue)">${brl(o.price)}</b></div>
        ${o.notes ? `<p style="margin:12px 0 0;line-height:1.5;color:#374151">“${esc(o.notes)}”</p>` : ''}</div>
      ${o.delay_min ? `<div class="notice warn">⏰ <div>Horário adiado: era ${o.original_time}, agora ${o.time}. Motivo: ${esc(o.delay_reason)}.</div></div>` : ''}
      <div class="card"><div class="line-ic" style="align-items:flex-start">${ic('clock')}<div><small class="muted">Data e Horário</small><br><b>${fullDay(o.date)} às ${o.time}</b></div></div>
        <div class="line-ic" style="align-items:flex-start;margin-top:8px">${ic('pin')}<div><small class="muted">Localização do Serviço</small><br><b>${esc(o.address)}</b></div></div>
        ${o.client.phone ? `<div class="line-ic" style="margin-top:8px">${ic('phone')} ${esc(o.client.phone)}</div>` : ''}
        <div class="sep"></div><div class="row-between small"><span class="muted">Pagamento</span>${paid ? '<span class="pill green">✓ Garantido pelo Biko</span>' : o.payment && o.payment.status === 'estornado' ? '<span class="pill purple">Estornado</span>' : '<span class="pill gray">Ainda não pago</span>'}</div></div>
      <div class="pad" style="display:grid;gap:10px">
        ${o.status === 'pendente' ? `<div class="btn-row"><button class="btn outline" data-act="recusar">Recusar</button><button class="btn" data-act="confirmar">Aceitar</button></div>` : ''}
        ${o.status === 'confirmado' ? `<button class="btn green" id="toSvc">${ic('nav')} ${o.in_progress ? 'Ver atendimento em andamento' : 'Ir para o atendimento'}</button>` : ''}
        ${o.actions.includes('cancelar') ? '<button class="btn outline" data-act="cancelar" style="color:var(--danger)">Cancelar pedido</button>' : ''}</div>
      <div class="card" style="margin-top:14px"><div class="card-title">Histórico</div><ul class="hist">${o.history.map((h) => `<li><span class="d"></span><div><b>${EVENT_LABEL[h.status] || esc(h.status)}</b> <small>${dateTimeBR(h.created_at)}</small><br><small>${esc(h.actor_name || 'Sistema')}${h.note ? ` — ${esc(h.note)}` : ''}</small></div></li>`).join('')}</ul></div>`;
  },
  bind({ id }) {
    const o = this.o;
    if (state.user.id !== o.provider.id) return SCREENS.order.bind.call(this, { id });
    const ts = document.getElementById('toSvc'); if (ts) ts.onclick = () => go('service', { id });
    $app.querySelectorAll('[data-act]').forEach((b) => (b.onclick = async () => {
      const r = await runAction(o, b.dataset.act);
      if (r && b.dataset.act === 'confirmar') replace('service', { id }); else if (r) renderApp();
    }));
  },
});

// =====================================================================
// PRESTADOR: Serviço em Andamento ("Prest 6")
// =====================================================================
screen('service', {
  async html({ id }) {
    const o = (await api('GET', `/api/orders/${id}`)).order;
    this.o = o;
    const ev = (s) => o.history.filter((h) => h.status === s).pop();
    const conf = ev('confirmado'), ini = ev('iniciado'), fim = ev('concluido');
    const step = o.status === 'concluido' ? 5 : o.in_progress ? 3 : o.status === 'confirmado' ? 2 : 1;
    const li = (n, title, sub) => `<li class="${step > n ? 'done' : step === n ? 'now' : ''}"><span class="dot"></span><b>${title}</b>${sub ? `<small>${sub}</small>` : ''}</li>`;
    const paid = o.payment && o.payment.status === 'pago';
    const maps = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(o.address)}`;
    let actions = '';
    if (o.status === 'pendente') actions = `<div class="btn-row"><button class="btn outline" data-act="recusar">Recusar</button><button class="btn" data-act="confirmar">Aceitar</button></div>`;
    else if (o.status === 'confirmado' && !o.in_progress) actions = `<button class="btn green" data-act="iniciar">${ic('pin')} Cheguei ao Local / Iniciar</button>${o.actions.includes('atrasar') ? '<button class="btn light" data-act="atrasar">⏰ Avisar atraso / imprevisto</button>' : ''}`;
    else if (o.in_progress) actions = `<button class="btn green" data-act="concluir">${ic('checkCircle')} Concluir Serviço</button>${o.actions.includes('estender') ? '<button class="btn light" data-act="estender">⏳ Preciso de mais tempo</button>' : ''}`;
    else actions = `<div class="notice ${o.status === 'concluido' ? 'warn' : 'off'}" style="margin:0">${o.status === 'concluido' ? '🏁' : 'ℹ️'}<div>Pedido ${STATUS_LABEL[o.status].toLowerCase()}${o.real_duration_min ? ` · tempo real ${fmtDur(o.real_duration_min)}` : ''}.</div></div>`;
    return `${topbar('Serviço em Andamento', '', 'left')}
      <div class="card" style="margin-top:10px"><div class="card-title">Status do Atendimento</div><ul class="timeline">
        ${li(1, 'Chamado Aceito', conf ? `${hhmmOf(conf.created_at)} - ${dayLabel(ymd(new Date(conf.created_at)))}` : 'Aguardando você aceitar')}
        ${li(2, o.status === 'confirmado' && !o.in_progress ? 'A Caminho do Cliente' : 'Horário agendado', `${dayLabel(o.date)} às ${o.time}${o.delay_min ? ` (adiado +${o.delay_min} min)` : ''}`)}
        ${li(3, 'Serviço em Realização', ini ? `Iniciado às ${hhmmOf(ini.created_at)} · término previsto ${o.end_time}${o.extended_min ? ` (+${o.extended_min} min)` : ''}` : '')}
        ${li(4, 'Concluído & Pagamento', fim ? `${hhmmOf(fim.created_at)}${paid ? ' · pagamento liberado' : ''}` : paid ? 'Pagamento já garantido' : '')}</ul></div>
      <div class="card"><div class="map-ph">${ic('map')}<span class="gps">Mapa ilustrativo</span></div>
        <b style="color:var(--ink)">${esc(o.address)}</b><div class="row-between small" style="margin-top:4px"><span class="muted">${esc(o.service_title)} · ${fmtDur(o.duration_min)}</span><a class="link" href="${maps}" target="_blank" rel="noopener">Ver rota ↗</a></div></div>
      <div class="card"><div class="pro" style="align-items:center">${avatarHtml(o.client, 'lg ring')}<div class="info"><div class="name">${esc(o.client.name)}</div>
        <small style="color:${paid ? 'var(--green)' : 'var(--muted)'};font-weight:600">${paid ? 'Pagamento Garantido pelo Biko' : 'Pagamento ainda não feito'}</small></div>
        ${o.client.phone ? `<a class="icon-btn soft round" href="tel:${esc(o.client.phone.replace(/[^\d+]/g, ''))}" aria-label="Ligar">${ic('phone')}</a>` : ''}<button class="icon-btn soft round" data-chat="${o.client.id}" aria-label="Chat">${ic('chat')}</button></div></div>
      <div class="pad" style="display:grid;gap:10px">${actions}</div>`;
  },
  bind() {
    const o = this.o;
    $app.querySelectorAll('[data-act]').forEach((b) => (b.onclick = async () => { if (await runAction(o, b.dataset.act)) renderApp(); }));
  },
});

// =====================================================================
// PRESTADOR: Sua Agenda ("Prest 5")
// =====================================================================
screen('pagenda', {
  async html() {
    const d = await api('GET', '/api/orders?limit=100');
    const today = new Date(); today.setHours(0, 0, 0, 0);
    if (!state.agendaDay) state.agendaDay = ymd(today);
    const days = Array.from({ length: 14 }, (_, i) => { const x = new Date(today); x.setDate(x.getDate() + i); return x; });
    const active = d.orders.filter((o) => ['pendente', 'confirmado', 'concluido'].includes(o.status));
    const has = new Set(active.filter((o) => o.status !== 'concluido').map((o) => o.date));
    const sel = parseYmd(state.agendaDay);
    const list = active.filter((o) => o.date === state.agendaDay).sort((a, b) => a.time.localeCompare(b.time));
    // horários livres (≥ 1 h) entre 07:00 e 20:00, contando só o que ainda não passou
    const busy = list.filter((o) => o.status !== 'concluido').map((o) => [toMin(o.time), toMin(o.end_time)]).sort((a, b) => a[0] - b[0]);
    let cursor = OPEN_MIN;
    if (state.agendaDay === ymd(new Date())) { const n = new Date(); cursor = Math.max(cursor, Math.ceil((n.getHours() * 60 + n.getMinutes()) / 30) * 30); }
    const free = [];
    for (const [s, e] of busy) { if (s - cursor >= 60) free.push([cursor, s]); cursor = Math.max(cursor, e); }
    if (CLOSE_MIN - cursor >= 60) free.push([cursor, CLOSE_MIN]);
    const hm = (m) => `${pad2(Math.floor(m / 60))}:${pad2(m % 60)}`;
    const card = (o) => {
      const [color, label, lc] = o.in_progress ? ['blue', 'EM ANDAMENTO', 'var(--blue)'] : o.status === 'confirmado' ? ['', 'CONFIRMADO', 'var(--green)'] : o.status === 'pendente' ? ['orange', 'AGUARDANDO VOCÊ', '#e07a00'] : ['gray', 'CONCLUÍDO', 'var(--muted)'];
      const maps = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(o.address)}`;
      return `<div class="card agenda-card ${color}"><div class="row-between"><span class="when" style="color:${lc}">${o.time} - ${label}</span><button class="link" data-order="${o.id}" style="color:var(--muted)" aria-label="Detalhes">${ic('dots')}</button></div>
        <h4>${esc(o.service_title)}</h4><div class="muted small">Cliente: ${esc(o.client.name)}</div>
        ${o.status === 'concluido' ? '' : `<div class="btn-row" style="margin-top:12px"><a class="btn sm" style="width:100%" href="${maps}" target="_blank" rel="noopener">${ic('nav')} Ver Rota</a><button class="btn sm outline" style="width:100%" data-chat="${o.client.id}">${ic('chat')} Chat</button></div>`}</div>`;
    };
    return `<div class="page-title"><h2>Sua Agenda</h2><button class="icon-btn" id="mySvcs" aria-label="Meus serviços" style="border:0;background:none;color:var(--blue)">${ic('sliders')}</button></div>
      <div class="pad"><div class="row-between" style="margin-bottom:12px"><b style="color:var(--ink)">${MONTHS[sel.getMonth()]} ${sel.getFullYear()}</b><button class="link" id="mng">Gerenciar Serviços</button></div>
        <div class="days">${days.map((x) => `<button class="day ${ymd(x) === state.agendaDay ? 'on' : ''} ${has.has(ymd(x)) ? 'has' : ''}" data-day="${ymd(x)}"><b>${x.getDate()}</b><small>${DOW[x.getDay()]}</small><span class="dot"></span></button>`).join('')}</div></div>
      <div class="section"><h3 class="caps" style="font-size:12.5px">Compromissos de ${dayLabel(state.agendaDay).toLowerCase() === 'hoje' ? 'hoje' : dayLabel(state.agendaDay)}</h3></div>
      ${list.length ? list.map(card).join('') : '<div class="empty" style="padding-top:4px">Nenhum compromisso neste dia.</div>'}
      ${free.slice(0, 3).map(([a, b]) => `<div class="free-slot">${ic('clock')} Horário Livre das ${hm(a)} às ${hm(b)}</div>`).join('')}`;
  },
  bind() {
    $app.querySelectorAll('[data-day]').forEach((b) => (b.onclick = () => { state.agendaDay = b.dataset.day; renderApp(); }));
    document.getElementById('mng').onclick = () => go('myservices');
    document.getElementById('mySvcs').onclick = () => go('myservices');
  },
});

// =====================================================================
// PRESTADOR: Ganhos e Carteira ("Prest 7") — SIMULADO
// =====================================================================
screen('wallet', {
  async html() {
    const w = await api('GET', '/api/carteira');
    this.w = w;
    return `<div class="page-title"><h2>Ganhos e Carteira</h2><button class="icon-btn" id="help" style="border:0;background:none;color:var(--muted)" aria-label="Ajuda">${ic('help')}</button></div>
      <div class="wallet"><small>Saldo disponível para saque</small><div class="big">${brl(w.disponivel)}</div>
        <button class="btn orange" id="pix" ${w.disponivel > 0 ? '' : 'disabled'}>${ic('pix')} Transferir via Pix</button></div>
      <div class="stat2"><div class="card"><small>Pendente</small><b>${brl(w.pendente)}</b></div><div class="card"><small>Este Mês</small><b class="g">${brl(w.este_mes)}</b></div></div>
      <div class="section"><h3>Histórico Recente</h3></div>
      ${w.historico.length ? w.historico.map((h) => `<div class="card tx"><div class="ic ${h.tipo === 'saque' ? 'out' : ''}">${ic(h.tipo === 'saque' ? 'up' : 'down')}</div>
        <div class="info"><b>${esc(h.titulo)}</b><small>${dayOf(h.quando)} às ${timeOf(h.quando)}${h.tipo === 'entrada' && !h.liberado ? ' · libera ao concluir' : ''}</small></div>
        <div class="v ${h.tipo === 'saque' ? 'out' : ''}">${h.tipo === 'saque' ? '- ' : '+ '}${brl(h.valor)}</div></div>`).join('')
        : '<div class="empty">Quando os clientes pagarem, os valores aparecem aqui.</div>'}
      <div class="demo-note">🧪 Carteira simulada (TCC): nenhum dinheiro é transferido de verdade.</div>`;
  },
  bind() {
    const w = this.w;
    document.getElementById('help').onclick = () => sheet(`<h3>Como funciona</h3><p class="muted" style="line-height:1.55">O cliente paga ao agendar. O valor fica <b>pendente</b> até você concluir o serviço; aí ele vai para o <b>saldo disponível</b>. O Biko fica com 10% do serviço (a Taxa de Proteção é paga pelo cliente).<br><br>Se o pedido for recusado ou cancelado, o cliente recebe o estorno.</p><button class="btn light" data-close>Entendi</button>`);
    document.getElementById('pix').onclick = () => {
      const ov = sheet(`<h3>Transferir via Pix</h3><p class="muted small">Chave Pix: ${esc(w.chave_pix)}</p>
        <label class="lbl">Valor (disponível ${brl(w.disponivel)})</label><input id="val" inputmode="decimal" value="${w.disponivel.toFixed(2).replace('.', ',')}"><div class="field-error" id="vErr"></div>
        <div class="actions"><button class="btn light" data-close>Cancelar</button><button class="btn orange" id="go">Transferir</button></div>`);
      ov.el.querySelector('#go').onclick = async () => {
        try { const r = await api('POST', '/api/carteira/saque', { valor: ov.el.querySelector('#val').value }); ov.close(); toast(r.mensagem); renderApp(); }
        catch (err) { ov.el.querySelector('#vErr').textContent = (err.fields && err.fields.valor) || err.message; }
      };
    };
  },
});

// =====================================================================
// PRESTADOR: Meu Perfil Profissional ("Prest 8")
// =====================================================================
screen('profile', {
  async html() {
    const p = (await api('GET', '/api/me/profissional')).prestador;
    this.p = p;
    const on = p.categories || CATS.map((c) => c.nome);
    return `<div class="page-title"><h2>Meu Perfil Profissional</h2><button class="icon-btn" id="gear" style="border:0;background:none;color:var(--muted)" aria-label="Configurações da conta">${ic('gear')}</button></div>
      <div class="card profile-head">${avatarHtml(state.user, 'xl ring')}<h3>${esc(p.name)} ${p.verified ? ic('badge', 'verified') : ''}</h3>
        <p id="specTxt">${esc(p.specialty || 'Toque em editar para escrever sua especialidade')} <button class="link" id="editSpec">Editar</button></p>
        ${p.rating ? `<span class="rating-pill">⭐ ${fmtRating(p.rating)} (${p.reviews_count} avaliações)</span>` : '<span class="pill blue">Ainda sem avaliações</span>'}</div>
      <div class="card"><div class="card-title">Suas Categorias de Atuação</div>
        ${CATS.map((c) => `<div class="switch-line"><span class="ci">${c.icon}</span><span class="n">${esc(c.nome)}</span><label class="toggle"><input type="checkbox" data-catt="${esc(c.nome)}" ${on.includes(c.nome) ? 'checked' : ''}><span></span></label></div>`).join('')}
        <p class="small muted" style="margin:6px 0 0">Categoria desligada: seus serviços dela somem da busca.</p></div>
      <div class="card"><div class="card-title">Valor Base da Visita Técnica</div><p class="small muted" style="margin:-6px 0 12px">Esse é o valor mínimo exibido para os clientes ao solicitar um diagnóstico.</p>
        <div style="display:grid;grid-template-columns:1fr auto;gap:10px"><input id="vp" inputmode="decimal" placeholder="R$ 0,00" value="${p.visit_price ? brl(p.visit_price) : ''}" style="text-align:center;font-weight:600"><button class="btn" id="saveVp" style="width:auto">Salvar</button></div>
        <div class="field-error" id="vpErr"></div></div>
      <div class="card"><div class="row-between" style="margin-bottom:6px"><div class="card-title" style="margin:0">Meus Serviços</div><button class="link" id="mng">Gerenciar</button></div>
        ${p.services.length ? p.services.map((s) => `<div class="svc-line"><div class="info"><b>${esc(s.title)}</b><small>${esc(s.category)} · ${fmtDur(s.duration_min)}</small></div><b>${brl(s.price)}</b></div>`).join('') : '<div class="muted small">Nenhum serviço ativo. Toque em Gerenciar para cadastrar.</div>'}</div>
      <div class="card"><div class="row-between" style="margin-bottom:12px"><div class="card-title" style="margin:0">Portfólio de Trabalhos</div><button class="link" id="addPh">+ Adicionar</button></div>
        <div class="portfolio">${p.portfolio.map((f) => `<div class="ph"><img src="${f.url}" alt="Trabalho"><button data-rmph="${f.id}" aria-label="Remover foto">×</button></div>`).join('')}
          ${p.portfolio.length < 6 ? `<div class="ph add" id="addPh2">${ic('plus')}<br>Foto</div>` : ''}</div>
        <input type="file" id="phFile" accept="image/png,image/jpeg,image/webp" hidden></div>
      ${p.reviews.length ? `<div class="card"><div class="card-title">O que dizem os clientes</div>${p.reviews.map((r) => `<div class="review"><span class="star">${'★'.repeat(r.stars)}</span> <b>${esc(first(r.client_name))}</b>${r.comment ? `<div class="muted">${esc(r.comment)}</div>` : ''}</div>`).join('')}</div>` : ''}`;
  },
  bind() {
    const p = this.p;
    const patch = async (body, msg) => { try { const r = await api('PATCH', '/api/me/profissional', body); state.user = r.user; if (msg) toast(msg); return r; } catch (err) { toast(err.message, true); return null; } };
    document.getElementById('gear').onclick = () => go('account');
    document.getElementById('mng').onclick = () => go('myservices');
    document.getElementById('editSpec').onclick = () => {
      const ov = sheet(`<h3>Sua especialidade</h3><input id="sp" maxlength="60" value="${esc(p.specialty || '')}" placeholder="Ex.: Especialista em Telhados e Coberturas"><div class="actions"><button class="btn light" data-close>Cancelar</button><button class="btn" id="ok">Salvar</button></div>`);
      ov.el.querySelector('#ok').onclick = async () => { if (await patch({ specialty: ov.el.querySelector('#sp').value }, 'Especialidade salva.')) { ov.close(); renderApp(); } };
    };
    $app.querySelectorAll('[data-catt]').forEach((cb) => (cb.onchange = async () => {
      const cats = [...$app.querySelectorAll('[data-catt]')].filter((x) => x.checked).map((x) => x.dataset.catt);
      if (!(await patch({ categories: cats }, cb.checked ? `${cb.dataset.catt} ligado.` : `${cb.dataset.catt} desligado.`))) cb.checked = !cb.checked;
    }));
    document.getElementById('saveVp').onclick = async () => {
      const v = document.getElementById('vp').value.replace(/[^\d,.]/g, '').replace(/\.(?=\d{3})/g, '');
      try { const r = await api('PATCH', '/api/me/profissional', { visit_price: v }); state.user = r.user; document.getElementById('vpErr').textContent = ''; document.getElementById('vp').value = brl(r.user.visit_price); toast('Valor da visita salvo.'); }
      catch (err) { document.getElementById('vpErr').textContent = (err.fields && err.fields.visit_price) || err.message; }
    };
    const file = document.getElementById('phFile');
    const pick = () => file.click();
    document.getElementById('addPh').onclick = pick;
    const a2 = document.getElementById('addPh2'); if (a2) a2.onclick = pick;
    file.onchange = async () => {
      if (!file.files[0]) return;
      try { const image = await fileToAvatar(file.files[0]); await api('POST', '/api/me/portfolio', { image }); toast('Foto adicionada ao portfólio.'); renderApp(); }
      catch (err) { toast(err.message, true); }
    };
    $app.querySelectorAll('[data-rmph]').forEach((b) => (b.onclick = async () => { try { await api('DELETE', `/api/me/portfolio/${b.dataset.rmph}`); renderApp(); } catch (err) { toast(err.message, true); } }));
  },
});

// Gerenciar serviços (criar, editar, ativar/desativar)
async function loadCategories() {
  if (!state.categories) state.categories = (await api('GET', '/api/categories')).categories;
  return state.categories;
}
function realStatsHtml(s) {
  const r = s.real_stats;
  if (!r || !r.count) return '';
  const tip = r.suggested_min && r.suggested_min !== s.duration_min ? ` · <b style="color:${r.suggested_min < s.duration_min ? 'var(--green)' : '#c2410c'}">sugestão: ${fmtDur(r.suggested_min)}</b>` : '';
  return `<small style="display:block;margin-top:4px">Tempo real típico: ${fmtDur(r.median_min)} (${r.count} atendimento(s))${tip}</small>`;
}
screen('myservices', {
  async html() {
    await loadCategories();
    state.myServices = (await api('GET', '/api/services/mine')).services;
    return `${topbar('Meus Serviços')}<div class="pad" style="margin:8px 0 14px"><button class="btn" id="newService">${ic('plus')} Novo serviço</button></div>
      ${state.myServices.length ? state.myServices.map((s) => `<div class="card"><div class="row-between"><div><b style="color:var(--ink)">${CAT_ICON[s.category] || '🛠️'} ${esc(s.title)}</b><div class="small muted">${esc(s.category)} · ${fmtDur(s.duration_min)} · <b style="color:var(--ink)">${brl(s.price)}</b></div>${realStatsHtml(s)}</div>
        <div style="text-align:right"><span class="pill ${s.active ? 'green' : 'gray'}">${s.active ? 'Ativo' : 'Inativo'}</span><br><button class="link" data-editsvc="${s.id}" style="margin-top:8px">Editar</button></div></div></div>`).join('')
        : '<div class="empty">Você ainda não cadastrou serviços.<br>Cadastre um para aparecer na busca dos clientes.</div>'}`;
  },
  bind() {
    document.getElementById('newService').onclick = () => serviceModal(null);
    $app.querySelectorAll('[data-editsvc]').forEach((b) => (b.onclick = () => serviceModal(state.myServices.find((s) => s.id === Number(b.dataset.editsvc)))));
  },
});
function serviceModal(s) {
  const isNew = !s;
  const durations = [30, 45, 60, 90, 120, 150, 180, 240, 300, 360, 480];
  const ov = sheet(`<h3>${isNew ? 'Novo serviço' : 'Editar serviço'}</h3>
    <form id="sf" novalidate>
      <label class="lbl">Título</label><input name="title" maxlength="80" value="${esc(s?.title)}" placeholder="Ex.: Troca de torneira"><div class="field-error" data-err="title"></div>
      <label class="lbl">Categoria</label><select name="category">${state.categories.map((c) => `<option value="${esc(c.nome)}" ${(s?.category || '') === c.nome ? 'selected' : ''}>${esc(c.nome)}</option>`).join('')}</select><div class="field-error" data-err="category"></div>
      <label class="lbl">Descrição</label><textarea name="description" rows="3" maxlength="300">${esc(s?.description)}</textarea><div class="field-error" data-err="description"></div>
      <div class="two"><div><label class="lbl">Preço (R$)</label><input name="price" type="number" inputmode="decimal" min="0" step="0.01" value="${s ? s.price : ''}"><div class="field-error" data-err="price"></div></div>
        <div><label class="lbl">Duração</label><select name="duration_min">${durations.map((d) => `<option value="${d}" ${(s?.duration_min || 60) === d ? 'selected' : ''}>${fmtDur(d)}</option>`).join('')}</select></div></div>
      ${isNew ? '' : `<div class="switch-row"><div><b style="font-size:14px">Serviço ativo</b><div class="small muted">Inativos não aparecem na busca</div></div><label class="toggle"><input type="checkbox" name="active" ${s.active ? 'checked' : ''}><span></span></label></div>`}
      <div class="actions"><button type="button" class="btn light" data-close>Cancelar</button><button type="submit" class="btn">Salvar</button></div>
    </form>`);
  const f = ov.el.querySelector('#sf');
  f.onsubmit = async (e) => {
    e.preventDefault();
    const body = { title: f.title.value, category: f.category.value, description: f.description.value, price: f.price.value, duration_min: Number(f.duration_min.value) };
    const fields = {};
    if (body.title.trim().length < 3) fields.title = 'O título deve ter de 3 a 80 caracteres.';
    if (!(Number(body.price) > 0)) fields.price = 'Informe um preço maior que zero.';
    showFieldErrors(f, fields); formAlert(f, '');
    if (Object.keys(fields).length) return;
    if (!isNew) body.active = f.active.checked;
    try {
      if (isNew) await api('POST', '/api/services', body); else await api('PATCH', `/api/services/${s.id}`, body);
      ov.close(); toast(isNew ? 'Serviço cadastrado.' : 'Serviço atualizado.'); renderApp();
    } catch (err) { showFieldErrors(f, err.fields); formAlert(f, err.message); }
  };
}

// =====================================================================
// ADMIN (não está no Figma: usa o mesmo visual)
// =====================================================================
screen('ahome', {
  async html() {
    const r = await api('GET', '/api/admin/resumo');
    const u = state.user;
    return `<div class="hero"><div class="who">${avatarHtml(u, 'on-hero')}<div><b>Olá, ${esc(first(u.name))} 👋</b><small>Painel administrativo</small></div>${bellHtml()}</div></div>
      <div class="stats"><div class="stat"><b>${r.clientes}</b><small>Clientes</small></div><div class="stat"><b>${r.prestadores}</b><small>Prestadores</small></div><div class="stat"><b>${r.desativados}</b><small>Desativados</small></div></div>
      <div class="stats"><div class="stat"><b>${r.pedidos}</b><small>Pedidos</small></div><div class="stat"><b>${r.pendentes}</b><small>Pendentes</small></div><div class="stat"><b>${r.concluidos}</b><small>Concluídos</small></div></div>
      <div class="empty">Use a aba <b>Usuários</b> para gerenciar contas, <b>Pedidos</b> para acompanhar os agendamentos e <b>Vendas</b> para ver os pagamentos.</div>`;
  },
  bind() {},
});

function usersUrl() {
  const q = new URLSearchParams(Object.entries(state.filters).filter(([, v]) => v)).toString();
  return '/api/users?limit=100' + (q ? '&' + q : '');
}
const userRow = (u) => `<div class="card user-row">${avatarHtml(u)}<div class="info"><b>${esc(u.name)}</b><small>${esc(u.email)}</small>
  <div class="badges"><span class="pill ${u.role === 'prestador' ? 'orange' : u.role === 'admin' ? 'purple' : 'blue'}">${ROLE_LABEL[u.role]}</span><span class="pill ${u.active ? 'green' : 'red'}">${u.active ? 'Ativo' : 'Desativado'}</span></div></div>
  <button class="link" data-edit="${u.id}">Editar</button></div>`;
screen('users', {
  async html() {
    const d = await api('GET', usersUrl());
    state.users = d.users;
    const f = state.filters;
    return `<div class="page-title"><h2>Usuários</h2><button class="btn sm" id="newUser">${ic('plus')} Novo</button></div>
      <div class="toolbar"><div class="field">${ic('search')}<input id="search" type="search" placeholder="Buscar por nome ou e-mail" value="${esc(f.search)}"></div>
        <div class="filters"><select id="fRole"><option value="">Todos os perfis</option>${['admin', 'cliente', 'prestador'].map((r) => `<option value="${r}" ${f.role === r ? 'selected' : ''}>${ROLE_LABEL[r]}</option>`).join('')}</select>
          <select id="fStatus"><option value="">Qualquer status</option><option value="ativo" ${f.status === 'ativo' ? 'selected' : ''}>Ativos</option><option value="inativo" ${f.status === 'inativo' ? 'selected' : ''}>Desativados</option></select></div></div>
      <div class="count">${d.total} usuário(s)</div>${d.users.length ? d.users.map(userRow).join('') : '<div class="empty">Nenhum resultado encontrado.</div>'}`;
  },
  bind() {
    let t;
    const s = document.getElementById('search');
    s.oninput = () => { clearTimeout(t); t = setTimeout(() => { state.filters.search = s.value.trim(); renderApp(); }, 400); };
    document.getElementById('fRole').onchange = (e) => { state.filters.role = e.target.value; renderApp(); };
    document.getElementById('fStatus').onchange = (e) => { state.filters.status = e.target.value; renderApp(); };
    document.getElementById('newUser').onclick = () => userModal(null);
    $app.querySelectorAll('[data-edit]').forEach((b) => (b.onclick = () => userModal(state.users.find((u) => u.id === Number(b.dataset.edit)))));
  },
});
function userModal(u) {
  const isNew = !u, self = u && u.id === state.user.id;
  const ov = sheet(`<h3>${isNew ? 'Novo usuário' : 'Editar usuário'}</h3>
    <form id="mf" novalidate>
      <label class="lbl">Nome completo</label><input name="name" value="${esc(u?.name)}"><div class="field-error" data-err="name"></div>
      <label class="lbl">E-mail</label><input name="email" type="email" value="${esc(u?.email)}"><div class="field-error" data-err="email"></div>
      <label class="lbl">Telefone</label><input name="phone" value="${esc(u?.phone)}"><div class="field-error" data-err="phone"></div>
      <label class="lbl">Perfil</label><select name="role" ${self ? 'disabled' : ''}>${['cliente', 'prestador', 'admin'].map((r) => `<option value="${r}" ${(u?.role || 'cliente') === r ? 'selected' : ''}>${ROLE_LABEL[r]}</option>`).join('')}</select><div class="field-error" data-err="role"></div>
      ${isNew ? '<label class="lbl">Senha inicial</label><input name="password" type="password" autocomplete="new-password"><div class="field-error" data-err="password"></div>'
        : `<div class="switch-row"><div><b style="font-size:14px">Conta ativa</b><div class="small muted">Desativados não conseguem entrar</div></div><label class="toggle"><input type="checkbox" name="active" ${u.active ? 'checked' : ''} ${self ? 'disabled' : ''}><span></span></label></div>`}
      ${self ? '<div class="alert info" style="word-break:normal">Você não pode desativar nem alterar o perfil da sua própria conta.</div>' : ''}
      <div class="actions"><button type="button" class="btn light" data-close>Cancelar</button><button type="submit" class="btn">Salvar</button></div>
    </form>`);
  const f = ov.el.querySelector('#mf');
  f.onsubmit = async (e) => {
    e.preventDefault();
    const body = { name: f.name.value, email: f.email.value, phone: f.phone.value, role: f.role.value };
    const fields = {};
    if (body.name.trim().length < 3) fields.name = 'Informe o nome completo (mín. 3 caracteres).';
    if (!EMAIL_RE.test(body.email.trim())) fields.email = 'Informe um e-mail válido.';
    if (isNew) { body.password = f.password.value; const pe = pwError(body.password); if (pe) fields.password = pe; }
    showFieldErrors(f, fields); formAlert(f, '');
    if (Object.keys(fields).length) return;
    if (!isNew && !self) body.active = f.active.checked;
    if (self) delete body.role;
    try {
      if (isNew) await api('POST', '/api/users', body); else await api('PATCH', `/api/users/${u.id}`, body);
      ov.close(); toast(isNew ? 'Usuário criado.' : 'Alterações salvas.'); renderApp();
    } catch (err) { showFieldErrors(f, err.fields); formAlert(f, err.message); }
  };
}
screen('orders', {
  async html() {
    const f = state.orderFilter;
    const d = await api('GET', '/api/orders?limit=100' + (f ? `&status=${f}` : ''));
    return `<div class="page-title"><h2>Pedidos</h2></div>
      <div class="chips"><button class="chip ${!f ? 'on' : ''}" data-of="">Todos</button>${Object.entries(STATUS_LABEL).map(([v, l]) => `<button class="chip ${f === v ? 'on' : ''}" data-of="${v}">${l}</button>`).join('')}</div>
      <div class="count">${d.total} pedido(s)</div>${d.orders.length ? d.orders.map((o) => agendaCardClient(o).replace('Profissional:', 'Cliente → Profissional:').replace(`>Cliente: ${esc(o.client.name)}<`, `>${esc(o.client.name)} → ${esc(o.provider.name)}<`)).join('') : '<div class="empty">Nenhum pedido.</div>'}`;
  },
  bind() { $app.querySelectorAll('[data-of]').forEach((b) => (b.onclick = () => { state.orderFilter = b.dataset.of; renderApp(); })); },
});

// Sessão persistida: ao abrir o app, pergunta ao backend se ainda há sessão válida.
(async function init() {
  try {
    const { user } = await api('GET', '/api/auth/me');
    enterApp(user);
  } catch (e) {
    state.view = 'login';
    render();
  }
})();
