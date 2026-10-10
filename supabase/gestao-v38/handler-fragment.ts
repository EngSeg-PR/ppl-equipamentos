  if(['management-list','management-save','management-file-put','management-file-get'].includes(b.action)){
   const authorized=async(unit:string,team:string)=>owner||!!await checked(scoped.rpc('ppl_can_read_company',{c:selected.id,u:unit,t:team}));
   const kinds=['training','legal-action','legal-document','nr'];
   const programs=['PGR','PCMSO','PPR','PCA','PAE','LIP','LTCAT'];
   const day=(v:any,optional=false)=>{if(optional&&!v)return '';if(typeof v!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(v))fail('Data inválida.');const d=new Date(v+'T12:00:00Z');if(!Number.isFinite(+d)||d.toISOString().slice(0,10)!==v)fail('Data inválida.');return v;};
   if(b.action==='management-list'){
    const offset=Number(b.offset||0);if(!Number.isInteger(offset)||offset<0)fail('Página inválida.');
    const rows=await checked(scoped.from('ppl_management_entries').select('*').eq('company_id',selected.id).order('id').range(offset,offset+99));
    const files=rows.length?await checked(scoped.from('ppl_management_files').select('id,entry_id,name,mime,size,created_at').eq('company_id',selected.id).in('entry_id',rows.map((r:any)=>r.id))):[];
    return respond({rows,files,scopes:owner||member?.scope_mode==='company'?null:await checked(admin.from('ppl_scopes').select('unit,team').eq('user_id',profile.user_id).eq('company_id',selected.id)),moduleVersion:38});
   }
   if(b.action==='management-save'){
    if(!uuid(b.id)||!kinds.includes(b.kind)||!b.payload||typeof b.payload!=='object'||Array.isArray(b.payload))fail('Cadastro inválido.');
    const unit=String(b.unit||'').trim(),team=String(b.team||'').trim();if(unit.length>150||team.length>150||!await authorized(unit,team))throw new RequestError('Unidade/equipe fora do seu acesso.',403);
    const old=await checked(scoped.from('ppl_management_entries').select('id,version').eq('company_id',selected.id).eq('id',b.id).maybeSingle());
    if(old&&old.version!==b.version)throw new RequestError('Este cadastro foi atualizado por outra pessoa. Atualize a aba antes de editar.',409);
    const p=b.payload,v:any={title:text(p.title,250)};
    if(b.kind==='training'){
     Object.assign(v,{date:day(p.date),type:text(p.type,160),instructor:text(p.instructor,160),status:p.status,hours:Number(p.hours),validUntil:day(p.validUntil,true)});
     if(!['Planejado','Realizado'].includes(v.status)||!Number.isFinite(v.hours)||v.hours<=0||v.hours>1000)fail('Situação ou carga horária inválida.');
     if(v.validUntil&&v.validUntil<v.date)fail('Validade anterior ao treinamento.');
     const today=new Date().toLocaleDateString('en-CA',{timeZone:'America/Fortaleza'});if(v.status==='Realizado'&&v.date>today)fail('Treinamento futuro deve ser planejado.');
     const ids=p.participantIds;if(!Array.isArray(ids)||!ids.length||ids.length>5000||ids.some((id:any)=>!uuid(id))||new Set(ids).size!==ids.length)fail('Selecione os participantes.');
     const employees=[];for(let start=0;start<ids.length;start+=100){employees.push(...await checked(admin.from('ppl_employees').select('id,name,employee_number,job_title').eq('company_id',selected.id).eq('active',true).in('id',ids.slice(start,start+100))));}
     if(employees.length!==ids.length)fail('Participante fora do cadastro ativo da empresa.');v.participants=employees.sort((a:any,b:any)=>a.name.localeCompare(b.name,'pt-BR'));
    }else if(b.kind==='legal-action'){
     if(!programs.includes(p.program)||!['Pendente','Realizado'].includes(p.status))fail('Programa ou situação inválidos.');
     Object.assign(v,{program:p.program,date:day(p.date),status:p.status,responsible:text(p.responsible,160),notes:String(p.notes||'').slice(0,10000),completedDate:p.status==='Realizado'?day(p.completedDate):''});
     if(v.completedDate&&v.completedDate>new Date().toLocaleDateString('en-CA',{timeZone:'America/Fortaleza'}))fail('Conclusão não pode estar no futuro.');
    }else if(b.kind==='legal-document'){
     if(!programs.includes(p.program))fail('Programa inválido.');Object.assign(v,{program:p.program,date:day(p.date),validUntil:day(p.validUntil,true),notes:String(p.notes||'').slice(0,10000)});
     if(v.validUntil&&v.validUntil<v.date)fail('Revisão prevista anterior à emissão.');
    }else{
     if(!/^NR-\d{1,2}$/.test(p.number)||!['Aplicável','Não aplicável','Em avaliação'].includes(p.applicability))fail('NR ou aplicabilidade inválida.');
     Object.assign(v,{number:p.number,applicability:p.applicability,date:day(p.date,true),notes:String(p.notes||'').slice(0,10000)});
    }
    const data={company_id:selected.id,kind:b.kind,unit,team,payload:v,updated_by:profile.user_id,updated_at:new Date().toISOString(),version:old?old.version+1:1};
    const saved=old?await checked(admin.from('ppl_management_entries').update(data).eq('id',b.id).eq('company_id',selected.id).eq('version',old.version).select('id,version').maybeSingle()):await checked(admin.from('ppl_management_entries').insert({...data,id:b.id,created_by:profile.user_id}).select('id,version').single());
    if(!saved)throw new RequestError('Cadastro alterado em outra sessão. Atualize antes de editar.',409);return respond({ok:true,...saved});
   }
   if(!uuid(b.entryId))fail('Registro inválido.');
   const entry=await checked(scoped.from('ppl_management_entries').select('id').eq('company_id',selected.id).eq('id',b.entryId).maybeSingle());if(!entry)throw new RequestError('Registro fora do seu acesso.',403);
   if(b.action==='management-file-get'){
    if(!uuid(b.fileId))fail('Arquivo inválido.');const file=await checked(scoped.from('ppl_management_files').select('*').eq('id',b.fileId).eq('entry_id',entry.id).eq('company_id',selected.id).maybeSingle());if(!file)throw new RequestError('Arquivo não encontrado.',404);
    const data=await checked(admin.storage.from('prs-management').download(file.path));return new Response(data,{headers:{...headers,'Content-Type':file.mime,'Content-Disposition':"attachment; filename*=UTF-8''"+encodeURIComponent(file.name),'X-Content-Type-Options':'nosniff'}});
   }
   const mimeTypes={'pdf':'application/pdf','png':'image/png','jpg':'image/jpeg','jpeg':'image/jpeg','webp':'image/webp','xlsx':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','xls':'application/vnd.ms-excel','docx':'application/vnd.openxmlformats-officedocument.wordprocessingml.document','doc':'application/msword'};
   const name=text(b.name,200),ext=name.split('.').pop()?.toLowerCase(),mime=mimeTypes[ext];
   if(!mime||typeof b.base64!=='string'||b.base64.length>11184812||!/^[A-Za-z0-9+/]+={0,2}$/.test(b.base64))fail('Escolha PDF, foto, Excel ou Word de até 8 MB.');
   let raw;try{raw=Uint8Array.from(atob(b.base64),c=>c.charCodeAt(0));}catch{fail('Arquivo inválido.');}if(!raw?.length||raw.length>8388608)fail('Arquivo excede 8 MB.');
   const id=crypto.randomUUID(),path=selected.id+'/'+entry.id+'/'+id+'.'+ext;
   await checked(admin.storage.from('prs-management').upload(path,raw,{contentType:mime,upsert:false}));
   try{await checked(admin.from('ppl_management_files').insert({id,entry_id:entry.id,company_id:selected.id,path,name,mime,size:raw.length,created_by:profile.user_id}));}catch(error){await admin.storage.from('prs-management').remove([path]);throw error;}
   return respond({ok:true,id});
  }
