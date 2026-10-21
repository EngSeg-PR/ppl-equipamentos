/* Owner-only employee forms. Issued documents retain their original employee snapshots. */
window.PREmployees=(()=>{
 const E=value=>PR.escape(value);
 function mount(host,{companyId,rows,jobs=[],moduleVersion=0,isCurrent=()=>true}){
  let alive=true,dirty=false,dialog=null;
  const current=()=>alive&&isCurrent();
  const controls=(person={},prefix='employee')=>{
   const matched=jobs.find(j=>j.id===person.job_id)||jobs.find(j=>j.title.trim().toLocaleLowerCase('pt-BR')===(person.job_title||'').trim().toLocaleLowerCase('pt-BR'));
   return `<div class="employee-fields">
    <label>Nome completo<input name="name" required maxlength="160" autocomplete="off" value="${E(person.name||'')}"></label>
    <label>Matrícula<input name="employeeNumber" required maxlength="80" autocomplete="off" value="${E(person.employee_number||'')}"></label>
    <label>CPF (opcional)<input name="cpf" maxlength="14" inputmode="numeric" autocomplete="off" placeholder="000.000.000-00" value="${E(person.cpf||'')}"></label>
    <label>Selecionar função<select name="jobChoice"><option value="">Selecione uma função</option>${jobs.map(j=>`<option value="${E(j.id)}" ${matched?.id===j.id?'selected':''}>${E(j.title)}</option>`).join('')}<option value="new" ${!matched&&person.job_title?'selected':''}>Nova função / preencher manualmente</option></select></label>
    <div class="employee-wide employee-auto"><div class="employee-label"><label for="${prefix}-job-title">Função</label><button type="button" data-edit-title ${matched?'':'hidden'}>Editar função</button></div><input id="${prefix}-job-title" name="jobTitle" required maxlength="160" value="${E(person.job_title||'')}" ${matched?'readonly':''}></div>
    <div class="employee-wide employee-auto"><div class="employee-label"><label for="${prefix}-job-description">Descrição do cargo / atividades</label><button type="button" data-edit-description ${matched&&person.job_description?'':'hidden'}>Editar descrição</button></div><textarea id="${prefix}-job-description" name="jobDescription" maxlength="10000" rows="5" ${matched&&person.job_description?'readonly':''}>${E(person.job_description||'')}</textarea><p class="employee-hint" data-description-hint>${matched?'Descrição do cadastro. Ao escolher outra função, a descrição será preenchida pelo padrão selecionado.':'Na primeira utilização, escreva a função e sua descrição. Ela ficará disponível nos próximos cadastros desta empresa.'}</p></div>
    <label class="employee-wide employee-checkbox" data-template-option hidden><input type="checkbox" name="updateJobTemplate">Usar esta descrição nos próximos cadastros desta função</label>
   </div>`;
  };
  function wire(form,person=null){
   const choice=form.elements.jobChoice,title=form.elements.jobTitle,description=form.elements.jobDescription,template=form.elements.updateJobTemplate;
   const descriptionButton=form.querySelector('[data-edit-description]'),titleButton=form.querySelector('[data-edit-title]'),hint=form.querySelector('[data-description-hint]'),templateOption=form.querySelector('[data-template-option]');
   let edited=false;
   const selected=()=>jobs.find(j=>j.id===choice.value);
   const templateState=()=>{templateOption.hidden=!selected()||!edited;};
   const mark=()=>{if(person)form.dataset.dirty='true';else dirty=true;};
   form.addEventListener('input',mark);form.addEventListener('change',mark);
   choice.onchange=()=>{
    const job=selected();edited=false;template.checked=false;templateState();
    if(job){title.value=job.title;description.value=job.description||'';title.readOnly=true;description.readOnly=!!job.description;titleButton.hidden=false;descriptionButton.hidden=!job.description;hint.textContent=job.description?'Preenchido automaticamente pela função selecionada. Use Editar descrição para ajustar.':'Esta função ainda não possui descrição. Preencha e marque a opção abaixo para reutilizá-la nos próximos cadastros.';if(!job.description){edited=true;templateState();}}
    else{title.value='';description.value='';title.readOnly=false;description.readOnly=false;titleButton.hidden=true;descriptionButton.hidden=true;hint.textContent='Escreva a nova função e sua descrição. Ao salvar, ela ficará disponível para os próximos cadastros desta empresa.';title.focus();}
   };
   titleButton.onclick=()=>{choice.value='new';title.readOnly=false;description.readOnly=false;titleButton.hidden=true;descriptionButton.hidden=true;template.checked=false;edited=false;templateState();hint.textContent='Você está cadastrando uma nova função. Os demais funcionários permanecem com seus dados atuais.';mark();title.focus();};
   descriptionButton.onclick=()=>{description.readOnly=false;descriptionButton.hidden=true;edited=true;templateState();hint.textContent='A alteração será aplicada a este funcionário. Marque a opção abaixo se também quiser reutilizar a descrição nos próximos cadastros.';description.focus();};
   description.addEventListener('input',()=>{edited=true;templateState();});
   form.onsubmit=async event=>{
    event.preventDefault();if(!current())return;
    const result=form.querySelector('[data-form-status]'),button=form.querySelector('[type=submit]');
    if(moduleVersion<48){result.textContent='A atualização do cadastro ainda não foi ativada no servidor. Atualize a página após a ativação.';return;}
    const payload={companyId,name:form.elements.name.value,employeeNumber:form.elements.employeeNumber.value,cpf:form.elements.cpf.value,jobTitle:title.value,jobDescription:description.value,jobId:selected()?.id||null,updateJobTemplate:!!selected()&&template.checked};
    if(person)Object.assign(payload,{employeeId:person.id,expectedUpdatedAt:person.updated_at});
    const fieldset=form.querySelector('fieldset'),cancel=form.querySelector('[data-cancel]');form.dataset.saving='true';fieldset.disabled=true;button.disabled=true;if(cancel)cancel.disabled=true;result.textContent='Salvando cadastro…';
    try{
     await PR.call(person?'employee-update':'employee-create',payload,true);
     if(!current())return;
     // A saved change is complete even if refreshing the list fails afterwards.
     dirty=false;form.dataset.dirty='';if(person){dialog.close();}else form.reset();
     try{const data=await PR.call('employees',{companyId},true);if(!current())return;rows=data.rows;jobs=data.jobs||[];moduleVersion=data.moduleVersion||0;render();host.querySelector('[data-employee-status]').textContent=person?'Cadastro atualizado. Os documentos já emitidos foram preservados.':'Funcionário cadastrado. A função está disponível para os próximos cadastros.';}
     catch(error){if(current())host.querySelector('[data-employee-status]').textContent='Cadastro salvo. Não foi possível atualizar a lista: '+error.message+' Abra esta aba novamente para consultar.';}
    }catch(error){if(current()&&form.isConnected)result.textContent=error.message;}
    finally{form.dataset.saving='';fieldset.disabled=false;button.disabled=false;if(cancel)cancel.disabled=false;}
   };
  }
  function edit(person){
   if(!current())return;
   if(dirty&&!confirm('Há um novo cadastro não salvo. Deseja descartá-lo para editar este funcionário?'))return;
   dirty=false;
   dialog=document.createElement('dialog');dialog.className='platform-box owner-dialog employee-dialog';dialog.innerHTML=`<h2>Editar funcionário</h2><p>Altere os dados necessários. O vínculo com os documentos já emitidos será mantido.</p><form><fieldset>${controls(person,'employee-edit')}</fieldset><p role="status" data-form-status></p><div class="owner-actions"><button type="submit">Salvar alterações</button><button type="button" data-cancel>Cancelar</button></div></form>`;
   document.body.append(dialog);const f=dialog.querySelector('form');wire(f,person);dialog.querySelector('[data-cancel]').onclick=()=>dialog.close();dialog.addEventListener('cancel',event=>{if(f.dataset.saving==='true')event.preventDefault();});dialog.addEventListener('close',()=>{dialog.remove();dialog=null;});dialog.showModal();
  }
  function render(){
   host.innerHTML=`<section class="platform-box"><h2>Cadastrar funcionário</h2><p class="platform-note">Selecione uma função já cadastrada para preencher a descrição automaticamente ou escolha Nova função.</p><form id="employee-form"><fieldset>${controls()}</fieldset><p role="status" data-form-status></p><button type="submit">Salvar cadastro</button></form><p class="platform-note">Este cadastro preenche os documentos e não cria login de gestão.</p></section>
    <section class="platform-box"><div class="employee-list-heading"><h2>Funcionários cadastrados <span>(${rows.length})</span></h2><label>Buscar funcionário<input type="search" data-employee-search placeholder="Nome, matrícula ou função" autocomplete="off"></label></div><p role="status" data-employee-status></p><div class="employee-list">${rows.map((p,i)=>`<article class="employee-card" data-employee-row="${i}"><div><h3>${E(p.name)}</h3><p>${E(p.job_title)}</p><p class="employee-meta">Matrícula: ${E(p.employee_number)} · CPF: ${p.cpf?'Cadastrado':'Não informado'}${p.active===false?' · Inativo':''}</p></div><button type="button" data-employee-details="${i}" aria-label="Editar funcionário ${E(p.name)}">Editar</button></article>`).join('')||'<p>Nenhum funcionário cadastrado nesta empresa.</p>'}</div><p data-no-results hidden>Nenhum funcionário encontrado.</p></section>`;
   wire(host.querySelector('#employee-form'));
   host.querySelectorAll('[data-employee-details]').forEach(button=>button.onclick=()=>edit(rows[Number(button.dataset.employeeDetails)]));
   host.querySelector('[data-employee-search]').oninput=event=>{const query=event.target.value.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('pt-BR');let count=0;host.querySelectorAll('[data-employee-row]').forEach(card=>{const p=rows[Number(card.dataset.employeeRow)],text=[p.name,p.employee_number,p.job_title].join(' ').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('pt-BR');card.hidden=!text.includes(query);if(!card.hidden)count++;});host.querySelector('[data-no-results]').hidden=count>0||!rows.length;};
  }
  render();
  return {companyId,tab:'employees',hasUnsaved:()=>dirty||!!dialog?.querySelector('form[data-dirty=true]'),destroy(){alive=false;dialog?.close();}};
 }
 return {mount};
})();
