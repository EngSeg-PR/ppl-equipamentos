(()=>{
 let context,logged=false,tab='records',modules=null,view=0,owner=false,dossierEmployee='',attentionEmployee='';
 const slug=new URLSearchParams(location.search).get('company')||'ppl';
 const status=document.querySelector('#status'),workspace=document.querySelector('#management-workspace'),content=document.querySelector('#management-content');
 async function dashboard(){if(!logged)return;const expected=++view;modules?.destroy();modules=null;content.replaceChildren();status.textContent='Carregando registros…';document.querySelectorAll('[data-module]').forEach(b=>b.classList.toggle('selected',b.dataset.module===tab));try{
  if(tab==='records'){const panel=await PRRecords('#management-content',{companyId:context.company.id,employees:context.employees,isCurrent:()=>logged&&expected===view});if(!logged||expected!==view){panel?.destroy();return;}modules=panel;}
  else if(tab==='dossier'){modules=PRStaffDossier.create({host:content,company:context.company,employees:context.employees,isCurrent:()=>logged&&expected===view});await modules.open(dossierEmployee);}
  else if(tab==='attention-history'){modules=PRAttentionHistory.create({host:content,company:context.company,employees:context.employees,isCurrent:()=>logged&&expected===view});await modules.open(attentionEmployee);}
  else if(['permit','certificate','service-order'].includes(tab)){modules=PRPPLDocuments.create({host:content,company:context.company,employees:context.employees,owner});await modules.open(tab);}
  else{modules=PRManagementModules.create({host:content,company:context.company,employees:context.employees,owner});await modules.open(tab);}
  if(logged&&expected===view)status.textContent='';
 }catch(e){if(logged&&expected===view)status.textContent=e.message;}}
 window.addEventListener('prs-open-dossier',event=>{if(!logged)return;dossierEmployee=event.detail?.employeeId||'';tab='dossier';dashboard();});
 window.addEventListener('prs-open-attention-history',event=>{if(!logged)return;attentionEmployee=event.detail?.employeeId||'';tab='attention-history';dashboard();});
 document.querySelectorAll('[data-module]').forEach(b=>b.onclick=()=>{tab=b.dataset.module;if(tab==='attention-history')attentionEmployee='';dashboard();});
 document.querySelector('#refresh').onclick=dashboard;
 document.querySelector('#logout').onclick=()=>{logged=false;++view;modules?.destroy();modules=null;PR.logout();if(context)context.employees=[];workspace.hidden=true;content.replaceChildren();document.querySelector('#login-box').hidden=false;status.textContent='Sessão encerrada.';};
 document.querySelector('#login-form').onsubmit=async e=>{e.preventDefault();const f=e.currentTarget,b=f.querySelector('button');b.disabled=true;try{if(!context)throw Error('Selecione uma empresa válida.');const v=new FormData(f);const access=await PR.login(v.get('email'),v.get('password'),context.company.id);owner=access.profile.role==='owner';const authorized=await PR.context(slug,{private:true});context={...authorized,company:{...authorized.company,defaults:authorized.defaults||{}}};f.reset();logged=true;document.querySelector('#login-box').hidden=true;workspace.hidden=false;await dashboard();}catch(e){logged=false;PR.logout();status.textContent=e.message;}finally{b.disabled=false;}};
 (async()=>{try{context=await PR.context(slug);context.company={...context.company,defaults:context.defaults||context.company.defaults||{}};const company=context.company;document.querySelector('#company-name').textContent=company.name+' · Gestão';const im=document.querySelector('#company-logo');im.src=company.logoData;im.alt=company.name;im.hidden=!company.logoData;document.querySelector('#record-link').href='executant.html?company='+encodeURIComponent(slug);}catch(e){status.textContent=e.message;}})();
 setInterval(()=>{if(logged)PR.call('session',{companyId:context.company.id},true).catch(()=>document.querySelector('#logout').click());},60000);
})();
