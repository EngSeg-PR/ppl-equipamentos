/* PPL daily checklists: immutable snapshots and owner-only revision publication. */
const ppl59LayoutType='ppl-equipment-table';
const ppl59Legend='NAS INSPEÇÕES MARQUE: C- CONFORME NC- NÃO CONFORME N/A- NÃO SE APLICA';
function ppl59RevisionPublic(row:any){return row?{id:row.id,revision:row.revision,modelCount:row.model_count,createdAt:row.created_at,source:{filename:row.source_filename,sha256:row.source_hash}}:null;}
async function ppl59LatestRevision(companyId:string){return await checked(admin.from('ppl_checklist_revisions').select('id,revision,model_count,created_at,source_filename,source_hash').eq('company_id',companyId).order('sequence',{ascending:false}).limit(1).maybeSingle());}
function ppl59CustomState(rows:any[],ids:string[]){const compare=(a:string,b:string)=>a<b?-1:a>b?1:0;return rows.filter((m:any)=>ids.includes(m.model_id)).map((m:any)=>({model_id:m.model_id,version:m.version,active:m.active})).sort((a:any,b:any)=>compare(a.model_id,b.model_id)||compare(a.version,b.version));}
function ppl59Text(value:any,max:number,label:string){if(typeof value!=='string'||!value.trim()||value.length>max)fail(label);return value.trim();}
function ppl59RevisionInput(b:any,approved:any[],revisionId:string){
 const revision=ppl59Text(b.revision,100,'Informe a revisão do arquivo.');
 if(b.expectedRevisionId!==null&&!uuid(b.expectedRevisionId))fail('Atualize a lista de modelos antes de importar a revisão.');
 const source=b.source;if(!source||typeof source!=='object'||Array.isArray(source))fail('Arquivo da revisão ausente.');
 const filename=ppl59Text(source.filename,240,'Nome do arquivo inválido.');
 const extension=/\.xlsx$/i.test(filename)?'xlsx':/\.xls$/i.test(filename)?'xls':'';
 if(!extension||!['application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'].includes(source.mime))fail('Use um arquivo Excel XLS ou XLSX.');
 if(typeof source.sha256!=='string'||!/^[a-f0-9]{64}$/.test(source.sha256)||typeof source.base64!=='string'||source.base64.length>19573420||!source.base64.length||source.base64.length%4!==0||!/^[A-Za-z0-9+/]*={0,2}$/.test(source.base64))fail('Arquivo da revisão inválido ou maior que 14 MB.');
 const bytes=Uint8Array.from(atob(source.base64),(x:string)=>x.charCodeAt(0));
 if(!bytes.length||bytes.length>14680064)fail('Arquivo da revisão maior que 14 MB.');
 const magic=extension==='xls'?[208,207,17,224,161,177,26,225]:[80,75];
 if(magic.some((v:number,n:number)=>bytes[n]!==v))fail('O conteúdo do arquivo não corresponde a um Excel válido.');
 if(!Array.isArray(b.models)||!b.models.length||b.models.length>46)fail('Informe os modelos reconhecidos da revisão.');
 const ids=new Set(),sheets=new Set(),models:any[]=[];
 for(const input of b.models){
  if(!input||typeof input!=='object'||Array.isArray(input))fail('Modelo da revisão inválido.');
  const id=ppl59Text(input.baseModelId,200,'Identificador do modelo inválido.');
  const base=approved.find((x:any)=>x.kind==='checklist'&&x.snapshot.id===id&&x.snapshot.version===input.expectedVersion)?.snapshot;
  if(!id.startsWith('ppl-')||!base||base.reportLayout?.issuer==='VALE'||!ppl59BuiltinIds.has(id))throw new RequestError('Um modelo mudou, foi excluído ou não pertence aos checklists internos PPL. Atualize a lista antes de importar.',409);
  if(ids.has(id))fail('Modelo repetido na revisão.');ids.add(id);
  if(typeof input.sourceSheet!=='string'||!input.sourceSheet.trim()||input.sourceSheet.length>100||sheets.has(input.sourceSheet)||input.sourceSheet!==base.source?.sheet)fail('A folha não corresponde ao modelo cadastrado. Preserve o nome completo da folha, inclusive espaços.');sheets.add(input.sourceSheet);
  const formCode=ppl59Text(input.formCode,250,'Código do formulário ausente.');
  const legend=ppl59Text(input.legend,1000,'Legenda do formulário ausente.');
  if(!/CONFORME/i.test(legend)||!/N[AÃ]O\s+CONFORME/i.test(legend)||!/APLICA/i.test(legend))fail('A legenda deve preservar Conforme, Não Conforme e Não se aplica.');
  if(!Array.isArray(input.guidance)||!input.guidance.length||input.guidance.length>20)fail('Orientações do formulário ausentes.');
  const guidance=input.guidance.map((x:any)=>ppl59Text(x,10000,'Orientação do formulário inválida.'));
  if(!Array.isArray(input.items)||!input.items.length||input.items.length>250)fail('Quantidade de itens do modelo inválida.');
  const rows=new Set(),previousItems=new Map();for(const item of base.items){const number=String(item.sourceNumber??'');if(!previousItems.has(number))previousItems.set(number,[]);previousItems.get(number).push(item);}
  const items=input.items.map((item:any,n:number)=>{
   if(!item||typeof item!=='object'||Array.isArray(item))fail('Item do checklist inválido.');
   const sourceNumber=ppl59Text(String(item.sourceNumber??''),30,'Número original do item inválido.');
   if(!/^\d+(?:\.\d+)*$/.test(sourceNumber))fail('Número original ausente no modelo.');
   if(!Number.isInteger(item.sourceRow)||item.sourceRow<1||item.sourceRow>65536||rows.has(item.sourceRow))fail('Linha original do item inválida ou repetida.');rows.add(item.sourceRow);
   const old=previousItems.get(sourceNumber)?.shift();
   return {id:old?.id||id+'-revision-'+(n+1),category:typeof item.category==='string'&&item.category.trim()?ppl59Text(item.category,160,'Categoria inválida.'):'Verificação do equipamento',text:ppl59Text(item.text,4000,'Texto do item ausente ou muito longo.'),sourceNumber,sourceRow:item.sourceRow};
  });
  const snapshot={...structuredClone(base),version:'59-'+revisionId,items,source:{...base.source,form:formCode,sheet:input.sourceSheet,guidance,revisionSource:{filename,sha256:source.sha256,revision}},reportLayout:{type:ppl59LayoutType,issuer:'PPL',version:59,formCode,revision,equipmentName:base.equipmentName||base.title,legend,guidance,dayColumns:31,source:{filename,sha256:source.sha256,sheet:input.sourceSheet}}};
  models.push({snapshot,kind:'checklist',active:true});
 }
 return {revision,source:{filename,sha256:source.sha256,mime:extension==='xls'?'application/vnd.ms-excel':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',extension,bytes},models};
}
async function ppl59Publish(b:any,selected:any,profile:any){
 if(profile?.role!=='owner'||profile.active!==true)throw new RequestError('Operação exclusiva do proprietário.',403);
 if(selected.slug!=='ppl')throw new RequestError('A revisão é exclusiva dos checklists internos PPL.',403);
 const custom=await checked(admin.from('ppl_company_models').select('model_id,version,snapshot,kind,active').eq('company_id',selected.id).order('created_at'));
 const approved=await templates(selected,custom),revisionId=crypto.randomUUID(),input=ppl59RevisionInput(b,approved,revisionId);
 if(await hash(input.source.bytes)!==input.source.sha256)fail('A integridade do Excel não foi confirmada. Selecione o arquivo novamente.');
 const requestHash=await hash(new TextEncoder().encode(canonical({revision:input.revision,sourceHash:input.source.sha256,models:b.models.map((m:any)=>({id:m.baseModelId,sheet:m.sourceSheet,formCode:m.formCode,legend:m.legend,guidance:m.guidance,items:m.items}))})));
 const previous=await checked(admin.from('ppl_checklist_revisions').select('id,revision,request_hash,model_count,source_hash').eq('company_id',selected.id).eq('source_hash',input.source.sha256).maybeSingle());
 if(previous){if(previous.request_hash!==requestHash)throw new RequestError('Este arquivo já foi publicado com outros dados. Preserve a revisão existente e use um novo arquivo para alterar o modelo.',409);return {ok:true,revisionId:previous.id,revision:previous.revision,modelCount:previous.model_count,importedModelCount:b.models.length,moduleVersion:59,idempotent:true};}
 if(b.models.some((m:any)=>!approved.some((x:any)=>x.active&&x.kind==='checklist'&&x.snapshot.id===m.baseModelId&&x.snapshot.version===m.expectedVersion)))throw new RequestError('Um modelo mudou ou foi excluído. Atualize a lista antes de publicar a revisão.',409);
 const latest=await ppl59LatestRevision(selected.id);
 if((latest?.id||null)!==b.expectedRevisionId)throw new RequestError('A revisão foi alterada em outra tela. Atualize a lista antes de publicar.',409);
 // Omitted models keep their technical content while moving to the same current layout/revision.
 for(const id of ppl59BuiltinIds){if(input.models.some((m:any)=>m.snapshot.id===id))continue;const candidates=approved.filter((m:any)=>m.kind==='checklist'&&m.snapshot.id===id),old=candidates.find((m:any)=>m.active)||candidates.filter((m:any)=>m.snapshot.reportLayout?.type===ppl59LayoutType).at(-1)||candidates.at(-1);if(!old)fail('Modelo interno ausente do catálogo.');const prior=old.snapshot,layout=prior.reportLayout||ppl59BuiltinModels.find((m:any)=>m.id===id).reportLayout;input.models.push({kind:'checklist',active:old.active===true,snapshot:{...structuredClone(prior),version:'59-'+revisionId,reportLayout:{...structuredClone(layout),revision:input.revision,source:{filename:input.source.filename,sha256:input.source.sha256,sheet:prior.source?.sheet||null}},...(prior.source?{source:{...prior.source,revisionSource:{filename:input.source.filename,sha256:input.source.sha256,revision:input.revision,contentPreserved:true}}}:{})}});}
 const ids=input.models.map((m:any)=>m.snapshot.id),expectedState=ppl59CustomState(custom,ids);
 const sourcePath=selected.id+'/checklist-revisions/'+input.source.sha256+'/source.'+input.source.extension;
 const upload=await admin.storage.from('ppl-private').upload(sourcePath,input.source.bytes,{contentType:input.source.mime,upsert:false});
 if(upload.error){const duplicate=['409','Duplicate'].includes(String(upload.error.statusCode))||/already exists|duplicate/i.test(String(upload.error.message));if(!duplicate)throw new RequestError('Não foi possível arquivar o Excel. Nenhum modelo foi atualizado.',503);const stored=await admin.storage.from('ppl-private').download(sourcePath);if(stored.error||!stored.data||await hash(new Uint8Array(await stored.data.arrayBuffer()))!==input.source.sha256)throw new RequestError('O arquivo arquivado não passou pela verificação de integridade. Nenhum modelo foi atualizado.',503);}
 const row={id:revisionId,company_id:selected.id,revision:input.revision,source_filename:input.source.filename,source_hash:input.source.sha256,source_mime:input.source.mime,source_path:sourcePath,source_size:input.source.bytes.length,request_hash:requestHash,model_count:input.models.length};
 const saved=await admin.rpc('ppl_publish_checklist_revision_v59',{p_revision:row,p_models:input.models,p_expected_revision:b.expectedRevisionId,p_expected_custom:expectedState,p_actor:profile.user_id});
 if(saved.error){const detail=String(saved.error.message||'');if(/revision_conflict|revision_file_conflict|revision_label_conflict|revision_models_conflict/.test(detail))throw new RequestError('A revisão ou os modelos mudaram. Atualize a lista antes de importar novamente; os registros anteriores foram preservados.',409);if(/revision_owner_required/.test(detail))throw new RequestError('Operação exclusiva do proprietário.',403);throw new RequestError('A revisão não foi confirmada. Os modelos anteriores foram preservados; atualize a lista antes de tentar novamente.',503);}
 return {ok:true,revisionId:saved.data.id,revision:saved.data.revision,modelCount:saved.data.modelCount,importedModelCount:b.models.length,moduleVersion:59,idempotent:saved.data.idempotent===true};
}
