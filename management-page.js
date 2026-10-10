(()=>{
 let context,logged=false,tab='records',modules=null,view=0,owner=false;
 const status=document.querySelector('#status'),workspace=document.querySelector('#management-workspace'),content=document.querySelector('#management-content');
 async function dashboard(){if(!logged)return;const expected=++view;modules?.destroy();modules=null;content.replaceChildren();status.textContent='Carregando registros…';document.querySelectorAll('[data-module]').forEach(b=>b.classList.toggle('selected',b.dataset.module===tab));try{
  if(tab==='records'){await PRRecords('#management-content',{companyId:context.company.id});}
  else if(['permit','certificate','service-order'].includes(tab)){modules=PRPPLDocuments.create({host:content,company:context.company,employees:context.employees,owner});await modules.open(tab);}
  else{modules=PRManagementModules.create({host:content,company:context.company,employees:context.employees,owner});await modules.open(tab);}
  if(logged&&expected===view)status.textContent='';
 }catch(e){if(logged&&expected===view)status.textContent=e.message;}}
 document.querySelectorAll('[data-module]').forEach(b=>b.onclick=()=>{tab=b.dataset.module;dashboard();});
 document.querySelector('#refresh').onclick=dashboard;
 document.querySelector('#logout').onclick=()=>{logged=false;++view;modules?.destroy();modules=null;PR.logout();workspace.hidden=true;content.replaceChildren();document.querySelector('#login-box').hidden=false;status.textContent='Sessão encerrada.';};
 document.querySelector('#login-form').onsubmit=async e=>{e.preventDefault();const f=e.currentTarget,b=f.querySelector('button');b.disabled=true;try{if(!context)throw Error('Selecione uma empresa válida.');const v=new FormData(f);const access=await PR.login(v.get('email'),v.get('password'),context.company.id);owner=access.profile.role==='owner';f.reset();logged=true;document.querySelector('#login-box').hidden=true;workspace.hidden=false;await dashboard();}catch(e){PR.logout();status.textContent=e.message;}finally{b.disabled=false;}};
 (async()=>{try{const slug=new URLSearchParams(location.search).get('company')||'ppl';context=await PR.context(slug);const company=context.company;document.querySelector('#company-name').textContent=company.name+' · Gestão';const im=document.querySelector('#company-logo');im.src=company.logoData;im.alt=company.name;im.hidden=!company.logoData;document.querySelector('#record-link').href='executant.html?company='+encodeURIComponent(slug);}catch(e){status.textContent=e.message;}})();
 setInterval(()=>{if(logged)PR.call('session',{companyId:context.company.id},true).catch(()=>document.querySelector('#logout').click());},60000);
})();
