/* Company-scoped field access. The server validates every online session and submission. */
(() => {
  const prefix = 'prs-executor-session-v54:';
  const sessions = new Map();
  let context = null, slug = '', opening = null, modal = null, generation = 0, directory = [];
  const esc = value => PR.escape(value);
  const supported = () => !!context && (Number(context.moduleVersion) >= 54 || typeof context.executorAccessRequired === 'boolean');
  const valid = row => !context?.accessDenied && !!row?.executorToken && Date.parse(row.expiresAt) > Date.now() && row.company?.id === context?.company?.id && !!row.employee?.id;
  function saved() {
    if (!context?.company?.id) return null;
    let row = sessions.get(context.company.id);
    if (!row) {
      try { row = JSON.parse(localStorage.getItem(prefix + context.company.id)); } catch {}
      if (row) sessions.set(context.company.id, row);
    }
    return valid(row) ? row : null;
  }
  function matchCompany(value) { return !value || value === slug || value === context?.company?.id || value === context?.company?.slug; }
  function own(value) { return matchCompany(value) ? saved()?.employee || null : null; }
  function emit() {
    if (supported() && window.PRContext) PRContext.employees = own() ? [own()] : [];
    paint();
    window.dispatchEvent(new CustomEvent('prs-executor-changed', {detail:{employee:own(),companyId:context?.company?.id}}));
  }
  function paint() {
    const host = document.querySelector('#executor-identity');
    if (!host || !supported()) return;
    const row = saved();
    host.hidden = false;
    host.innerHTML = row
      ? `<p class="executor-label">Executante identificado</p><strong>${esc(row.employee.name)}</strong><p>${esc(row.employee.job_title || '')}</p><button type="button" data-executor-change>Trocar colaborador / sair</button>`
      : '<p class="executor-label">Acesso do executante</p><p>Identifique-se para iniciar ou continuar um preenchimento.</p><button type="button" data-executor-enter>Entrar como executante</button>';
    host.querySelector('[data-executor-enter]')?.addEventListener('click', () => ensure(slug));
    host.querySelector('[data-executor-change]')?.addEventListener('click', async () => {
      if (typeof busy !== 'undefined' && busy) return;
      await logout();
      await ensure(slug);
    });
  }
  async function logout(value) {
    if (!matchCompany(value)) return;
    const row = saved();
    generation++;
    sessions.delete(context?.company?.id);
    try { localStorage.removeItem(prefix + context.company.id); } catch {}
    emit();
    if (row && navigator.onLine) {
      try { await PR.call('executor-logout', {companyId:row.company.id}, false, false, {executorToken:row.executorToken}); } catch {}
    }
  }
  function applyIdentity(record) {
    if (!supported()) return record;
    const employee = own(record.company?.id);
    if (!employee) throw Error('Entre como executante para preencher este registro.');
    if (record.staff?.id && record.staff.id !== employee.id) throw Error('Este rascunho pertence a outro colaborador. Entre com o nome correspondente para continuá-lo.');
    record.staff = {id:employee.id};
    Object.assign(record.fields, {inspector:employee.name,employee:employee.employee_number,functionName:employee.job_title || ''});
    return record;
  }
  async function guardRecord(record) {
    if (!supported()) return true;
    if (!await ensure(slug, {allowLocal:true})) return false;
    const employee = own(record.company?.id);
    if (!employee || record.staff?.id && record.staff.id !== employee.id) {
      if (typeof message === 'function') message('Este rascunho pertence a outro colaborador. Troque o acesso para continuar. A cópia foi preservada.', true);
      return false;
    }
    return true;
  }
  async function verify(row, expected) {
    const result = await PR.call('executor-session', {companyId:row.company.id}, false, false, {executorToken:row.executorToken});
    if (expected !== generation) throw Error('Acesso alterado. Entre novamente.');
    const updated = {...row, ...result, executorToken:row.executorToken};
    if (!valid(updated) || updated.employee.id !== row.employee.id) throw Error('Sessão do executante inválida.');
    persist(updated);
    return true;
  }
  function persist(row) {
    const safe = {executorToken:String(row.executorToken),expiresAt:String(row.expiresAt),company:{id:row.company.id,slug:row.company.slug,name:row.company.name},
      employee:{id:row.employee.id,name:row.employee.name,employee_number:row.employee.employee_number,job_title:row.employee.job_title || '',job_description:row.employee.job_description || ''}};
    sessions.set(context.company.id, safe);
    // The typed password is not saved separately. The employee number remains in the profile and documents.
    // Because that number is the initial password, this is only basic access control, not strong identity proof.
    try { localStorage.setItem(prefix + context.company.id, JSON.stringify(safe)); } catch {}
    emit();
  }
  async function ensure(value = slug, options = {}) {
    if (!supported()) return true;
    if (!matchCompany(value)) return false;
    const row = saved();
    if (row) {
      if (!navigator.onLine) return true;
      try { return await verify(row, generation); }
      catch (error) {
        if ([401,403].includes(error.status)) await logout();
        else if (valid(row) && !error.status) return true;
        else if (typeof message === 'function') message(error.message, true);
      }
    }
    if (opening) return opening;
    opening = loginDialog(options).finally(() => { opening = null; });
    return opening;
  }
  function loginDialog(options) {
    return new Promise(resolve => {
      let finished = false;
      const expected = generation;
      const finish = value => { if (finished) return; finished = true; modal?.close(); modal?.remove(); modal = null; resolve(value); };
      modal = document.createElement('dialog');
      modal.className = 'executor-dialog';
      modal.setAttribute('aria-labelledby', 'executor-login-title');
      modal.innerHTML = `<form class="executor-login"><h2 id="executor-login-title">Acesso do executante</h2><p>Selecione seu nome e informe sua matrícula cadastrada. Os seus dados preencherão os checklists e as inspeções.</p><label>Colaborador<select name="executorEmployee" required><option value="">Carregando colaboradores…</option></select></label><label>Matrícula<input name="executorPassword" type="password" required autocomplete="off" inputmode="text"></label><p class="executor-login-status" role="status" aria-live="polite"></p><div class="actions"><button type="submit" class="primary">Entrar</button><button type="button" data-executor-local>Consultar pendências e PDFs deste aparelho</button></div><p class="muted">O primeiro acesso exige internet. Um acesso já autorizado pode ser utilizado sem conexão até o fim da sessão. A matrícula é um controle básico de acesso.</p></form>`;
      document.body.append(modal);
      const form = modal.querySelector('form'), select = form.elements.executorEmployee, password = form.elements.executorPassword;
      const status = modal.querySelector('[role=status]'), submit = modal.querySelector('[type=submit]');
      const pending = () => { finish(false); if (typeof showPending === 'function') void showPending(); };
      modal.querySelector('[data-executor-local]').onclick = pending;
      modal.addEventListener('cancel', event => { event.preventDefault(); pending(); });
      submit.disabled = true;
      form.onsubmit = async event => {
        event.preventDefault();
        if (!navigator.onLine) { status.textContent = 'Conecte-se à internet para validar um novo acesso. As cópias locais continuam disponíveis.'; return; }
        if (!form.reportValidity()) return;
        submit.disabled = true;
        if(context.accessDenied || !context.company?.id){status.textContent='A empresa não está disponível para novos registros. As cópias locais continuam preservadas.';return;}
        const secret = password.value;
        password.value = '';
        status.textContent = 'Validando acesso…';
        try {
          const result = await PR.call('executor-login', {slug,companyId:context.company.id,employeeId:select.value,password:secret});
          if (generation !== expected || finished) return;
          if (!valid(result)) throw Error('Não foi possível confirmar este acesso. Tente novamente.');
          persist(result);
          finish(true);
        } catch (error) { if (!finished) status.textContent = error.message; }
        finally { if (!finished) submit.disabled = false; }
      };
      modal.showModal();
      if (context.accessDenied || !context.company?.id) {
        select.innerHTML = '<option value="">Novos registros indisponíveis</option>';
        status.textContent = context.errorMessage || 'Não foi possível confirmar o acesso desta empresa. Consulte as cópias locais e tente novamente com conexão.';
        return;
      }
      if (!navigator.onLine) {
        select.innerHTML = '<option value="">Novo acesso indisponível sem conexão</option>';
        status.textContent = 'Não há sessão válida neste aparelho. Consulte as pendências e os PDFs, ou conecte-se para entrar.';
        return;
      }
      PR.call('executor-directory', {slug,companyId:context.company.id}).then(result => {
        if (finished || generation !== expected) return;
        directory = result.employees.map(p=>({id:p.id,name:p.name}));
        select.innerHTML = '<option value="">Selecione o seu nome</option>' + result.employees.map(employee => `<option value="${esc(employee.id)}">${esc(employee.name)}</option>`).join('');
        submit.disabled = !result.employees.length;
        if (!result.employees.length) status.textContent = 'Nenhum colaborador ativo cadastrado. Solicite o cadastro ao proprietário.';
        select.focus();
      }).catch(error => { if (!finished) { status.textContent = error.message; select.innerHTML = '<option value="">Não foi possível consultar os colaboradores</option>'; } });
    });
  }
  function configure(value, companySlug) { context = value; slug = companySlug; emit(); }
  window.PRExecutor = {
    configure, ensure, current:own, people:()=>directory.map(p=>({...p})), token:value => matchCompany(value) ? saved()?.executorToken || null : null,
    logout, applyIdentity, guardRecord, required:supported,
    canEdit:record => !supported() || !!own(record?.company?.id) && (!record?.staff?.id || record.staff.id === own(record.company?.id).id)
  };
  window.addEventListener('storage', event => { if (event.key === prefix + context?.company?.id) { sessions.clear(); generation++; emit(); } });
  setInterval(() => { if (supported() && document.querySelector('#executor-identity strong') && !saved()) emit(); }, 15000);
})();
