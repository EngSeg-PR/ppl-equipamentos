/* API59 isolated validation. No requests to Supabase or production data. */
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {stripTypeScriptTypes}=require('node:module');
const root=path.resolve(__dirname,'..'),cid='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222',uid='44444444-4444-4444-8444-444444444444';
let role='owner',active=true,handler,checks=0,rpcConflict=false;
const tables={ppl_companies:[{id:cid,slug:'ppl',name:'EMPRESA FICTÍCIA',status:'ready',brand_version:1},{id:other,slug:'other',name:'OUTRA EMPRESA',status:'ready'}],ppl_company_models:[],ppl_checklist_revisions:[],ppl_inspections:[{key:'EVIDENCIA-HISTORICA',payload:{immutable:true},pdf_path:'historical.pdf'}]},blobs=new Map();
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
class Query{
 constructor(table){this.table=table;this.filters=[];this.fields='*';this.orders=[];}
 select(fields='*'){this.fields=fields;return this;}eq(k,v){this.filters.push(r=>r[k]===v);return this;}
 in(k,values){this.filters.push(r=>values.includes(r[k]));return this;}order(k,opts={}){this.orders.push({k,direction:opts.ascending===false?-1:1});return this;}
 range(start,end){this.start=start;this.end=end;return this;}limit(n){this.maximum=n;return this;}
 maybeSingle(){this.one=true;return this;}single(){this.one=true;return this;}
 then(ok,no){try{const base=this.table==='ppl_access'?[{user_id:uid,role,active}]:this.table==='ppl_company_access'?[{user_id:uid,company_id:cid,scope_mode:'company',active:true}]:tables[this.table]||[];
  let rows=base.filter(r=>this.filters.every(f=>f(r))).map(r=>structuredClone(r));
  rows.sort((a,b)=>{for(const s of this.orders){const cmp=a[s.k]<b[s.k]?-1:a[s.k]>b[s.k]?1:0;if(cmp)return cmp*s.direction;}return 0;});
  if(this.maximum!==undefined)rows=rows.slice(0,this.maximum);if(this.start!==undefined)rows=rows.slice(this.start,this.end+1);
  if(this.fields!=='*')rows=rows.map(r=>Object.fromEntries(this.fields.split(',').map(k=>[k,r[k]])));
  return Promise.resolve({data:this.one?rows[0]||null:rows,error:null}).then(ok,no);
 }catch(error){return Promise.reject(error).then(ok,no);}}
}
const state=(rows,ids)=>rows.filter(r=>ids.includes(r.model_id)).map(({model_id,version,active})=>({model_id,version,active})).sort((a,b)=>a.model_id<b.model_id?-1:a.model_id>b.model_id?1:a.version<b.version?-1:a.version>b.version?1:0);
const rpc=async(name,args)=>{
 if(name!=='ppl_publish_checklist_revision_v59')return {data:true,error:null};
 const r=args.p_revision,models=args.p_models,prior=tables.ppl_checklist_revisions.find(x=>x.company_id===r.company_id&&x.source_hash===r.source_hash),latest=tables.ppl_checklist_revisions.at(-1);
 if(prior)return prior.request_hash===r.request_hash?{data:{id:prior.id,revision:prior.revision,modelCount:prior.model_count,idempotent:true},error:null}:{error:{message:'revision_file_conflict'}};
 if(rpcConflict||!same(latest?.id||null,args.p_expected_revision)||!same(state(tables.ppl_company_models,models.map(m=>m.snapshot.id)),args.p_expected_custom))return {error:{message:'revision_models_conflict'}};
 if(tables.ppl_checklist_revisions.some(x=>x.company_id===r.company_id&&x.revision===r.revision))return {error:{message:'revision_label_conflict'}};
 const before=structuredClone(tables.ppl_company_models);
 try{for(const old of tables.ppl_company_models)if(models.some(m=>m.snapshot.id===old.model_id))old.active=false;
  for(const m of models)tables.ppl_company_models.push({company_id:r.company_id,model_id:m.snapshot.id,version:m.snapshot.version,snapshot:structuredClone(m.snapshot),kind:m.kind,active:m.active,created_at:'2026-11-04T12:00:00Z'});
  tables.ppl_checklist_revisions.push({...structuredClone(r),models:structuredClone(models),sequence:tables.ppl_checklist_revisions.length+1,created_at:'2026-11-04T12:00:00Z'});
 }catch(e){tables.ppl_company_models=before;throw e;}
 return {data:{id:r.id,revision:r.revision,modelCount:models.length,idempotent:false},error:null};
};
const createClient=()=>({
 from:t=>new Query(t),rpc,
 auth:{getUser:async token=>({data:{user:token==='VALID'?{id:uid}:null},error:null})},
 storage:{from:()=>({
  upload:async(p,b)=>{if(blobs.has(p))return {error:{message:'already exists',statusCode:'409'}};blobs.set(p,new Uint8Array(b));return {error:null};},
  download:async p=>({data:blobs.has(p)?new Blob([blobs.get(p)]):null,error:blobs.has(p)?null:{message:'missing'}})
 })}
});
const source=fs.readFileSync(path.join(root,'supabase/checklists-v59/ppl-api-dashboard.ts'),'utf8'),source58=fs.readFileSync(path.join(root,'supabase/documentos-v58/ppl-api-dashboard.ts'),'utf8');
const context={createClient,Deno:{env:{get:()=>''},serve:fn=>handler=fn},Response,Request,TextEncoder,TextDecoder,Uint8Array,Date,crypto,atob,console,structuredClone,Map,Set};
vm.createContext(context);vm.runInContext(stripTypeScriptTypes(source.replace("import {createClient} from 'npm:@supabase/supabase-js@2';",''),{mode:'transform'}),context);
const call=(action,body={},token='VALID')=>handler(new Request('https://test.invalid',{method:'POST',headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{})},body:JSON.stringify({action,companyId:cid,...body})}));
const json=async response=>({status:response.status,data:await response.json(),headers:response.headers});
const expect=(actual,expected,note)=>{const plain=value=>value&&typeof value==='object'?JSON.parse(JSON.stringify(value)):value;assert.deepEqual(plain(actual),plain(expected),note);checks++;};
const old=JSON.parse(source58.match(/^const builtinModels=(\[.*\]);$/m)[1]),seed=JSON.parse(fs.readFileSync(path.join(root,'ppl-checklist-models-v59.json')));
const photo=()=>({name:'FOTO FICTÍCIA',data:'data:image/jpeg;base64,AAAA',createdAt:'2026-10-01T12:00:00Z',captureMethod:'camera'});
function record(model){return {id:crypto.randomUUID(),revision:1,key:'',model:structuredClone(model),fields:{type:model.types[0],date:'2026-10-01',belt:'TAG-TESTE',inspector:'FICTÍCIO',employee:'QA',notes:'',reason:''},status:'recorded',signature:{kind:'drawn-electronic',data:'data:image/png;base64,AAAA',createdAt:'2026-10-01T12:00:00Z'},workerPhoto:photo(),equipmentPhotos:[],answers:model.items.map(i=>({itemId:i.id,value:'Conforme',notes:'',photos:[],actionCode:''})),recordedAt:'2026-10-01T12:00:00Z'};}
const normalize=(r,models=seed)=>{r.key=r.id+':1';context.testRecord=r;context.testModels=models;return vm.runInContext('normalizeRecord(testRecord,testModels)',context);};
const excel=(marker=1)=>{const raw=Buffer.from([208,207,17,224,161,177,26,225,marker]);return {filename:'REVISAO-FICTICIA.xls',sha256:crypto.createHash('SHA-256').update(raw).digest('hex'),base64:raw.toString('base64'),mime:'application/vnd.ms-excel'};};
function payload(rows=seed,marker=1,revision='Rev.06',head=null){return {expectedRevisionId:head,revision,source:excel(marker),models:rows.filter(m=>m.source?.sheet).map(m=>({baseModelId:m.id,expectedVersion:m.version,sourceSheet:m.source.sheet,formCode:m.reportLayout.formCode,legend:m.reportLayout.legend,guidance:m.reportLayout.guidance,items:m.items.map((i,n)=>({sourceNumber:i.sourceNumber,sourceRow:n+12,category:i.category,text:i.text}))}))};}
async function publish(body){return json(await call('ppl-revision-publish',body));}
(async()=>{
 expect(seed.length,46);expect(seed.reduce((n,m)=>n+m.items.length,0),505);expect([...new Set(seed.map(m=>m.reportLayout.revision))],['05'],'All internal PPL models start on the same current revision');
 for(const m of seed){expect(m.items,old.find(x=>x.id===m.id).items,'Initial revision must preserve every technical question');expect(m.types,old.find(x=>x.id===m.id).types);}
 expect(JSON.parse(source.match(/^const builtinModels=(\[.*\]);$/m)[1]),old,'All old PPL/Vale snapshots remain exact');
 expect(source.match(/^const pplDocumentTemplates=(\[.*\]);$/m)[1],source58.match(/^const pplDocumentTemplates=(\[.*\]);$/m)[1],'OS58 and other documents untouched');
 expect(source.includes("ppl_attention_visual_submit_v57"),true);expect(source.includes('CLASSIFICATION57'),source58.includes('CLASSIFICATION57'));
 let list=await json(await call('models'));expect(list.status,200);expect(list.headers.get('X-PPL-API-Version'),'59');expect(list.data.moduleVersion,59);expect(list.data.pplRevision,null);expect(list.data.rows.filter(m=>m.active).length,75);expect(list.data.rows.filter(m=>m.snapshot.id.startsWith('ppl-')).length,92);
 for(const m of seed)expect(list.data.rows.filter(x=>x.active&&x.snapshot.id===m.id).length,1);
 context.directRows=[{snapshot:{...structuredClone(seed[0]),version:'59-first'},kind:'checklist',active:true},{snapshot:{...structuredClone(seed[0]),version:'59-latest'},kind:'checklist',active:true}];
 const directBefore=JSON.stringify(context.directRows),direct=await vm.runInContext("templates({id:'"+cid+"',slug:'ppl'},directRows)",context);expect(direct.filter(m=>m.snapshot.id===seed[0].id&&m.active).map(m=>m.snapshot.version),['59-latest'],'A damaged legacy active flag cannot expose two revisions');expect(JSON.stringify(context.directRows),directBefore,'Template listing never mutates rows used by compare-and-swap');
 const baseline=JSON.stringify(tables.ppl_inspections),r=record(seed[0]);expect(normalize(r).equipmentPhotos.length,0);
 for(const code of ['','1','2','1,2']){const r=record(seed[0]);r.answers[0].actionCode=code;expect(normalize(r).answers[0].actionCode,code);}
 for(const code of ['3','1, 2',null,2]){const r=record(seed[0]);r.answers[0].actionCode=code;assert.throws(()=>normalize(r),/Código/);checks++;}
 let r12=record(seed[0]);r12.equipmentPhotos=Array.from({length:12},photo);expect(normalize(r12).equipmentPhotos.length,12);r12.equipmentPhotos.push(photo());assert.throws(()=>normalize(r12),/12/);checks++;
 for(const invalid of [{...photo(),captureMethod:'library'},{...photo(),data:'invalid'},{...photo(),createdAt:'invalid'}]){const r=record(seed[0]);r.equipmentPhotos=[invalid];assert.throws(()=>normalize(r),/equipamento/);checks++;}
 let bad=record(seed[0]);bad.workerPhoto.captureMethod='library';assert.throws(()=>normalize(bad),/câmera/);checks++;
 bad=record(seed[0]);bad.answers[0].photos=[{...photo(),captureMethod:'library'}];assert.throws(()=>normalize(bad),/câmera/);checks++;
 const historical=record(old[0]);delete historical.equipmentPhotos;expect(normalize(historical,old).model.version,'0.5-piloto');
 bad=record(seed[0]);bad.model.items[0].text='TEXTO ADULTERADO';assert.throws(()=>normalize(bad),/Modelo/);checks++;
 expect((await call('ppl-revision-publish',payload(),'' )).status,401);role='manager';expect((await call('ppl-revision-publish',payload())).status,403);role='owner';active=false;expect((await call('ppl-revision-publish',payload())).status,403);active=true;
 expect((await publish({...payload(),companyId:other})).status,403);
 const tests=[b=>b.source.sha256='0'.repeat(64),b=>b.source.base64='???',b=>b.source.filename='arquivo.docx',b=>b.source.mime='text/plain',b=>b.models[0].baseModelId='vale-excel-02-3',b=>b.models[0].expectedVersion='inexistente',b=>b.models[0].sourceSheet+=' ',b=>b.models[0].items[0].sourceRow=0,b=>b.models[0].items[1].sourceRow=b.models[0].items[0].sourceRow,b=>b.models[0].legend='Legenda incorreta'];
 for(const mutate of tests){const b=payload();mutate(b);assert((await publish(b)).status>=400);checks++;expect(tables.ppl_checklist_revisions.length,0);}
 let b=payload();b.expectedRevisionId=crypto.randomUUID();expect((await publish(b)).status,409);
 rpcConflict=true;expect((await publish(payload())).status,409);rpcConflict=false;expect(tables.ppl_company_models.length,0);expect(tables.ppl_checklist_revisions.length,0);
 b=payload();let saved=await publish(b);expect(saved.status,200,JSON.stringify(saved.data));expect(saved.data.modelCount,46);expect(saved.data.importedModelCount,45);expect(tables.ppl_checklist_revisions.length,1);expect(tables.ppl_company_models.length,46);expect(JSON.stringify(tables.ppl_inspections),baseline);
 const row=tables.ppl_checklist_revisions[0];expect(blobs.has(row.source_path),true);expect(crypto.createHash('SHA-256').update(blobs.get(row.source_path)).digest('hex'),b.source.sha256);
 expect(row.models.find(m=>m.snapshot.id==='ppl-cinturao-talabarte').snapshot.items,seed[0].items,'Omitted legacy questions retained');
 const jato=row.models.find(m=>m.snapshot.id==='ppl-maquina-de-jato').snapshot;expect(new Set(jato.items.map(i=>i.id)).size,jato.items.length,'Repeated printed source numbers retain separate stable IDs');
 expect((await publish(b)).data.idempotent,true);expect(tables.ppl_checklist_revisions.length,1);expect((await publish({...b,revision:'OUTRO RÓTULO'})).status,409);
 list=await json(await call('models'));expect(list.data.pplRevision.id,row.id);expect(list.data.rows.filter(m=>m.active&&m.snapshot.id.startsWith('ppl-')).length,46);expect(list.data.rows.filter(m=>m.active&&m.snapshot.id.startsWith('vale-')).map(m=>m.snapshot),old.filter(m=>m.id.startsWith('vale-')));
 for(const m of seed)expect(list.data.rows.filter(x=>x.active&&x.snapshot.id===m.id).length,1);
 expect(normalize(record(seed[0]),list.data.rows.map(m=>m.snapshot)).model.version,seed[0].version,'Old offline snapshot remains recognized after publication');
 const current=list.data.rows.filter(m=>m.active&&m.snapshot.id.startsWith('ppl-')).map(m=>m.snapshot),second=payload(current,2,'Rev.07',row.id);second.models[0].items[0].text='ALTERAÇÃO FICTÍCIA REVISADA PELO PROPRIETÁRIO';
 const archivedContent=JSON.stringify(tables.ppl_company_models[0].snapshot);saved=await publish(second);expect(saved.status,200,JSON.stringify(saved.data));expect(tables.ppl_company_models.length,92);expect(JSON.stringify(tables.ppl_company_models[0].snapshot),archivedContent);expect(tables.ppl_company_models.slice(0,46).every(m=>m.active===false),true);expect(tables.ppl_company_models.slice(46).every(m=>m.active===true),true);
 expect((await publish(payload(current,3,'Rev.08',row.id))).status,409);expect(tables.ppl_checklist_revisions.length,2);
 // A model intentionally hidden by its owner must not be revived by a layout revision.
 const hidden=tables.ppl_company_models.find(m=>m.active&&m.model_id==='ppl-cinturao-talabarte');hidden.active=false;
 list=await json(await call('models'));const third=payload(list.data.rows.filter(m=>m.active&&m.snapshot.id.startsWith('ppl-')).map(m=>m.snapshot),4,'Rev.08',tables.ppl_checklist_revisions.at(-1).id);saved=await publish(third);expect(saved.status,200,JSON.stringify(saved.data));expect(tables.ppl_company_models.filter(m=>m.model_id==='ppl-cinturao-talabarte'&&m.active).length,0);expect(tables.ppl_checklist_revisions.at(-1).model_count,46);expect(JSON.stringify(tables.ppl_inspections),baseline);
 console.log('PASS '+checks+' isolated API59 checks: snapshots, photos, actions, owner/PPL, atomic revisions, archive, CAS, history, Vale/OS58 preservation.');
})().catch(e=>{console.error(e);process.exitCode=1;});
