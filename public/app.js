// Biko - frontend (JS puro). Toda regra de segurança real está no backend (server.js);
// aqui a interface apenas se adapta ao perfil do usuário logado.

const $app = document.getElementById('app');
const state = {
  user: null, view: 'login', tab: 'home', resetEmail: '',
  users: [], filters: { search: '', role: '', status: '' },          // gestão de usuários (admin)
  search: { q: '', category: '', maxPrice: '', sort: '' }, results: [], total: 0, categories: null, // busca
  orders: [], orderFilter: '', myServices: [],
  notifCount: 0,                                                      // sino de notificações (microsserviço)
};

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const initials = (n) => n.split(' ').filter(Boolean).slice(0, 2).map((p) => p[0]).join('').toUpperCase();
const ROLE_LABEL = { admin: 'Admin', cliente: 'Cliente', prestador: 'Prestador' };

function toast(msg, isError) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.className = 'toast show' + (isError ? ' error' : '');
  clearTimeout(toast._t);
  toast._t = setTimeout(() => (t.className = 'toast'), 3000);
}

async function api(method, url, body) {
  const res = await fetch(url, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : {},
    body: body ? JSON.stringify(body) : undefined,
    credentials: 'same-origin',
  });
  let data = {};
  try { data = await res.json(); } catch (e) { /* sem corpo */ }
  if (!res.ok) {
    // Sessão expirada / conta desativada no meio do uso -> volta para o login
    if ((res.status === 401 || res.status === 403) && state.user && url !== '/api/auth/login') {
      state.user = null; state.view = 'login';
      render();
      toast(data.error || 'Sessão encerrada.', true);
    }
    const err = new Error(data.error || 'Erro inesperado.');
    err.fields = data.fields || {};
    err.status = res.status;
    throw err;
  }
  return data;
}

function showFieldErrors(form, fields) {
  form.querySelectorAll('.field-error').forEach((e) => (e.textContent = ''));
  form.querySelectorAll('input.invalid').forEach((i) => i.classList.remove('invalid'));
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

// ---------- telas de autenticação ----------
function authShell(inner) {
  return `<div class="screen pad">
    <div class="logo">b</div><div class="brand">biko</div>
    ${inner}
  </div>`;
}

function viewLogin() {
  $app.innerHTML = authShell(`
    <div class="tagline">Encontre quem precisa no pedágio e fecha o serviço rápido.</div>
    <form id="f" novalidate>
      <label for="email">E-mail</label>
      <input id="email" name="email" type="email" autocomplete="username" placeholder="exemplo@email.com">
      <div class="field-error" data-err="email"></div>
      <div class="row-between"><label for="password">Senha</label><button type="button" class="link" id="forgot">Esqueci a senha</button></div>
      <input id="password" name="password" type="password" autocomplete="current-password" placeholder="Sua senha">
      <div class="field-error" data-err="password"></div>
      <button class="btn" type="submit">Entrar</button>
    </form>
    <div class="footer-text">Não tem conta? <button class="link" id="goReg">Cadastre-se</button></div>
    <div class="footer-text" style="font-size:12px">Demo: admin@biko.com / Admin@123<br>cliente@biko.com / Cliente@123<br>prestador@biko.com / Prestador@123<br>joana@biko.com / Joana@123 (prestadora)</div>
  `);
  const f = document.getElementById('f');
  document.getElementById('goReg').onclick = () => { state.view = 'register'; render(); };
  document.getElementById('forgot').onclick = () => { state.view = 'forgot'; render(); };
  f.onsubmit = async (e) => {
    e.preventDefault();
    const email = f.email.value.trim(), password = f.password.value;
    const fields = {};
    if (!EMAIL_RE.test(email)) fields.email = 'Informe um e-mail válido.';
    if (!password) fields.password = 'Informe a senha.';
    showFieldErrors(f, fields); formAlert(f, '');
    if (Object.keys(fields).length) return;
    const btn = f.querySelector('button[type=submit]'); btn.disabled = true;
    try {
      const { user } = await api('POST', '/api/auth/login', { email, password });
      enterApp(user);
    } catch (err) { formAlert(f, err.message); }
    btn.disabled = false;
  };
}

function viewRegister() {
  let role = 'cliente';
  $app.innerHTML = authShell(`
    <div class="tagline">Crie sua conta</div>
    <form id="f" novalidate>
      <label>Quero usar o Biko como</label>
      <div class="seg"><button type="button" data-role="cliente" class="on">Cliente</button><button type="button" data-role="prestador">Prestador</button></div>
      <label for="name">Nome completo</label>
      <input id="name" name="name" autocomplete="name"><div class="field-error" data-err="name"></div>
      <label for="email">E-mail</label>
      <input id="email" name="email" type="email" autocomplete="username"><div class="field-error" data-err="email"></div>
      <label for="phone">Telefone</label>
      <input id="phone" name="phone" type="tel" placeholder="(47) 99999-9999"><div class="field-error" data-err="phone"></div>
      <label for="password">Senha</label>
      <input id="password" name="password" type="password" autocomplete="new-password" placeholder="Mín. 8 caracteres, letras e números"><div class="field-error" data-err="password"></div>
      <label for="confirm">Confirmar senha</label>
      <input id="confirm" name="confirm" type="password" autocomplete="new-password"><div class="field-error" data-err="confirm"></div>
      <button class="btn" type="submit">Criar conta</button>
    </form>
    <div class="footer-text">Já tem conta? <button class="link" id="goLogin">Entrar</button></div>
  `);
  const f = document.getElementById('f');
  document.getElementById('goLogin').onclick = () => { state.view = 'login'; render(); };
  f.querySelectorAll('.seg button').forEach((b) => (b.onclick = () => {
    role = b.dataset.role;
    f.querySelectorAll('.seg button').forEach((x) => x.classList.toggle('on', x === b));
  }));
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
      const { user } = await api('POST', '/api/auth/register', { name: v.name, email: v.email, phone: v.phone, password: v.password, role });
      toast('Conta criada com sucesso!');
      enterApp(user);
    } catch (err) { showFieldErrors(f, err.fields); formAlert(f, err.message); }
    btn.disabled = false;
  };
}

function viewForgot() {
  $app.innerHTML = authShell(`
    <div class="tagline">Recuperar senha</div>
    <form id="f" novalidate>
      <label for="email">E-mail da sua conta</label>
      <input id="email" name="email" type="email" placeholder="exemplo@email.com"><div class="field-error" data-err="email"></div>
      <button class="btn" type="submit">Enviar código</button>
    </form>
    <div class="footer-text"><button class="link" id="back">Voltar ao login</button> · <button class="link" id="hasCode">Já tenho um código</button></div>
  `);
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
  $app.innerHTML = authShell(`
    <div class="tagline">Defina uma nova senha</div>
    <form id="f" novalidate>
      <label for="token">Código de recuperação</label>
      <input id="token" name="token" value="${esc(state.resetToken || '')}"><div class="field-error" data-err="token"></div>
      <label for="password">Nova senha</label>
      <input id="password" name="password" type="password" autocomplete="new-password"><div class="field-error" data-err="password"></div>
      <label for="confirm">Confirmar nova senha</label>
      <input id="confirm" name="confirm" type="password" autocomplete="new-password"><div class="field-error" data-err="confirm"></div>
      <button class="btn" type="submit">Redefinir senha</button>
    </form>
    <div class="footer-text"><button class="link" id="back">Voltar ao login</button></div>
  `);
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
      state.resetToken = '';
      state.view = 'login'; render();
      toast('Senha redefinida! Faça login.');
    } catch (err) { formAlert(f, err.message); }
  };
}

// ---------- app logado ----------
function enterApp(user) {
  state.user = user;
  state.tab = 'home';
  state.view = 'app';
  state.notifCount = 0;
  render();
  refreshBell();
}

// ---------- formatação ----------
const brl = (v) => Number(v).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
const dateBR = (d) => String(d).split('-').reverse().join('/');
const fmtDur = (m) => (m < 60 ? `${m} min` : m % 60 === 0 ? `${m / 60} h` : `${Math.floor(m / 60)} h ${m % 60} min`);
const dateTimeBR = (ms) => new Date(ms).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
const pad2 = (n) => String(n).padStart(2, '0');
const ymd = (d) => `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
const toMin = (hhmm) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5));
const STATUS_LABEL = { pendente: 'Pendente', confirmado: 'Confirmado', recusado: 'Recusado', concluido: 'Concluído', cancelado: 'Cancelado' };
const CAT_ICON = { 'Telhado & Reparador': '🏠', Encanador: '🔧', Eletricista: '⚡', Pintor: '🎨', Limpeza: '🧹', Jardinagem: '🌿' };
const ACTION_LABEL = { confirmar: 'Confirmar pedido', recusar: 'Recusar', atrasar: 'Avisar atraso / imprevisto', iniciar: 'Iniciar atendimento', estender: 'Preciso de mais tempo', concluir: 'Marcar como concluído', cancelar: 'Cancelar pedido' };
const ACTION_DONE = { confirmar: 'Pedido confirmado.', recusar: 'Pedido recusado.', atrasar: 'Cliente avisado. O horário foi adiado.', iniciar: 'Atendimento iniciado.', estender: 'Tempo prorrogado. A agenda foi ajustada.', concluir: 'Pedido concluído.', cancelar: 'Pedido cancelado.' };
// Eventos do histórico que não são status (agenda elástica)
const EVENT_LABEL = { ...STATUS_LABEL, atrasado: 'Aviso de atraso', iniciado: 'Atendimento iniciado', prorrogado: 'Tempo prorrogado', remarcado: 'Horário remarcado', pago: 'Pagamento aprovado', estornado: 'Pagamento estornado' };
const OPEN_MIN = 7 * 60, CLOSE_MIN = 20 * 60; // mesmo horário de atendimento do backend

// Avatar: foto (se houver) ou iniciais do nome
function avatarHtml(u, cls = '') {
  const inner = u.photo_url ? `<img src="${esc(u.photo_url)}" alt="Foto de ${esc(u.name)}">` : esc(initials(u.name || '?'));
  return `<div class="avatar ${cls}">${inner}</div>`;
}

function navItems() {
  const r = state.user.role;
  const items = [{ id: 'home', ico: '🏠', label: 'Início' }];
  if (r === 'cliente') { items.push({ id: 'search', ico: '🔍', label: 'Buscar' }, { id: 'orders', ico: '📅', label: 'Pedidos' }, { id: 'sales', ico: '💳', label: 'Pagamentos' }); }
  if (r === 'prestador') { items.push({ id: 'services', ico: '🛠️', label: 'Serviços' }, { id: 'orders', ico: '📅', label: 'Pedidos' }, { id: 'sales', ico: '💰', label: 'Vendas' }); }
  if (r === 'admin') { items.push({ id: 'users', ico: '👥', label: 'Usuários' }, { id: 'orders', ico: '📅', label: 'Pedidos' }, { id: 'sales', ico: '💰', label: 'Vendas' }); }
  items.push({ id: 'account', ico: '👤', label: 'Conta' });
  return items;
}

function shell(content) {
  const u = state.user;
  return `
    <div class="screen">
      <div class="top"><div class="hello">
        <div><h2>Olá, ${esc(u.name.split(' ')[0])} 👋</h2><p>${u.role === 'cliente' ? 'O que você precisa hoje?' : u.role === 'prestador' ? 'Veja seus pedidos de hoje' : 'Painel administrativo'}</p></div>
        <div class="top-right">${bellHtml()}${avatarHtml(u)}</div>
      </div></div>
      ${content}
    </div>
    <nav class="nav">${navItems().map((i) => `<button data-tab="${i.id}" class="${state.tab === i.id ? 'on' : ''}"><span class="ico">${i.ico}</span>${i.label}</button>`).join('')}</nav>`;
}

async function viewApp() {
  const seq = (viewApp.seq = (viewApp.seq || 0) + 1); // ignora respostas atrasadas se o usuário trocar de aba rápido
  $app.innerHTML = shell('<div class="spinner">Carregando…</div>');
  bindNav();
  try {
    const tab = state.tab;
    let html = '';
    if (tab === 'home') html = await homeHtml();
    else if (tab === 'search') html = await searchHtml();
    else if (tab === 'orders') html = await ordersHtml();
    else if (tab === 'services') html = await servicesHtml();
    else if (tab === 'users') { await loadUsers(); html = usersHtml(); }
    else if (tab === 'sales') html = await salesHtml();
    else html = accountHtml();
    if (seq !== viewApp.seq) return;
    $app.innerHTML = shell(html);
    bindNav();
    if (tab === 'home') bindHome();
    if (tab === 'search') bindSearch();
    if (tab === 'orders') bindOrders();
    if (tab === 'services') bindServices();
    if (tab === 'users') bindUsers();
    if (tab === 'sales') bindSales();
    if (tab === 'account') bindAccount();
  } catch (err) {
    if (state.user && seq === viewApp.seq) { $app.innerHTML = shell(`<div class="empty">${esc(err.message)}</div>`); bindNav(); }
  }
}

function goTab(tab) { state.tab = tab; viewApp(); }
function bindNav() {
  $app.querySelectorAll('.nav button').forEach((b) => (b.onclick = () => goTab(b.dataset.tab)));
  const bell = $app.querySelector('#bell');
  if (bell) bell.onclick = notifModal;
}

// ---------- notificações (vêm do microsserviço, passando pela API principal) ----------
function bellHtml() {
  const n = state.notifCount;
  return `<button type="button" class="bell" id="bell" aria-label="Notificações${n ? ` (${n} não lidas)` : ''}">🔔${n ? `<span class="bell-count">${n > 9 ? '9+' : n}</span>` : ''}</button>`;
}
function paintBell() {
  const b = $app.querySelector('#bell');
  if (b) { b.outerHTML = bellHtml(); $app.querySelector('#bell').onclick = notifModal; }
}
// Atualiza o número do sino. Se o microsserviço estiver fora do ar, o sino só fica sem número.
async function refreshBell() {
  if (!state.user) return;
  try { state.notifCount = (await api('GET', '/api/notificacoes/contagem')).nao_lidas; }
  catch (e) { state.notifCount = 0; }
  paintBell();
}
setInterval(() => { if (state.user && !document.hidden) refreshBell(); }, 20000);

// Histórico de notificações: cada item mostra o NOME DA AÇÃO (ex.: "Pedido confirmado"), não a data.
const NOTIF_ICON = { pendente: '🆕', confirmado: '✅', recusado: '⛔', cancelado: '✖️', concluido: '🏁', atrasado: '⏰', iniciado: '▶️', prorrogado: '⏳', remarcado: '🔁', pago: '💰', estornado: '↩️' };
async function notifModal() {
  const ov = document.createElement('div');
  ov.className = 'overlay';
  ov.innerHTML = '<div class="sheet"><h3>Notificações</h3><div class="spinner">Carregando…</div></div>';
  $app.appendChild(ov);
  const close = () => ov.remove();
  ov.onclick = (e) => { if (e.target === ov) close(); };
  let d;
  try { d = await api('GET', '/api/notificacoes?limit=30'); }
  catch (err) {
    ov.querySelector('.sheet').innerHTML = `<h3>Notificações</h3><div class="notice warn">${esc(err.message)}</div><button type="button" class="btn secondary" id="nClose">Fechar</button>`;
    ov.querySelector('#nClose').onclick = close;
    return;
  }
  state.notifCount = d.nao_lidas; paintBell();
  const item = (n) => `<li class="notif ${n.lida ? '' : 'unread'}" data-id="${n.id}" data-order="${n.pedido_id || ''}">
      <span class="notif-ico">${NOTIF_ICON[n.acao] || '🔔'}</span>
      <div><b>${esc(n.titulo)}</b><small>${esc(n.mensagem)}</small></div>
    </li>`;
  ov.querySelector('.sheet').innerHTML = `
    <div class="row-between"><h3>Notificações</h3>${d.nao_lidas ? `<button type="button" class="link" id="nAll">Marcar todas como lidas</button>` : ''}</div>
    ${d.notificacoes.length ? `<ul class="notif-list">${d.notificacoes.map(item).join('')}</ul>` : '<div class="empty">Nenhuma notificação por enquanto.</div>'}
    <button type="button" class="btn secondary" id="nClose" style="margin-top:12px">Fechar</button>`;
  ov.querySelector('#nClose').onclick = close;
  const all = ov.querySelector('#nAll');
  if (all) all.onclick = async () => {
    try { await api('POST', '/api/notificacoes/lidas'); } catch (err) { return toast(err.message, true); }
    ov.querySelectorAll('.notif.unread').forEach((li) => li.classList.remove('unread'));
    all.remove(); state.notifCount = 0; paintBell();
  };
  ov.querySelectorAll('.notif').forEach((li) => (li.onclick = async () => {
    if (li.classList.contains('unread')) {
      try { state.notifCount = (await api('POST', `/api/notificacoes/${li.dataset.id}/lida`)).nao_lidas; paintBell(); } catch (e) { /* segue mesmo assim */ }
    }
    if (li.dataset.order) { close(); orderModal(Number(li.dataset.order)); }
    else li.classList.remove('unread');
  }));
}

// ---------- início ----------
async function homeHtml() {
  const role = state.user.role;
  if (role === 'prestador') {
    const d = await api('GET', '/api/prestador/painel');
    const prox = d.proximos.length
      ? d.proximos.map(orderCard).join('')
      : '<div class="empty">Nenhum atendimento confirmado por enquanto.</div>';
    return `<div class="stats">
      <div class="stat"><b>${d.resumo.pedidosNovos}</b><small>Pedidos novos</small></div>
      <div class="stat"><b>${d.resumo.avaliacao ?? '—'}</b><small>Avaliação</small></div>
      <div class="stat"><b>${brl(d.resumo.ganhosMes)}</b><small>Ganhos no mês</small></div></div>
      ${d.resumo.pedidosNovos ? `<div class="pad" style="padding-bottom:0"><button class="btn small" id="goPending">Ver ${d.resumo.pedidosNovos} pedido(s) novo(s)</button></div>` : ''}
      <div class="section-title"><span>Próximos atendimentos</span></div>${prox}`;
  }
  if (role === 'admin') {
    const r = await api('GET', '/api/admin/resumo');
    return `<div class="stats">
      <div class="stat"><b>${r.clientes}</b><small>Clientes</small></div>
      <div class="stat"><b>${r.prestadores}</b><small>Prestadores</small></div>
      <div class="stat"><b>${r.desativados}</b><small>Desativados</small></div></div>
      <div class="stats">
      <div class="stat"><b>${r.pedidos}</b><small>Pedidos</small></div>
      <div class="stat"><b>${r.pendentes}</b><small>Pendentes</small></div>
      <div class="stat"><b>${r.concluidos}</b><small>Concluídos</small></div></div>
      <div class="empty">Use a aba <b>Usuários</b> para gerenciar contas e a aba <b>Pedidos</b> para acompanhar os agendamentos.</div>`;
  }
  const d = await api('GET', '/api/cliente/home');
  const avisos = (d.avisos || []).map((o) => `<div class="notice warn" style="margin-bottom:10px">⏰ <b>${esc(o.provider.name)} avisou um atraso</b> em "${esc(o.service_title)}": ${dateBR(o.date)}, era ${o.original_time} e agora é <b>${o.time}</b>.<br>Motivo: ${esc(o.delay_reason)}.</div>${orderCard(o)}`).join('');
  return `${avisos ? `<div class="section-title"><span>Avisos</span></div>${avisos}` : ''}<div class="promo" id="promo" role="button" tabindex="0"><b>Precisa de um profissional?</b><small>Encontre prestadores disponíveis e agende em poucos toques.</small></div>
    <div class="section-title"><span>Categorias populares</span></div>
    ${d.categorias.map((c) => `<div class="cat" data-cat="${esc(c.nome)}" role="button" tabindex="0"><div class="ci">${CAT_ICON[c.nome] || '🛠️'}</div><div style="flex:1"><b>${esc(c.nome)}</b><small>${esc(c.desc)}</small></div><small>${c.total} serviço(s)</small></div>`).join('')}`;
}

function bindHome() {
  const pending = document.getElementById('goPending');
  if (pending) pending.onclick = () => { state.orderFilter = 'pendente'; goTab('orders'); };
  const promo = document.getElementById('promo');
  if (promo) promo.onclick = () => goTab('search');
  $app.querySelectorAll('[data-cat]').forEach((el) => (el.onclick = () => { state.search.category = el.dataset.cat; goTab('search'); }));
  bindOrderCards();
}

// ---------- busca (cliente) ----------
async function loadCategories() {
  if (!state.categories) state.categories = (await api('GET', '/api/categories')).categories;
  return state.categories;
}
async function runSearch() {
  const s = state.search;
  const q = new URLSearchParams();
  if (s.q) q.set('q', s.q);
  if (s.category) q.set('category', s.category);
  if (s.maxPrice !== '') q.set('max_price', s.maxPrice);
  if (s.sort) q.set('sort', s.sort);
  const d = await api('GET', '/api/search?' + q.toString());
  state.results = d.results; state.total = d.total;
}

async function searchHtml() {
  const cats = await loadCategories();
  await runSearch();
  const s = state.search;
  return `<div class="toolbar">
      <input id="q" type="search" placeholder="O que você procura? (ex.: vazamento, pintura)" value="${esc(s.q)}" maxlength="80">
      <div class="filters">
        <select id="sCat"><option value="">Todas as categorias</option>${cats.map((c) => `<option value="${esc(c.nome)}" ${s.category === c.nome ? 'selected' : ''}>${esc(c.nome)}</option>`).join('')}</select>
        <select id="sSort">${[['', 'Mais relevantes'], ['preco_asc', 'Menor preço'], ['preco_desc', 'Maior preço'], ['nome', 'Nome (A–Z)']].map(([v, l]) => `<option value="${v}" ${s.sort === v ? 'selected' : ''}>${l}</option>`).join('')}</select>
      </div>
      <input id="sMax" type="number" inputmode="decimal" min="0" step="1" placeholder="Preço máximo (R$)" value="${esc(s.maxPrice)}">
    </div>
    <div class="count" id="sCount"></div>
    <div id="results"></div>`;
}

function resultsInner() {
  const s = state.search;
  document.getElementById('sCount').textContent = `${state.total} serviço(s) encontrado(s)`;
  if (!state.results.length) {
    const hasFilter = s.q || s.category || s.maxPrice !== '' || s.sort;
    return `<div class="empty">Nenhum resultado encontrado${s.q ? ` para “${esc(s.q)}”` : ''}.<br>Tente outras palavras ou ajuste os filtros.${hasFilter ? '<br><button class="link" id="clearFilters" style="margin-top:10px">Limpar filtros</button>' : ''}</div>`;
  }
  return state.results.map((r) => `<div class="card-item svc">
      ${avatarHtml({ name: r.provider_name, photo_url: r.provider_photo_url }, 'soft')}
      <div class="info"><b>${esc(r.title)}</b><small>${esc(r.provider_name)} · ${esc(r.category)}</small>
        ${r.description ? `<small class="desc">${esc(r.description)}</small>` : ''}
        <div class="meta"><span>${brl(r.price)}</span><span>⏱ ${fmtDur(r.duration_min)}</span></div></div>
      ${state.user.role === 'cliente' ? `<button class="btn small" data-book="${r.id}">Agendar</button>` : ''}</div>`).join('');
}

function paintResults() {
  const box = document.getElementById('results');
  box.innerHTML = resultsInner();
  box.querySelectorAll('[data-book]').forEach((b) => (b.onclick = () => bookModal(state.results.find((r) => r.id === Number(b.dataset.book)))));
  const clear = document.getElementById('clearFilters');
  if (clear) clear.onclick = () => { state.search = { q: '', category: '', maxPrice: '', sort: '' }; viewApp(); };
}

async function refreshResults() {
  try { await runSearch(); paintResults(); } catch (err) { toast(err.message, true); }
}

function bindSearch() {
  let t;
  const q = document.getElementById('q'), max = document.getElementById('sMax');
  const later = (fn) => { clearTimeout(t); t = setTimeout(fn, 300); };
  q.oninput = () => later(() => { state.search.q = q.value.trim(); refreshResults(); });
  max.oninput = () => later(() => { state.search.maxPrice = max.value.trim(); refreshResults(); });
  document.getElementById('sCat').onchange = (e) => { state.search.category = e.target.value; refreshResults(); };
  document.getElementById('sSort').onchange = (e) => { state.search.sort = e.target.value; refreshResults(); };
  paintResults();
}

// ---------- agendamento (modal do cliente) ----------
function bookModal(sv) {
  const today = new Date(), maxDay = new Date(); maxDay.setDate(maxDay.getDate() + 60);
  const ov = document.createElement('div');
  ov.className = 'overlay';
  ov.innerHTML = `<div class="sheet"><h3>Agendar serviço</h3>
    <div class="summary"><b>${esc(sv.title)}</b><small>${esc(sv.provider_name)} · ${brl(sv.price)} · ${fmtDur(sv.duration_min)}</small></div>
    <form id="bf" novalidate>
      <label for="bDate">Data</label><input id="bDate" name="date" type="date" min="${ymd(today)}" max="${ymd(maxDay)}"><div class="field-error" data-err="date"></div>
      <label for="bTime">Horário</label><select id="bTime" name="time" disabled><option value="">Escolha a data primeiro</option></select><div class="field-error" data-err="time"></div>
      <label for="bAddr">Endereço do serviço</label><input id="bAddr" name="address" maxlength="200" placeholder="Rua, número, bairro"><div class="field-error" data-err="address"></div>
      <label for="bNotes">Observações (opcional)</label><textarea id="bNotes" name="notes" rows="3" maxlength="500" placeholder="Conte o que precisa ser feito"></textarea><div class="field-error" data-err="notes"></div>
      <div class="actions" style="margin-top:18px"><button type="button" class="btn secondary" id="cancel" style="margin:0">Voltar</button><button type="submit" class="btn" style="margin:0">Enviar pedido</button></div>
    </form></div>`;
  $app.appendChild(ov);
  const f = ov.querySelector('#bf');
  ov.querySelector('#cancel').onclick = () => ov.remove();
  ov.onclick = (e) => { if (e.target === ov) ov.remove(); };

  async function loadSlots() {
    const date = f.date.value, sel = f.time;
    if (!date) { sel.disabled = true; sel.innerHTML = '<option value="">Escolha a data primeiro</option>'; return; }
    let busy = [];
    try { busy = (await api('GET', `/api/providers/${sv.provider_id}/agenda?date=${date}`)).busy; }
    catch (err) { showFieldErrors(f, { date: err.message }); return; }
    const earliest = Date.now() + 60 * 60000;
    let opts = '', free = 0;
    for (let m = OPEN_MIN; m + sv.duration_min <= CLOSE_MIN; m += 30) {
      const hhmm = `${pad2(Math.floor(m / 60))}:${pad2(m % 60)}`;
      const [y, mo, d] = date.split('-').map(Number);
      const startMs = new Date(y, mo - 1, d, Math.floor(m / 60), m % 60).getTime();
      const taken = busy.some((b) => m < toMin(b.end) && m + sv.duration_min > toMin(b.start));
      const past = startMs < earliest;
      if (!taken && !past) free++;
      opts += `<option value="${hhmm}" ${taken || past ? 'disabled' : ''}>${hhmm}${taken ? ' (ocupado)' : past ? ' (indisponível)' : ''}</option>`;
    }
    sel.innerHTML = `<option value="">${free ? 'Escolha o horário' : 'Sem horários neste dia'}</option>` + opts;
    sel.disabled = !free;
  }
  f.date.onchange = () => { showFieldErrors(f, {}); loadSlots(); };

  f.onsubmit = async (e) => {
    e.preventDefault();
    const fields = {};
    if (!f.date.value) fields.date = 'Escolha a data.';
    if (!f.time.value) fields.time = 'Escolha o horário.';
    if (f.address.value.trim().length < 5) fields.address = 'Informe o endereço do serviço.';
    showFieldErrors(f, fields); formAlert(f, '');
    if (Object.keys(fields).length) return;
    const btn = f.querySelector('button[type=submit]'); btn.disabled = true;
    try {
      await api('POST', '/api/orders', { service_id: sv.id, date: f.date.value, time: f.time.value, address: f.address.value, notes: f.notes.value });
      ov.remove();
      toast('Pedido enviado! Aguarde a confirmação do prestador.');
      state.orderFilter = '';
      goTab('orders');
      return;
    } catch (err) {
      showFieldErrors(f, err.fields); formAlert(f, err.message);
      if (err.status === 409) loadSlots(); // alguém ocupou o horário: atualiza a lista
    }
    btn.disabled = false;
  };
}

// ---------- pedidos ----------
function counterpart(o) {
  const r = state.user.role;
  if (r === 'cliente') return `Prestador: ${o.provider.name}`;
  if (r === 'prestador') return `Cliente: ${o.client.name}`;
  return `${o.client.name} → ${o.provider.name}`;
}

function orderCard(o) {
  return `<div class="card-item order" data-order="${o.id}" role="button" tabindex="0">
    <div class="info"><b>${esc(o.service_title)}</b><small>${esc(counterpart(o))}</small>
      <small>📅 ${dateBR(o.date)} · ${o.time}–${o.end_time}${o.delay_min ? ` <span class="warn">(⏰ atraso +${o.delay_min} min)</span>` : ''}</small></div>
    <div class="right"><span class="badge st-${o.in_progress ? 'andamento' : o.status}">${o.in_progress ? 'Em andamento' : STATUS_LABEL[o.status]}</span><b>${brl(o.price)}</b>${payBadge(o.payment)}</div></div>`;
}

async function ordersHtml() {
  const f = state.orderFilter;
  const d = await api('GET', '/api/orders' + (f ? `?status=${f}` : ''));
  state.orders = d.orders; state.ordersPage = d;
  return `<div class="toolbar"><select id="oFilter"><option value="">Todos os status</option>${Object.entries(STATUS_LABEL).map(([v, l]) => `<option value="${v}" ${f === v ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
    <div class="count">${d.total} pedido(s)</div>
    ${state.orders.length ? `<div id="orderList">${state.orders.map(orderCard).join('')}</div>${moreButton('moreOrders', d.has_more)}`
      : `<div class="empty">${f ? 'Nenhum pedido com esse status.' : state.user.role === 'cliente' ? 'Você ainda não fez nenhum pedido.<br>Use a aba Buscar para encontrar um profissional.' : state.user.role === 'prestador' ? 'Você ainda não tem pedidos.<br>Quando um cliente agendar, ele aparecerá aqui.' : 'Nenhum pedido registrado.'}</div>`}`;
}

// Botão "Carregar mais" das listas paginadas (pedidos e usuários)
const moreButton = (id, show) => `<div class="pad" id="${id}Wrap" ${show ? '' : 'hidden'}><button class="btn small secondary" id="${id}">Carregar mais</button></div>`;
async function loadMore(btnId, url, key, render, onDone) {
  const btn = document.getElementById(btnId);
  btn.disabled = true; btn.textContent = 'Carregando...';
  try {
    const sep = url.includes('?') ? '&' : '?';
    const d = await api('GET', `${url}${sep}offset=${state[key].length}`);
    state[key] = state[key].concat(d[key]);
    render(d[key]);
    document.getElementById(`${btnId}Wrap`).hidden = !d.has_more;
    onDone && onDone();
  } catch (err) { toast(err.message, true); }
  finally { btn.disabled = false; btn.textContent = 'Carregar mais'; }
}

function bindOrders() {
  document.getElementById('oFilter').onchange = (e) => { state.orderFilter = e.target.value; viewApp(); };
  const more = document.getElementById('moreOrders');
  if (more) {
    const f = state.orderFilter;
    more.onclick = () => loadMore('moreOrders', '/api/orders' + (f ? `?status=${f}` : ''), 'orders',
      (items) => document.getElementById('orderList').insertAdjacentHTML('beforeend', items.map(orderCard).join('')), bindOrderCards);
  }
  bindOrderCards();
}
function bindOrderCards() {
  $app.querySelectorAll('[data-order]').forEach((el) => (el.onclick = () => orderModal(Number(el.dataset.order))));
}

async function orderModal(id) {
  let o;
  try { o = (await api('GET', `/api/orders/${id}`)).order; } catch (err) { return toast(err.message, true); }
  const ov = document.createElement('div');
  ov.className = 'overlay';
  const person = (label, p) => `<div class="kv"><span>${label}</span><b>${esc(p.name)}${p.phone ? `<br><small>${esc(p.phone)}</small>` : ''}</b></div>`;
  ov.innerHTML = `<div class="sheet">
    <div class="row-between"><h3>${esc(o.service_title)}</h3><span class="badge st-${o.in_progress ? 'andamento' : o.status}">${o.in_progress ? 'Em andamento' : STATUS_LABEL[o.status]}</span></div>
    <div class="kv"><span>Quando</span><b>${dateBR(o.date)} · ${o.time}–${o.end_time} (${fmtDur(o.duration_min)})</b></div>
    ${o.delay_min ? `<div class="notice warn">⏰ <b>Aviso de atraso:</b> o horário era ${o.original_time} e agora é ${o.time} (+${o.delay_min} min).<br>Motivo: ${esc(o.delay_reason)}.${o.status === 'confirmado' || o.status === 'pendente' ? ' O cliente pode cancelar sem custo.' : ''}</div>` : ''}
    ${o.started_time ? `<div class="kv"><span>Início real</span><b>${o.started_time}${o.extended_min ? ` · previsto até ${o.planned_end_time}, prorrogado +${fmtDur(o.extended_min)}` : ''}</b></div>` : ''}
    ${o.real_duration_min ? `<div class="kv"><span>Tempo real</span><b>${fmtDur(o.real_duration_min)}</b></div>` : ''}
    <div class="kv"><span>Valor</span><b>${brl(o.price)}${payBadge(o.payment)}</b></div>
    ${o.payment && o.payment.status !== 'recusado' ? `<div class="kv"><span>Pagamento</span><b>${PAY_LABEL[o.payment.status] || esc(o.payment.status)}${o.payment.code ? `<br><small>${esc(o.payment.code)}</small>` : ''}<br><button type="button" class="link" id="seeReceipt">${o.payment.status === 'aguardando' && o.can_pay ? 'Continuar pagamento' : 'Ver comprovante'}</button></b></div>` : ''}
    <div class="kv"><span>Endereço</span><b>${esc(o.address)}</b></div>
    ${o.notes ? `<div class="kv"><span>Observações</span><b>${esc(o.notes)}</b></div>` : ''}
    ${person('Cliente', o.client)}${person('Prestador', o.provider)}
    ${o.status_reason ? `<div class="kv"><span>Motivo</span><b>${esc(o.status_reason)}</b></div>` : ''}
    <h4 class="sub">Histórico</h4>
    <ul class="timeline">${o.history.map((h) => `<li><span class="dot st-${h.status}"></span><div><b>${EVENT_LABEL[h.status] || esc(h.status)}</b> <small>${dateTimeBR(h.created_at)}</small><br><small>${esc(h.actor_name || 'Sistema')}${h.note ? ` — ${esc(h.note)}` : ''}</small></div></li>`).join('')}</ul>
    <div id="reasonBox" hidden>
      <div id="extendBox" hidden>
        <label id="extendLabel">Quanto tempo a mais?</label>
        <div class="chips">${[15, 30, 45, 60].map((m, i) => `<label class="chip"><input type="radio" name="extMin" value="${m}" ${i === 0 ? 'checked' : ''}><span>+${m} min</span></label>`).join('')}</div>
        <small class="hint" id="extendHint">Os próximos clientes que forem afetados são remarcados automaticamente e podem cancelar sem custo.</small>
        <div class="field-error" data-err="minutes"></div>
      </div>
      <label for="reason" id="reasonLabel">Motivo</label><textarea id="reason" rows="2" maxlength="200"></textarea><div class="field-error" data-err="reason"></div>
      <div class="actions" style="margin-top:12px"><button type="button" class="btn secondary" id="reasonBack" style="margin:0">Voltar</button><button type="button" class="btn danger" id="reasonOk" style="margin:0">Confirmar</button></div>
    </div>
    <div id="actionBox" class="stack">
      ${o.can_pay && !(o.payment && o.payment.status === 'aguardando') ? `<button type="button" class="btn pay" id="payBtn" style="margin-top:10px">💳 Pagar ${brl(o.price)}</button>` : ''}
      ${o.actions.map((a) => `<button type="button" class="btn ${a === 'confirmar' || a === 'concluir' || a === 'iniciar' ? '' : a === 'recusar' || a === 'cancelar' ? 'danger' : 'secondary'}" data-act="${a}" style="margin-top:10px">${ACTION_LABEL[a]}</button>`).join('')}
      <button type="button" class="btn secondary" id="closeOrder" style="margin-top:10px">Fechar</button>
    </div></div>`;
  $app.appendChild(ov);
  const close = () => ov.remove();
  ov.onclick = (e) => { if (e.target === ov) close(); };
  ov.querySelector('#closeOrder').onclick = close;
  const payBtn = ov.querySelector('#payBtn');
  if (payBtn) payBtn.onclick = () => { close(); payModal(o); };
  const seeReceipt = ov.querySelector('#seeReceipt');
  if (seeReceipt) seeReceipt.onclick = async () => {
    if (o.payment.status === 'aguardando' && o.can_pay) { close(); return payModal(o); }
    try { const { cobranca } = await api('GET', `/api/orders/${o.id}/pagamento`); close(); receiptModal(cobranca); }
    catch (err) { toast(err.message, true); }
  };

  async function send(action, reason, minutes) {
    try {
      await api('POST', `/api/orders/${o.id}/status`, { action, reason, minutes });
      close();
      toast(ACTION_DONE[action]);
      await viewApp();
      refreshBell();
    } catch (err) {
      const inForm = !ov.querySelector('#reasonBox').hidden;
      const f = err.fields || {};
      if (inForm && (f.reason || f.minutes)) {
        ov.querySelector('[data-err="reason"]').textContent = f.reason || '';
        ov.querySelector('[data-err="minutes"]').textContent = f.minutes || '';
        if (f.minutes && !f.reason) toast(err.message, true);
      } else { toast(err.message, true); }
    }
  }
  ov.querySelectorAll('[data-act]').forEach((b) => (b.onclick = () => {
    const a = b.dataset.act;
    if (a === 'recusar' || a === 'cancelar' || a === 'estender' || a === 'atrasar') {
      // recusar, estender e atrasar sempre pedem motivo; cancelar pede motivo (obrigatório para prestador/admin, opcional para o cliente)
      const optional = a === 'cancelar' && state.user.id === o.client.id;
      const timed = a === 'estender' || a === 'atrasar';
      ov.querySelector('#reasonLabel').textContent = timed ? 'O que aconteceu? (ex.: acabou a energia, equipamento quebrado)' : optional ? 'Motivo (opcional)' : 'Motivo';
      ov.querySelector('#extendBox').hidden = !timed;
      ov.querySelector('#extendLabel').textContent = a === 'atrasar' ? `Quanto vai atrasar? (hoje o horário é ${o.time})` : 'Quanto tempo a mais?';
      ov.querySelector('#extendHint').textContent = a === 'atrasar'
        ? 'O cliente vê o aviso com o motivo e o novo horário, e pode cancelar sem custo. Os próximos clientes afetados também são remarcados.'
        : 'Os próximos clientes que forem afetados são remarcados automaticamente e podem cancelar sem custo.';
      ov.querySelector('#reasonOk').className = timed ? 'btn' : 'btn danger';
      ov.querySelector('#reasonBox').hidden = false; ov.querySelector('#actionBox').hidden = true;
      ov.querySelector('#reasonOk').onclick = () => send(a, ov.querySelector('#reason').value,
        timed ? Number(ov.querySelector('input[name="extMin"]:checked').value) : undefined);
      ov.querySelector('#reasonBack').onclick = () => { ov.querySelector('#reasonBox').hidden = true; ov.querySelector('#actionBox').hidden = false; };
    } else send(a);
  }));
}


// =====================================================================
// PAGAMENTOS / VENDAS (SIMULADO — microsserviço pagamentos/, nada é cobrado de verdade)
// =====================================================================
const PAY_LABEL = { aguardando: 'Aguardando Pix', pago: 'Pago', aprovado: 'Aprovado', recusado: 'Recusado', expirado: 'Expirado', estornado: 'Estornado', estorno_pendente: 'Estorno em andamento' };
const payBadge = (p) => (p && p.status !== 'recusado' ? `<span class="pay-badge pb-${p.status}">${p.status === 'pago' ? '✓ ' : ''}${PAY_LABEL[p.status] || esc(p.status)}</span>` : '');
const DEMO_NOTE = '<div class="demo-note">🧪 Ambiente de demonstração (TCC): nenhum valor é cobrado. Não use dados reais.</div>';
const bandeiraDe = (num) => (/^4/.test(num) ? 'Visa' : /^5[1-5]/.test(num) ? 'Mastercard' : /^(4011|4312|4389|5041|5066|5067|6277|6362|6363|6504|6505|6516)/.test(num) ? 'Elo' : 'Cartão');

// "QR Code" de enfeite: desenho gerado a partir do código (não é um QR de verdade)
function fakeQr(text) {
  const n = 25; let h = 2166136261;
  for (const ch of text) { h ^= ch.charCodeAt(0); h = Math.imul(h, 16777619); }
  const rnd = () => { h ^= h << 13; h ^= h >>> 17; h ^= h << 5; return (h >>> 0) / 4294967296; };
  const finder = (x, y) => [[0, 0], [n - 7, 0], [0, n - 7]].some(([fx, fy]) => x >= fx && x < fx + 7 && y >= fy && y < fy + 7);
  const finderOn = (x, y) => { const fx = x < 7 ? 0 : n - 7, fy = y < 7 ? 0 : n - 7; const dx = x - fx, dy = y - fy; return dx === 0 || dy === 0 || dx === 6 || dy === 6 || (dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4); };
  let rects = '';
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
    if (finder(x, y) ? finderOn(x, y) : rnd() > 0.52) rects += `<rect x="${x}" y="${y}" width="1" height="1"/>`;
  }
  return `<svg class="qr" viewBox="-2 -2 ${n + 4} ${n + 4}" role="img" aria-label="QR Code Pix (demonstração)"><rect x="-2" y="-2" width="${n + 4}" height="${n + 4}" fill="#fff"/><g fill="#14213d">${rects}</g></svg>`;
}

function payModal(o) {
  const ov = document.createElement('div');
  ov.className = 'overlay';
  ov.innerHTML = '<div class="sheet"></div>';
  $app.appendChild(ov);
  const sheet = ov.querySelector('.sheet');
  let timer = null;
  const close = () => { clearInterval(timer); ov.remove(); };
  ov.onclick = (e) => { if (e.target === ov) close(); };
  const head = `<div class="row-between"><h3>Pagamento</h3><span class="badge">${brl(o.price)}</span></div>
    <div class="kv"><span>Serviço</span><b>${esc(o.service_title)}</b></div>
    <div class="kv"><span>Prestador</span><b>${esc(o.provider.name)}</b></div>
    <div class="kv"><span>Quando</span><b>${dateBR(o.date)} · ${o.time}</b></div>`;
  const done = async (c) => {
    clearInterval(timer);
    refreshBell();
    if (c.status === 'aprovado') { close(); await viewApp(); receiptModal(c, true); }
  };

  function choose(metodo = 'pix') {
    clearInterval(timer);
    sheet.innerHTML = `${head}${DEMO_NOTE}
      <label>Forma de pagamento</label>
      <div class="seg"><button type="button" data-m="pix" class="${metodo === 'pix' ? 'on' : ''}">◆ Pix</button><button type="button" data-m="cartao" class="${metodo === 'cartao' ? 'on' : ''}">💳 Cartão de crédito</button></div>
      <div id="payBody"></div>`;
    sheet.querySelectorAll('[data-m]').forEach((b) => (b.onclick = () => choose(b.dataset.m)));
    const body = sheet.querySelector('#payBody');
    if (metodo === 'pix') {
      body.innerHTML = `<p class="hint">Aprovação na hora. Vamos gerar um código Pix para este pedido.</p>
        <button type="button" class="btn pay" id="genPix">Gerar Pix de ${brl(o.price)}</button>
        <button type="button" class="btn secondary" id="payCancel" style="margin-top:10px">Voltar</button>`;
      body.querySelector('#genPix').onclick = async (e) => {
        e.target.disabled = true;
        try { const r = await api('POST', `/api/orders/${o.id}/pagamento`, { metodo: 'pix' }); showPix(r.cobranca); }
        catch (err) { e.target.disabled = false; toast(err.message, true); }
      };
    } else {
      const parc = [1, 2, 3].map((n) => `<option value="${n}">${n}x de ${brl(o.price / n)} sem juros</option>`).join('');
      body.innerHTML = `<form id="cardForm" novalidate>
        <div class="card-preview"><span id="cpBrand">Cartão</span><b id="cpNum">•••• •••• •••• ••••</b><small id="cpName">NOME NO CARTÃO</small></div>
        <label for="cNum">Número do cartão</label>
        <input id="cNum" name="cNum" inputmode="numeric" autocomplete="off" placeholder="4242 4242 4242 4242" maxlength="19"><div class="field-error" data-err="cNum"></div>
        <label for="cName">Nome no cartão</label>
        <input id="cName" name="cName" autocomplete="off" placeholder="Como está no cartão"><div class="field-error" data-err="cName"></div>
        <div class="two">
          <div><label for="cExp">Validade</label><input id="cExp" name="cExp" inputmode="numeric" autocomplete="off" placeholder="MM/AA" maxlength="5"><div class="field-error" data-err="cExp"></div></div>
          <div><label for="cCvv">CVV</label><input id="cCvv" name="cCvv" inputmode="numeric" autocomplete="off" placeholder="123" maxlength="4"><div class="field-error" data-err="cCvv"></div></div>
        </div>
        <label for="cParc">Parcelas</label><select id="cParc" name="cParc">${parc}</select>
        <small class="hint">Teste: 4242 4242 4242 4242 é aprovado; um cartão terminado em 0002 é recusado. Só os 4 últimos dígitos saem do seu aparelho.</small>
        <button class="btn pay" type="submit">Pagar ${brl(o.price)}</button>
        <button type="button" class="btn secondary" id="payCancel" style="margin-top:10px">Voltar</button>
      </form>`;
      const f = body.querySelector('#cardForm');
      const digits = () => f.cNum.value.replace(/\D/g, '');
      f.cNum.oninput = () => {
        const d = digits().slice(0, 16);
        f.cNum.value = d.replace(/(\d{4})(?=\d)/g, '$1 ');
        sheet.querySelector('#cpNum').textContent = (d + '•'.repeat(16 - d.length)).replace(/(.{4})(?=.)/g, '$1 ');
        sheet.querySelector('#cpBrand').textContent = bandeiraDe(d);
      };
      f.cName.oninput = () => (sheet.querySelector('#cpName').textContent = f.cName.value.toUpperCase() || 'NOME NO CARTÃO');
      f.cExp.oninput = () => { const d = f.cExp.value.replace(/\D/g, '').slice(0, 4); f.cExp.value = d.length > 2 ? `${d.slice(0, 2)}/${d.slice(2)}` : d; };
      f.onsubmit = async (e) => {
        e.preventDefault();
        const d = digits(), fields = {};
        if (d.length < 13) fields.cNum = 'Número do cartão incompleto.';
        if (f.cName.value.trim().length < 3) fields.cName = 'Informe o nome como está no cartão.';
        const m = /^(\d{2})\/(\d{2})$/.exec(f.cExp.value);
        if (!m || Number(m[1]) < 1 || Number(m[1]) > 12) fields.cExp = 'Validade inválida.';
        if (!/^\d{3,4}$/.test(f.cCvv.value)) fields.cCvv = 'CVV inválido.';
        showFieldErrors(f, fields);
        if (Object.keys(fields).length) return;
        const btn = f.querySelector('button[type=submit]'); btn.disabled = true; btn.textContent = 'Processando…';
        try {
          // Só o final, a bandeira e as parcelas vão para o servidor (o CVV e o número inteiro nunca saem daqui)
          const r = await api('POST', `/api/orders/${o.id}/pagamento`, { metodo: 'cartao', cartao: { final: d.slice(-4), bandeira: bandeiraDe(d), parcelas: Number(f.cParc.value) } });
          if (r.cobranca.status === 'recusado') {
            btn.disabled = false; btn.textContent = `Pagar ${brl(o.price)}`;
            formAlert(f, `❌ ${r.cobranca.motivo}. Tente outro cartão ou pague com Pix.`);
          } else await done(r.cobranca);
        } catch (err) { btn.disabled = false; btn.textContent = `Pagar ${brl(o.price)}`; toast(err.message, true); }
      };
    }
    body.querySelector('#payCancel').onclick = () => { close(); orderModal(o.id); };
  }

  function showPix(c) {
    sheet.innerHTML = `${head}${DEMO_NOTE}
      <div class="pix-box">
        ${fakeQr(c.pix_copia_cola)}
        <small>Escaneie o QR Code no app do seu banco ou use o Pix copia e cola</small>
        <div class="pix-code"><code>${esc(c.pix_copia_cola)}</code></div>
        <button type="button" class="btn secondary small" id="copyPix">Copiar código</button>
        <div class="pix-timer">Expira em <b id="pixLeft">30:00</b></div>
      </div>
      <button type="button" class="btn pay" id="simPix">✅ Simular pagamento recebido (demo)</button>
      <button type="button" class="btn secondary" id="otherWay" style="margin-top:10px">Trocar forma de pagamento</button>`;
    const left = sheet.querySelector('#pixLeft');
    const tick = () => {
      const ms = Math.max(0, c.expira_em - Date.now());
      left.textContent = `${pad2(Math.floor(ms / 60000))}:${pad2(Math.floor((ms % 60000) / 1000))}`;
      if (!ms) clearInterval(timer);
    };
    tick(); timer = setInterval(tick, 1000);
    sheet.querySelector('#copyPix').onclick = async () => {
      try { await navigator.clipboard.writeText(c.pix_copia_cola); toast('Código Pix copiado.'); } catch (e) { toast('Não deu para copiar automaticamente.', true); }
    };
    sheet.querySelector('#otherWay').onclick = () => choose('cartao');
    sheet.querySelector('#simPix').onclick = async (e) => {
      e.target.disabled = true; e.target.textContent = 'Confirmando com o banco…';
      try {
        await new Promise((r) => setTimeout(r, 900)); // só para dar a sensação de "processando"
        const r = await api('POST', `/api/orders/${o.id}/pagamento/confirmar`);
        await done(r.cobranca);
      } catch (err) { e.target.disabled = false; e.target.textContent = '✅ Simular pagamento recebido (demo)'; toast(err.message, true); }
    };
  }

  // Já existe um Pix aguardando para este pedido? Continua dele.
  if (o.payment && o.payment.status === 'aguardando') {
    api('GET', `/api/orders/${o.id}/pagamento`).then(({ cobranca }) => (cobranca && cobranca.status === 'aguardando' ? showPix(cobranca) : choose()))
      .catch((err) => { toast(err.message, true); choose(); });
  } else choose();
}

// Comprovante de pagamento
function receiptModal(c, justPaid) {
  const ov = document.createElement('div');
  ov.className = 'overlay';
  const seller = state.user.role !== 'cliente';
  const forma = c.metodo === 'cartao' ? `${esc(c.cartao.bandeira)} •••• ${esc(c.cartao.final)}${c.parcelas > 1 ? ` · ${c.parcelas}x de ${brl(c.valor / c.parcelas)}` : ' · à vista'}` : 'Pix';
  const when = c.pago_em ? dateTimeBR(c.pago_em) : dateTimeBR(c.criada_em);
  ov.innerHTML = `<div class="sheet receipt">
    <div class="receipt-head ${c.status}">
      <div class="receipt-ico">${c.status === 'aprovado' ? '✓' : c.status === 'estornado' ? '↩' : c.status === 'aguardando' ? '…' : '✕'}</div>
      <h3>${c.status === 'aprovado' ? (justPaid ? 'Pagamento aprovado!' : 'Pagamento aprovado') : PAY_LABEL[c.status] || esc(c.status)}</h3>
      <b class="receipt-value">${brl(c.valor)}</b>
    </div>
    ${DEMO_NOTE}
    <div class="kv"><span>Serviço</span><b>${esc(c.descricao)}</b></div>
    <div class="kv"><span>Pago por</span><b>${esc(c.pagador.nome || '—')}</b></div>
    <div class="kv"><span>Recebido por</span><b>${esc(c.recebedor.nome || '—')}</b></div>
    <div class="kv"><span>Forma</span><b>${forma}</b></div>
    <div class="kv"><span>${c.pago_em ? 'Data do pagamento' : 'Criado em'}</span><b>${when}</b></div>
    <div class="kv"><span>Transação</span><b>${esc(c.codigo)}</b></div>
    ${c.autorizacao ? `<div class="kv"><span>Autorização</span><b>${esc(c.autorizacao)}</b></div>` : ''}
    ${seller ? `<div class="kv"><span>Taxa Biko (10%)</span><b>− ${brl(c.taxa)}</b></div><div class="kv"><span>Valor líquido</span><b>${brl(c.liquido)}</b></div>` : ''}
    ${c.motivo ? `<div class="kv"><span>Observação</span><b>${esc(c.motivo)}</b></div>` : ''}
    <button type="button" class="btn secondary" id="rClose" style="margin-top:14px">Fechar</button>
  </div>`;
  $app.appendChild(ov);
  const close = () => ov.remove();
  ov.onclick = (e) => { if (e.target === ov) close(); };
  ov.querySelector('#rClose').onclick = close;
}

// Aba Vendas (prestador/admin) ou Pagamentos (cliente)
async function salesHtml() {
  const d = await api('GET', '/api/pagamentos?limit=50');
  state.sales = d.cobrancas;
  const r = d.resumo, role = state.user.role;
  const stats = role === 'cliente'
    ? `<div class="stat"><b>${r.vendas}</b><small>Pagamentos</small></div><div class="stat"><b>${brl(r.bruto)}</b><small>Total pago</small></div><div class="stat"><b>${r.estornos}</b><small>Estornos</small></div>`
    : `<div class="stat"><b>${brl(r.bruto)}</b><small>${role === 'admin' ? 'Vendido na plataforma' : 'Total vendido'}</small></div><div class="stat"><b>${brl(r.taxa)}</b><small>Taxa Biko (10%)</small></div><div class="stat"><b>${brl(r.liquido)}</b><small>${role === 'admin' ? 'Repassado' : 'Você recebe'}</small></div>`;
  const item = (c, i) => `<div class="card-item order" data-sale="${i}" role="button" tabindex="0">
      <div class="ci">${c.metodo === 'pix' ? '◆' : '💳'}</div>
      <div class="info"><b>${esc(c.descricao)}</b><small>${role === 'cliente' ? esc(c.recebedor.nome || '') : role === 'admin' ? `${esc(c.pagador.nome || '')} → ${esc(c.recebedor.nome || '')}` : esc(c.pagador.nome || '')}</small>
        <small>${c.metodo === 'pix' ? 'Pix' : `${esc(c.cartao.bandeira)} •••• ${esc(c.cartao.final)}${c.parcelas > 1 ? ` · ${c.parcelas}x` : ''}`} · ${esc(c.codigo)}</small></div>
      <div class="right"><span class="pay-badge pb-${c.status === 'aprovado' ? 'pago' : c.status}">${PAY_LABEL[c.status]}</span><b>${brl(role === 'prestador' ? c.liquido : c.valor)}</b></div></div>`;
  return `${DEMO_NOTE.replace('demo-note', 'demo-note pad-x')}
    <div class="stats">${stats}</div>
    <div class="count">${d.total} transação(ões) · ${r.pix} Pix · ${r.cartao} cartão</div>
    ${d.cobrancas.length ? `<div>${d.cobrancas.map(item).join('')}</div>` : `<div class="empty">${role === 'cliente' ? 'Você ainda não pagou nenhum pedido.<br>Quando o prestador confirmar um pedido, o botão Pagar aparece nele.' : 'Nenhuma venda ainda.'}</div>`}`;
}
function bindSales() {
  $app.querySelectorAll('[data-sale]').forEach((el) => (el.onclick = () => receiptModal(state.sales[Number(el.dataset.sale)])));
}

// ---------- serviços (prestador) ----------
async function servicesHtml() {
  await loadCategories();
  state.myServices = (await api('GET', '/api/services/mine')).services;
  return `<div class="toolbar"><button class="btn small" id="newService" style="justify-self:end">+ Novo serviço</button></div>
    <div class="count">${state.myServices.length} serviço(s)</div>
    ${state.myServices.length ? state.myServices.map((s) => `<div class="card-item svc">
      <div class="ci">${CAT_ICON[s.category] || '🛠️'}</div>
      <div class="info"><b>${esc(s.title)}</b><small>${esc(s.category)}</small>
        <div class="meta"><span>${brl(s.price)}</span><span>⏱ ${fmtDur(s.duration_min)}</span><span class="badge ${s.active ? 'on' : 'off'}">${s.active ? 'Ativo' : 'Inativo'}</span></div>
        ${realStatsHtml(s)}</div>
      <button class="link" data-editsvc="${s.id}">Editar</button></div>`).join('')
      : '<div class="empty">Você ainda não cadastrou serviços.<br>Cadastre um para aparecer na busca dos clientes.</div>'}`;
}

// Tempo real medido (iniciar -> concluir). Sugere a duração típica: imprevistos ficam por conta do "Preciso de mais tempo".
function realStatsHtml(s) {
  const r = s.real_stats;
  if (!r || !r.count) return '';
  const ext = r.extended_count ? ` · ${r.extended_count} precisou(aram) de mais tempo` : '';
  const tip = r.suggested_min && r.suggested_min !== s.duration_min
    ? `<br><b class="${r.suggested_min < s.duration_min ? 'ok' : 'warn'}">Sugestão: cadastrar ${fmtDur(r.suggested_min)}</b>${r.suggested_min < s.duration_min ? ' — você libera horários para mais clientes' : ''}`
    : '';
  return `<small class="real-stats">Tempo real típico: ${fmtDur(r.median_min)} (${r.count} atendimento(s)${ext})${tip}</small>`;
}

function bindServices() {
  document.getElementById('newService').onclick = () => serviceModal(null);
  $app.querySelectorAll('[data-editsvc]').forEach((b) => (b.onclick = () => serviceModal(state.myServices.find((s) => s.id === Number(b.dataset.editsvc)))));
}

function serviceModal(s) {
  const isNew = !s;
  const ov = document.createElement('div');
  ov.className = 'overlay';
  const durations = [30, 45, 60, 90, 120, 150, 180, 240, 300, 360, 480];
  ov.innerHTML = `<div class="sheet"><h3>${isNew ? 'Novo serviço' : 'Editar serviço'}</h3>
    <form id="sf" novalidate>
      <label>Título</label><input name="title" maxlength="80" value="${esc(s?.title)}" placeholder="Ex.: Troca de torneira"><div class="field-error" data-err="title"></div>
      <label>Categoria</label><select name="category">${state.categories.map((c) => `<option value="${esc(c.nome)}" ${(s?.category || '') === c.nome ? 'selected' : ''}>${esc(c.nome)}</option>`).join('')}</select><div class="field-error" data-err="category"></div>
      <label>Descrição</label><textarea name="description" rows="3" maxlength="300">${esc(s?.description)}</textarea><div class="field-error" data-err="description"></div>
      <label>Preço (R$)</label><input name="price" type="number" inputmode="decimal" min="0" step="0.01" value="${s ? s.price : ''}"><div class="field-error" data-err="price"></div>
      <label>Duração</label><select name="duration_min">${durations.map((d) => `<option value="${d}" ${(s?.duration_min || 60) === d ? 'selected' : ''}>${fmtDur(d)}</option>`).join('')}</select><div class="field-error" data-err="duration_min"></div>
      ${isNew ? '' : `<div class="switch-row"><div><b style="font-size:14px">Serviço ativo</b><div style="font-size:12px;color:var(--muted)">Inativos não aparecem na busca</div></div>
        <label class="toggle"><input type="checkbox" name="active" ${s.active ? 'checked' : ''}><span></span></label></div>`}
      <div class="actions" style="margin-top:18px"><button type="button" class="btn secondary" id="cancel" style="margin:0">Cancelar</button><button type="submit" class="btn" style="margin:0">Salvar</button></div>
    </form></div>`;
  $app.appendChild(ov);
  const f = ov.querySelector('#sf');
  ov.querySelector('#cancel').onclick = () => ov.remove();
  ov.onclick = (e) => { if (e.target === ov) ov.remove(); };
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
      ov.remove();
      toast(isNew ? 'Serviço cadastrado.' : 'Serviço atualizado.');
      await viewApp();
    } catch (err) { showFieldErrors(f, err.fields); formAlert(f, err.message); }
  };
}

// ---------- conta / perfil ----------
function accountHtml() {
  const u = state.user;
  return `<div class="pad">
    <div class="photo-row">${avatarHtml(u, 'soft xl')}
      <div style="min-width:0"><b style="font-size:18px;display:block">${esc(u.name)}</b><span class="badge ${u.role}">${ROLE_LABEL[u.role]}</span>
        <div class="photo-actions"><button class="btn small secondary" id="pickPhoto" type="button">${u.photo_url ? 'Trocar foto' : 'Adicionar foto'}</button>${u.photo_url ? '<button class="link danger-link" id="rmPhoto" type="button">Remover</button>' : ''}</div>
        <input type="file" id="photoFile" accept="image/png,image/jpeg,image/webp" hidden></div></div>

    <div class="section-card"><h4>Meus dados</h4>
      <form id="pf" novalidate>
        <label for="pName">Nome completo</label><input id="pName" name="name" autocomplete="name" value="${esc(u.name)}"><div class="field-error" data-err="name"></div>
        <label for="pEmail">E-mail</label><input id="pEmail" name="email" type="email" autocomplete="username" value="${esc(u.email)}"><div class="field-error" data-err="email"></div>
        <label for="pPhone">Telefone</label><input id="pPhone" name="phone" type="tel" autocomplete="tel" value="${esc(u.phone || '')}" placeholder="(47) 99999-9999"><div class="field-error" data-err="phone"></div>
        <div id="pwWrap" hidden><label for="pCur">Senha atual (necessária para trocar o e-mail)</label><input id="pCur" name="currentPassword" type="password" autocomplete="current-password"><div class="field-error" data-err="currentPassword"></div></div>
        <button class="btn" type="submit">Salvar alterações</button>
      </form></div>

    <div class="section-card"><h4>Alterar senha</h4>
      <form id="pwf" novalidate>
        <label for="cur">Senha atual</label><input id="cur" name="currentPassword" type="password" autocomplete="current-password"><div class="field-error" data-err="currentPassword"></div>
        <label for="nw">Nova senha</label><input id="nw" name="newPassword" type="password" autocomplete="new-password" placeholder="Mín. 8 caracteres, letras e números"><div class="field-error" data-err="newPassword"></div>
        <label for="cf">Confirmar nova senha</label><input id="cf" name="confirm" type="password" autocomplete="new-password"><div class="field-error" data-err="confirm"></div>
        <button class="btn" type="submit">Alterar senha</button>
      </form></div>

    <button class="btn danger" id="logout">Sair da conta</button></div>`;
}

// Recorta no centro, reduz para 256x256 e converte para JPEG (a foto fica pequena e dentro do limite do servidor)
function fileToAvatar(file) {
  return new Promise((resolve, reject) => {
    if (!/^image\/(png|jpeg|webp)$/.test(file.type)) return reject(new Error('Escolha uma imagem PNG, JPG ou WEBP.'));
    if (file.size > 8 * 1024 * 1024) return reject(new Error('A imagem é muito grande (máx. 8 MB).'));
    const url = URL.createObjectURL(file), img = new Image();
    img.onload = () => {
      const size = 256, c = document.createElement('canvas'); c.width = c.height = size;
      const side = Math.min(img.width, img.height);
      c.getContext('2d').drawImage(img, (img.width - side) / 2, (img.height - side) / 2, side, side, 0, 0, size, size);
      URL.revokeObjectURL(url);
      resolve(c.toDataURL('image/jpeg', 0.85));
    };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error('Não foi possível ler essa imagem.')); };
    img.src = url;
  });
}

function bindAccount() {
  document.getElementById('logout').onclick = logout;
  const file = document.getElementById('photoFile');
  document.getElementById('pickPhoto').onclick = () => file.click();
  file.onchange = async () => {
    if (!file.files[0]) return;
    try {
      const image = await fileToAvatar(file.files[0]);
      const { user } = await api('PUT', '/api/me/photo', { image });
      state.user = user; toast('Foto atualizada.'); viewApp();
    } catch (err) { toast(err.message, true); }
    file.value = '';
  };
  const rm = document.getElementById('rmPhoto');
  if (rm) rm.onclick = async () => {
    try { const { user } = await api('DELETE', '/api/me/photo'); state.user = user; toast('Foto removida.'); viewApp(); }
    catch (err) { toast(err.message, true); }
  };

  const pf = document.getElementById('pf');
  const original = state.user.email;
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
    try {
      const { user } = await api('PATCH', '/api/me', body);
      state.user = user; toast('Dados atualizados.'); viewApp();
    } catch (err) { showFieldErrors(pf, err.fields); formAlert(pf, err.message); }
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
    try {
      const r = await api('POST', '/api/me/password', { currentPassword: wf.currentPassword.value, newPassword: wf.newPassword.value });
      wf.reset(); showFieldErrors(wf, {}); toast(r.message || 'Senha alterada.');
    } catch (err) { showFieldErrors(wf, err.fields); formAlert(wf, err.fields && Object.keys(err.fields).length ? '' : err.message); }
  };
}

async function logout() {
  try { await api('POST', '/api/auth/logout'); } catch (e) { /* sessão já inválida */ }
  state.user = null; state.view = 'login'; render();
  toast('Você saiu da conta.');
}

// ---------- gestão de usuários (admin) ----------
async function loadUsers() {
  const d = await api('GET', usersUrl());
  state.users = d.users; state.usersPage = d;
}
function usersUrl() {
  const q = new URLSearchParams(Object.entries(state.filters).filter(([, v]) => v)).toString();
  return '/api/users' + (q ? '?' + q : '');
}

function usersHtml() {
  const f = state.filters;
  return `<div class="toolbar">
      <input id="search" type="search" placeholder="Buscar por nome ou e-mail" value="${esc(f.search)}">
      <div class="filters">
        <select id="fRole"><option value="">Todos os perfis</option>${['admin', 'cliente', 'prestador'].map((r) => `<option value="${r}" ${f.role === r ? 'selected' : ''}>${ROLE_LABEL[r]}</option>`).join('')}</select>
        <select id="fStatus"><option value="">Qualquer status</option><option value="ativo" ${f.status === 'ativo' ? 'selected' : ''}>Ativos</option><option value="inativo" ${f.status === 'inativo' ? 'selected' : ''}>Desativados</option></select>
      </div>
      <button class="btn small" id="newUser" style="justify-self:end">+ Novo usuário</button>
    </div>
    <div class="count">${state.usersPage.total} usuário(s)</div>
    <div id="list">${state.users.length ? state.users.map(userRow).join('') : '<div class="empty">Nenhum resultado encontrado.</div>'}</div>
    ${moreButton('moreUsers', state.usersPage.has_more)}`;
}

function userRow(u) {
  return `<div class="user" data-id="${u.id}">
    ${avatarHtml(u, 'soft')}
    <div class="info"><b>${esc(u.name)}</b><small>${esc(u.email)}</small>
      <div class="badges"><span class="badge ${u.role}">${ROLE_LABEL[u.role]}</span><span class="badge ${u.active ? 'on' : 'off'}">${u.active ? 'Ativo' : 'Desativado'}</span></div></div>
    <button class="link" data-edit="${u.id}">Editar</button></div>`;
}

function bindUsers() {
  let t;
  const search = document.getElementById('search');
  search.oninput = () => { clearTimeout(t); t = setTimeout(async () => { state.filters.search = search.value.trim(); await refreshList(); }, 300); };
  document.getElementById('fRole').onchange = async (e) => { state.filters.role = e.target.value; await refreshList(); };
  document.getElementById('fStatus').onchange = async (e) => { state.filters.status = e.target.value; await refreshList(); };
  document.getElementById('newUser').onclick = () => userModal(null);
  document.getElementById('moreUsers').onclick = () => loadMore('moreUsers', usersUrl(), 'users',
    (items) => document.getElementById('list').insertAdjacentHTML('beforeend', items.map(userRow).join('')), bindRows);
  bindRows();
}
function bindRows() {
  $app.querySelectorAll('[data-edit]').forEach((b) => (b.onclick = () => userModal(state.users.find((u) => u.id === Number(b.dataset.edit)))));
}
async function refreshList() {
  try {
    await loadUsers();
    document.querySelector('.count').textContent = `${state.usersPage.total} usuário(s)`;
    document.getElementById('list').innerHTML = state.users.length ? state.users.map(userRow).join('') : '<div class="empty">Nenhum resultado encontrado.</div>';
    document.getElementById('moreUsersWrap').hidden = !state.usersPage.has_more;
    bindRows();
  } catch (err) { toast(err.message, true); }
}

function userModal(u) {
  const isNew = !u;
  const self = u && u.id === state.user.id;
  const ov = document.createElement('div');
  ov.className = 'overlay';
  ov.innerHTML = `<div class="sheet"><h3>${isNew ? 'Novo usuário' : 'Editar usuário'}</h3>
    <form id="mf" novalidate>
      <label>Nome completo</label><input name="name" value="${esc(u?.name)}"><div class="field-error" data-err="name"></div>
      <label>E-mail</label><input name="email" type="email" value="${esc(u?.email)}"><div class="field-error" data-err="email"></div>
      <label>Telefone</label><input name="phone" value="${esc(u?.phone)}"><div class="field-error" data-err="phone"></div>
      <label>Perfil</label>
      <select name="role" ${self ? 'disabled' : ''}>${['cliente', 'prestador', 'admin'].map((r) => `<option value="${r}" ${(u?.role || 'cliente') === r ? 'selected' : ''}>${ROLE_LABEL[r]}</option>`).join('')}</select>
      <div class="field-error" data-err="role"></div>
      ${isNew ? `<label>Senha inicial</label><input name="password" type="password" autocomplete="new-password"><div class="field-error" data-err="password"></div>` : `
      <div class="switch-row"><div><b style="font-size:14px">Conta ativa</b><div style="font-size:12px;color:var(--muted)">Desativados não conseguem entrar</div></div>
        <label class="toggle"><input type="checkbox" name="active" ${u.active ? 'checked' : ''} ${self ? 'disabled' : ''}><span></span></label></div>`}
      ${self ? '<div class="alert info" style="word-break:normal">Você não pode desativar nem alterar o perfil da sua própria conta.</div>' : ''}
      <div class="actions" style="margin-top:18px"><button type="button" class="btn secondary" id="cancel" style="margin:0">Cancelar</button><button type="submit" class="btn" style="margin:0">Salvar</button></div>
    </form></div>`;
  $app.appendChild(ov);
  const f = ov.querySelector('#mf');
  ov.querySelector('#cancel').onclick = () => ov.remove();
  ov.onclick = (e) => { if (e.target === ov) ov.remove(); };
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
      ov.remove();
      toast(isNew ? 'Usuário criado.' : 'Alterações salvas.');
      await viewApp();
    } catch (err) { showFieldErrors(f, err.fields); formAlert(f, err.message); }
  };
}

// ---------- roteamento ----------
function render() {
  if (state.view === 'app' && state.user) return viewApp();
  if (state.view === 'register') return viewRegister();
  if (state.view === 'forgot') return viewForgot();
  if (state.view === 'reset') return viewReset();
  return viewLogin();
}

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
