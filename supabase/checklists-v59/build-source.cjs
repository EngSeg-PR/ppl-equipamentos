/* Rebuild the complete API59 from the untouched OS58 source and canonical PPL catalog. */
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const base=fs.readFileSync(path.join(root,'supabase/documentos-v58/ppl-api-dashboard.ts'),'utf8');
const models=JSON.parse(fs.readFileSync(path.join(root,'ppl-checklist-models-v59.json'),'utf8'));
const fragment=fs.readFileSync(path.join(__dirname,'revision.fragment.ts'),'utf8');
let source=base;
const replace=(old,next)=>{if(!source.includes(old))throw Error('Source58 marker missing: '+old.slice(0,100));source=source.replace(old,next);};
replace("'X-PPL-API-Version':'58'","'X-PPL-API-Version':'59'");
replace('async function templates(c:any){',`const ppl59BuiltinModels=${JSON.stringify(models)};
const ppl59BuiltinIds=new Set(ppl59BuiltinModels.map((m:any)=>m.id));
${fragment}
async function templates58Unused(c:any){`);
const oldTemplates=source.match(/^async function templates58Unused\(c:any\)\{.*\}$/m);
if(!oldTemplates)throw Error('Source58 templates function marker missing');
replace(oldTemplates[0],`async function templates(c:any,customRows?:any[]){
 const custom=customRows||await checked(admin.from('ppl_company_models').select('snapshot,kind,active').eq('company_id',c.id).order('created_at'));
 const base=builtinModels.filter((m:any)=>m.reportLayout?.issuer==='VALE'||c.slug==='ppl').map((m:any)=>({snapshot:m,kind:'checklist',active:!ppl59BuiltinIds.has(m.id)}));
 if(c.slug==='ppl')base.push(...ppl59BuiltinModels.map((m:any)=>({snapshot:m,kind:'checklist',active:true})));
 const merged=new Map(base.map((m:any)=>[m.snapshot.id+'@'+m.snapshot.version,m]));
 for(const m of custom)merged.set(m.snapshot.id+'@'+m.snapshot.version,{...m});
 if(c.slug==='ppl')for(const id of ppl59BuiltinIds){
  const own=custom.filter((m:any)=>m.snapshot.id===id),revisions=own.filter((m:any)=>m.snapshot.reportLayout?.type===ppl59LayoutType);
  const historicalDeletion=own.length>0&&own.every((m:any)=>!m.active),latest=ppl59BuiltinModels.find((m:any)=>m.id===id),currentRevision=revisions.filter((m:any)=>m.active).at(-1);
  for(const row of merged.values())if(row.snapshot.id===id){
   row.active=revisions.length?currentRevision?.snapshot.version===row.snapshot.version:!historicalDeletion&&row.snapshot.version===latest.version;
  }
 }
 return [...merged.values()];
}`);
replace(" const image=value=>",` const ppl59Record=model.reportLayout?.type==='ppl-equipment-table';
 if(r.equipmentPhotos!==undefined&&!ppl59Record)fail('Fotografias gerais não pertencem a este modelo.');
 const image=value=>`);
replace(" if(!Array.isArray(r.answers)||r.answers.length!==model.items.length)fail('Itens incompletos.');",` if(ppl59Record){
  if(r.workerPhoto.captureMethod!=='camera')fail('Use a câmera para identificar o responsável.');
  if(r.equipmentPhotos===undefined)r.equipmentPhotos=[];
  if(!Array.isArray(r.equipmentPhotos)||r.equipmentPhotos.length>12||r.equipmentPhotos.some((p:any)=>!photo(p)||p.captureMethod!=='camera'))fail('Fotografe o equipamento com a câmera. Limite de 12 fotos.');
 }
 if(!Array.isArray(r.answers)||r.answers.length!==model.items.length)fail('Itens incompletos.');`);
replace("  if(a.photos.length>3)fail('Limite de três fotos por item.');",`  if(ppl59Record){if(a.actionCode===undefined)a.actionCode='';if(typeof a.actionCode!=='string'||!['','1','2','1,2'].includes(a.actionCode))fail('Código de ação inválido.');if(a.photos.some((p:any)=>p.captureMethod!=='camera'))fail('Capture as evidências pela câmera.');}
  if(a.photos.length>3)fail('Limite de três fotos por item.');`);
replace("r.answers?.forEach((a:any)=>a.photos=[]);const {pdf_hash,...visible}=row;","r.answers?.forEach((a:any)=>a.photos=[]);if(r.equipmentPhotos)r.equipmentPhotos=[];const {pdf_hash,...visible}=row;");
replace('models,employees,executorAccessRequired,moduleVersion:54','models,employees,executorAccessRequired,pplRevision:c.slug===\'ppl\'?ppl59RevisionPublic(await ppl59LatestRevision(c.id)):null,moduleVersion:59');
replace("if(b.action==='models')return respond({rows:await templates(selected)});",`if(b.action==='models')return respond({rows:await templates(selected),pplRevision:selected.slug==='ppl'?ppl59RevisionPublic(await ppl59LatestRevision(selected.id)):null,moduleVersion:59});
  if(b.action==='ppl-revision-publish')return respond(await ppl59Publish(b,selected,profile));`);
replace("if(!model)throw new RequestError('Modelo não encontrado nesta empresa.',404);await checked(admin.from('ppl_company_models').upsert(",`if(!model)throw new RequestError('Modelo não encontrado nesta empresa.',404);if(selected.slug==='ppl'&&ppl59BuiltinIds.has(modelId)){if(!model.active)throw new RequestError('O modelo mudou ou já foi retirado. Atualize a lista.',409);const hidden=await admin.rpc('ppl_hide_checklist_model_v59',{p_company:selected.id,p_snapshot:model.snapshot,p_actor:profile.user_id});if(hidden.error){if(/revision_models_conflict/.test(String(hidden.error.message||'')))throw new RequestError('A revisão mudou. Atualize a lista antes de excluir o modelo.',409);throw new RequestError('Não foi possível confirmar a retirada do modelo.',503);}return respond({ok:true});}await checked(admin.from('ppl_company_models').upsert(`);
fs.writeFileSync(path.join(__dirname,'ppl-api-dashboard.ts'),source);
console.log('API59 rebuilt; source58 and all Vale snapshots preserved.');
