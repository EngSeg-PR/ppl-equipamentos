/* Authenticated inspection consultation. Original PDF bytes and record revisions are retained. */
window.PRRecords=async function(host,{owner=false,companyId,companies=[],employees=[],isCurrent=()=>true}={}){
 const h=typeof host==='string'?document.querySelector(host):host,E=PR.escape;
 if(!h)throw Error('Área de consulta indisponível.');
 let alive=true,rows=[],viewToken=0,viewer=null,eventDialog=null,objectURL=null;
 const current=()=>alive&&isCurrent(),normalize=value=>String(value||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('pt-BR').trim(),names=new Map(companies.map(c=>[c.id,c.name]));
 const companyOf=row=>row.company_id||row.payload?.company?.id||companyId||'',groupOf=row=>companyOf(row)+':'+row.payload.id;
 const kindOf=row=>row.record_kind||row.payload.kind||'checklist',ncOf=row=>row.payload.answers?.some(a=>a.value==='Não Conforme')||false;
 const date=value=>/^\d{4}-\d{2}-\d{2}$/.test(value||'')?value.split('-').reverse().join('/'):value||'—';
 const fullName=row=>row.payload.fields.inspector||'Responsável não informado',number=row=>row.payload.fields.employee||'';
 const originalPersonKey=row=>row.payload.staff?.id?'staff:'+companyOf(row)+':'+row.payload.staff.id:null;
 const pair=(company,name,number)=>company+':'+normalize(name)+'|'+normalize(number);
 const container=document.createElement('section');container.className='records-panel';
 function revokePDF(){if(objectURL){URL.revokeObjectURL(objectURL);objectURL=null;}}
 function closeViewer(){++viewToken;if(viewer){const old=viewer;viewer=null;old.close();old.remove();}revokePDF();}
 const module={destroy(){alive=false;closeViewer();if(eventDialog){eventDialog.close();eventDialog.remove();eventDialog=null;}container.remove();}};
 try{
  for(let offset=0;;offset+=50){
   const page=await PR.call(owner?'owner-records':'list',{companyId,offset},true);if(!current())return module;
   rows.push(...page.rows);if(page.rows.length<50)break;if(offset>100000)throw Error('Filtre ou exporte os registros para volumes maiores.');
  }
 }catch(error){if(!current())return module;throw error;}
 // Match legacy declarations only when that name AND number identify exactly one stable ID.
 const knownPairs=new Map(),people=new Map(),groups=new Map();
 function rememberPair(key,id){if(!knownPairs.has(key))knownPairs.set(key,new Set());knownPairs.get(key).add(id);}
 for(const row of rows){const key=originalPersonKey(row);if(key)rememberPair(pair(companyOf(row),fullName(row),number(row)),key);const group=groupOf(row);if(!groups.has(group))groups.set(group,[]);groups.get(group).push(row);}
 for(const person of employees){const cid=person.company_id||companyId;if(cid)rememberPair(pair(cid,person.name,person.employee_number),'staff:'+cid+':'+person.id);}
 function personKey(row){const stable=originalPersonKey(row);if(stable)return stable;const declaration=pair(companyOf(row),fullName(row),number(row)),matches=knownPairs.get(declaration);return matches?.size===1?[...matches][0]:'legacy:'+declaration;}
 for(const row of rows){const key=personKey(row);let person=people.get(key);if(!person){person={key,company:companyOf(row),name:fullName(row),number:number(row),aliases:new Set(),latest:''};people.set(key,person);}person.aliases.add(normalize(fullName(row)+' '+number(row)));if((row.received_at||'')>=person.latest){person.name=fullName(row);person.number=number(row);person.latest=row.received_at||'';}}
 for(const employee of employees){const key='staff:'+(employee.company_id||companyId)+':'+employee.id,person=people.get(key);if(person){person.name=employee.name;person.number=employee.employee_number;person.aliases.add(normalize(employee.name+' '+employee.employee_number));}}
 for(const group of groups.values())group.sort((a,b)=>Number(b.payload.revision)-Number(a.payload.revision));
 container.innerHTML=`<div class="platform-box"><h2>Consultar checklists e inspeções</h2><p class="platform-note">Consulte o documento PDF ou baixe a cópia original. Registros offline aparecem após sincronização. Ausência de registro não indica falha.</p>
  <div class="platform-filters records-filters"><label>Colaborador<select id="filter-collaborator"><option value="">Todos os colaboradores</option>${[...people.values()].sort((a,b)=>a.name.localeCompare(b.name,'pt-BR')).map(p=>`<option value="${E(p.key)}">${E(p.name)} · ${E(p.number||'sem matrícula')}${owner?' · '+E(names.get(p.company)||p.company):''}${p.key.startsWith('legacy:')?' (registro antigo)':''}</option>`).join('')}</select></label>
  <label>Pesquisar colaborador<input id="filter-collaborator-search" type="search" placeholder="Nome ou matrícula de quem registrou"></label><label>Buscar no registro<input id="filter-search" type="search" placeholder="Equipamento, identificação ou modelo"></label>
  ${owner?`<label>Empresa<select id="filter-company"><option value="">Todas as empresas</option>${companies.map(c=>`<option value="${E(c.id)}">${E(c.name)}</option>`).join('')}</select></label>`:''}
  <label>Mês<input id="filter-month" type="month"></label><label>Data inicial<input id="filter-start" type="date"></label><label>Data final<input id="filter-end" type="date"></label><label>Tipo<select id="filter-kind"><option value="">Todos</option><option value="checklist">Checklist</option><option value="inspection">Inspeção</option></select></label><label>Resultado<select id="filter-result"><option value="">Todos</option><option value="nc">Não Conforme</option><option value="c">Sem Não Conforme</option></select></label></div>
  <div class="records-filter-actions"><button type="button" data-clear-filters>Limpar filtros</button><p class="platform-note">Cada registro aparece uma vez, na última revisão que atende aos filtros. As demais revisões permanecem disponíveis na consulta.</p></div><p data-filter-status role="status"></p><div id="record-counts" class="platform-grid"></div><div id="company-counts"></div><div id="record-cards"></div></div>`;
 if(!current())return module;h.replaceChildren(container);
 const value=id=>container.querySelector(id)?.value||'';
 function filteredRows(){
  const search=normalize(value('#filter-search')),personSearch=normalize(value('#filter-collaborator-search')),chosen=value('#filter-collaborator');
  const matching=rows.filter(row=>{const r=row.payload,f=r.fields,p=people.get(personKey(row)),aliases=[...(p?.aliases||[])].join(' ');return(!value('#filter-company')||companyOf(row)===value('#filter-company'))&&(!chosen||personKey(row)===chosen)&&(!personSearch||aliases.includes(personSearch))&&(!value('#filter-month')||(f.date||'').startsWith(value('#filter-month')))&&(!value('#filter-start')||f.date>=value('#filter-start'))&&(!value('#filter-end')||f.date<=value('#filter-end'))&&(!value('#filter-kind')||kindOf(row)===value('#filter-kind'))&&(!value('#filter-result')||(value('#filter-result')==='nc'?ncOf(row):!ncOf(row)))&&(!search||normalize([f.inspector,f.employee,f.belt,r.model.equipmentName,r.model.title,aliases].join(' ')).includes(search));});
  const latest=new Map();for(const row of matching){const key=groupOf(row),old=latest.get(key);if(!old||Number(row.payload.revision)>Number(old.payload.revision))latest.set(key,row);}return [...latest.values()].sort((a,b)=>(b.payload.fields.date||'').localeCompare(a.payload.fields.date||'')||(b.received_at||'').localeCompare(a.received_at||''));
 }
 function draw(){
  if(!current())return;const visible=filteredRows(),start=value('#filter-start'),end=value('#filter-end');
  container.querySelector('[data-filter-status]').textContent=start&&end&&start>end?'A data inicial está depois da data final. Ajuste o período.':visible.length+' registro(s) encontrado(s).';
  container.querySelector('#record-counts').innerHTML=[['Checklists',visible.filter(r=>kindOf(r)!=='inspection').length],['Inspeções',visible.filter(r=>kindOf(r)==='inspection').length],['Não Conformes',visible.filter(ncOf).length]].map(([label,n])=>`<div class="platform-card"><b class="platform-count">${n}</b>${label}</div>`).join('');
  container.querySelector('#company-counts').innerHTML=owner?`<div class="table-scroll"><table class="platform-table"><thead><tr><th>Empresa</th><th>Checklists</th><th>Inspeções</th></tr></thead><tbody>${companies.map(c=>`<tr><td>${E(c.name)}</td><td>${visible.filter(r=>companyOf(r)===c.id&&kindOf(r)!=='inspection').length}</td><td>${visible.filter(r=>companyOf(r)===c.id&&kindOf(r)==='inspection').length}</td></tr>`).join('')}</tbody></table></div>`:'';
  container.querySelector('#record-cards').innerHTML=visible.map((row,index)=>{const r=row.payload,f=r.fields;return `<article class="platform-card records-card ${ncOf(row)?'nc':''}" data-record-key="${E(row.key)}"><div class="records-card-heading"><h3>${E(r.model.equipmentName||r.model.title)}</h3><span class="records-result ${ncOf(row)?'nc':''}">${ncOf(row)?'Não Conforme':'Sem Não Conforme'}</span></div><p>${E(r.company?.name||names.get(companyOf(row))||'Empresa')} · ${E(f.belt)}</p><p><strong>${E(fullName(row))}</strong> · matrícula ${E(number(row))}<br>${E(f.functionName||'Função não informada no registro original')}</p><p class="platform-note">${E(date(f.date))} · revisão ${r.revision}${groups.get(groupOf(row)).length>1?' · '+groups.get(groupOf(row)).length+' revisões disponíveis':''}<br>ID ${E(r.id)} · recebido ${E(new Date(row.received_at).toLocaleString('pt-BR'))}</p>${!row.pdf_ready?'<p class="records-pending">PDF ainda pendente de sincronização. O documento ficará disponível após o envio pelo aparelho que realizou o registro.</p>':''}<div class="records-primary-actions"><button type="button" data-pdf="${index}">${row.pdf_ready?'Visualizar PDF':'Consultar registro'}</button><button type="button" data-download-pdf="${index}" ${row.pdf_ready?'':'disabled'}>Baixar PDF</button></div><div class="records-secondary-actions"><button type="button" data-events="${index}">Atualizar acompanhamento</button><span class="platform-note">Situação e observações de acompanhamento.</span></div></article>`;}).join('')||'<p>Nenhum registro para estes filtros.</p>';
  container.querySelectorAll('[data-pdf]').forEach(b=>b.onclick=()=>openPDF(visible[Number(b.dataset.pdf)]));
  container.querySelectorAll('[data-download-pdf]').forEach(b=>b.onclick=()=>openPDF(visible[Number(b.dataset.downloadPdf)],true));
  container.querySelectorAll('[data-events]').forEach(b=>b.onclick=()=>openEvents(visible[Number(b.dataset.events)]));
 }
 container.querySelectorAll('.records-filters input,.records-filters select').forEach(input=>input.addEventListener('input',draw));
 container.querySelector('[data-clear-filters]').onclick=()=>{container.querySelectorAll('.records-filters input,.records-filters select').forEach(input=>input.value='');draw();};draw();
 function createDialog(title,className){const dialog=document.createElement('dialog');dialog.className='records-dialog '+className;dialog.innerHTML=`<header class="records-dialog-heading"><h2>${E(title)}</h2><button type="button" data-close aria-label="Fechar consulta">Fechar</button></header><div class="records-dialog-body"></div>`;document.body.append(dialog);dialog.querySelector('[data-close]').onclick=()=>dialog.close();dialog.showModal();return dialog;}
 async function openPDF(row,download=false){
  if(!current())return;closeViewer();viewer=createDialog('Documento da inspeção','records-pdf-dialog');const dialog=viewer,body=dialog.querySelector('.records-dialog-body'),versions=groups.get(groupOf(row));
  dialog.addEventListener('close',()=>{if(viewer===dialog){viewer=null;++viewToken;revokePDF();}dialog.remove();});
  body.innerHTML=`<label class="records-revision-label">Revisão do registro<select data-pdf-revision>${versions.map((v,i)=>`<option value="${i}" ${v.key===row.key?'selected':''}>Revisão ${v.payload.revision} · ${E(date(v.payload.fields.date))} · ${E(fullName(v))}</option>`).join('')}</select></label><div data-pdf-content></div>`;
  const revision=body.querySelector('[data-pdf-revision]');revision.onchange=()=>loadPDF(versions[Number(revision.value)],false);await loadPDF(row,download);
  async function loadPDF(selected,autoDownload){
   const token=++viewToken,out=body.querySelector('[data-pdf-content]');revokePDF();
   const active=()=>current()&&viewer===dialog&&token===viewToken&&dialog.isConnected;
   const meta=()=>`<div class="records-pdf-meta"><strong>${E(selected.payload.model.equipmentName||selected.payload.model.title)}</strong><p>${E(selected.payload.company?.name||names.get(companyOf(selected))||'Empresa')} · ${E(selected.payload.fields.belt||'Sem identificação complementar')}<br>${E(fullName(selected))} · matrícula ${E(number(selected))}<br>${E(date(selected.payload.fields.date))} · revisão ${selected.payload.revision}<br>ID ${E(selected.payload.id)}</p></div>`;
   out.innerHTML=meta()+'<p role="status">Carregando PDF original…</p>';
   if(!selected.pdf_ready){out.innerHTML=meta()+'<p class="records-pending" role="status">PDF ainda pendente de sincronização. O registro foi recebido, mas a cópia PDF ainda não foi enviada. Conecte o aparelho que realizou a inspeção e envie suas pendências; depois atualize os registros neste painel.</p>';return;}
   try{
    const received=await PR.call('pdf',{companyId:companyOf(selected),key:selected.key},true,true);if(!active())return;
    const bytes=new Uint8Array(await received.arrayBuffer());if(!active())return;if(bytes.length<5||String.fromCharCode(...bytes.subarray(0,5))!=='%PDF-')throw Error('O arquivo recebido não é um PDF válido. Tente novamente.');
    const blob=new Blob([bytes],{type:'application/pdf'}),url=URL.createObjectURL(blob),filename='PR-'+selected.key.replace(':','-r')+'.pdf';objectURL=url;
    out.innerHTML=meta()+`<div class="records-pdf-actions"><a href="${url}" target="_blank" rel="noopener" data-open-pdf>Abrir PDF em outra aba</a><a href="${url}" download="${E(filename)}" data-pdf-download>Baixar PDF</a><button type="button" data-save-pdf>Salvar / compartilhar</button></div><p class="platform-note">Se a prévia não aparecer, use Abrir PDF em outra aba ou Baixar PDF. No iPhone, o compartilhamento permite Salvar em Arquivos.</p><p data-save-status role="status"></p><iframe class="records-pdf-preview" title="PDF da inspeção, revisão ${selected.payload.revision}" src="${url}"></iframe>`;
    out.querySelector('[data-save-pdf]').onclick=async()=>{try{const file=new File([blob],filename,{type:'application/pdf'});if(navigator.canShare?.({files:[file]}))await navigator.share({files:[file],title:'Relatório de inspeção'});else out.querySelector('[data-pdf-download]').click();}catch(error){if(active()&&error.name!=='AbortError')out.querySelector('[data-save-status]').textContent='Não foi possível compartilhar. Use Baixar PDF ou Abrir PDF em outra aba.';}};
    if(autoDownload)out.querySelector('[data-pdf-download]').click();
   }catch(error){if(active()){out.innerHTML=meta()+'<p role="alert">'+E(error.message)+'</p><button type="button" data-retry-pdf>Tentar novamente</button>';out.querySelector('[data-retry-pdf]').onclick=()=>loadPDF(selected,false);}}
  }
 }
 async function openEvents(row){
  if(!current())return;if(eventDialog){eventDialog.close();eventDialog.remove();}eventDialog=createDialog('Acompanhamento da inspeção','records-events-dialog');const dialog=eventDialog,body=dialog.querySelector('.records-dialog-body'),active=()=>current()&&eventDialog===dialog&&dialog.isConnected;
  dialog.addEventListener('close',()=>{if(eventDialog===dialog)eventDialog=null;dialog.remove();});
  async function load(){body.innerHTML='<p role="status">Carregando acompanhamento…</p>';try{const data=await PR.call('events',{companyId:companyOf(row),key:row.key},true);if(!active())return;body.innerHTML='<p class="platform-note">Este formulário altera o acompanhamento. Para consultar o documento, use Visualizar PDF no registro.</p>'+data.rows.map(e=>`<p><strong>${E(e.state)}</strong> · ${E(e.actor_name)}<br>${E(e.note)}</p>`).join('')+'<form><label>Situação do acompanhamento<select name="state"><option>Aberto</option><option>Em acompanhamento</option><option>Encaminhado para avaliação técnica</option></select></label><label>Observação<textarea name="note" required maxlength="10000"></textarea></label><button type="submit">Salvar acompanhamento</button><p role="status"></p></form>';body.querySelector('form').onsubmit=async event=>{event.preventDefault();if(!active())return;const form=event.currentTarget,button=form.querySelector('button');button.disabled=true;try{await PR.call('event',{companyId:companyOf(row),key:row.key,...Object.fromEntries(new FormData(form))},true);if(active())await load();}catch(error){if(active())form.querySelector('[role=status]').textContent=error.message;}finally{button.disabled=false;}};}catch(error){if(active())body.innerHTML='<p role="alert">'+E(error.message)+'</p>';}}
  await load();
 }
 return module;
};
