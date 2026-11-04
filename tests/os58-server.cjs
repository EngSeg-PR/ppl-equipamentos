/* OS58 handler validation in an isolated service mock. No production network or records. */
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {stripTypeScriptTypes}=require('node:module');
const root=path.resolve(__dirname,'..'),cid='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222',eid='33333333-3333-4333-8333-333333333333',uid='44444444-4444-4444-8444-444444444444';
let role='owner',active=true,handler,checks=0;
const tables={ppl_companies:[{id:cid,slug:'ppl',name:'EMPRESA FICTÍCIA',status:'ready',brand_version:1,profile:{}},{id:other,slug:'other',name:'OUTRA EMPRESA',status:'ready'}],ppl_employees:[{id:eid,company_id:cid,name:'COLABORADOR FICTÍCIO',employee_number:'QA-OS-58',job_title:'FUNÇÃO FICTÍCIA',job_description:'Descrição de teste',active:true}],ppl_management_entries:[],ppl_management_files:[],ppl_management_audit:[]},blobs=new Map();
const scopeOk=(c,u,t)=>c===cid&&u==='PORTO'&&t==='PINTURA';
class Query{
 constructor(table,scoped){this.table=table;this.scoped=scoped;this.filters=[];this.fields='*';}
 select(fields='*'){this.fields=fields;return this;}
 eq(k,v){this.filters.push(r=>r[k]===v);return this;}
 in(k,ids){this.filters.push(r=>ids.includes(r[k]));return this;}
 gt(k,v){this.filters.push(r=>r[k]>v);return this;}
 order(k,options={}){this.sort={k,direction:options.ascending===false?-1:1};return this;}
 range(start,end){this.start=start;this.end=end;return this;}
 limit(n){this.maximum=n;return this;}
 maybeSingle(){this.one=true;return this;}single(){this.one=true;return this;}
 insert(row){this.insertion=row;return this;}update(row){this.change=row;return this;}
 then(ok,no){try{
  let base=this.table==='ppl_access'?[{user_id:uid,name:'GESTOR DE TESTE',role,active}]:this.table==='ppl_company_access'?[{user_id:uid,company_id:cid,scope_mode:'teams',active:true}]:this.table==='ppl_scopes'?[{user_id:uid,company_id:cid,unit:'PORTO',team:'PINTURA'}]:tables[this.table]||[];
  let rows=base.filter(r=>this.filters.every(f=>f(r)));
  if(this.scoped&&this.table==='ppl_management_entries')rows=rows.filter(r=>role==='owner'||scopeOk(r.company_id,r.unit,r.team));
  if(this.scoped&&this.table==='ppl_management_files')rows=rows.filter(r=>role==='owner'||tables.ppl_management_entries.some(e=>e.id===r.entry_id&&scopeOk(e.company_id,e.unit,e.team)));
  if(this.insertion){const row={id:crypto.randomUUID(),created_at:'2026-11-03T12:00:00Z',...structuredClone(this.insertion)};base.push(row);rows=[row];}
  if(this.change)rows.forEach(r=>Object.assign(r,structuredClone(this.change)));
  if(this.sort)rows=[...rows].sort((a,b)=>String(a[this.sort.k]).localeCompare(String(b[this.sort.k]))*this.sort.direction);
  if(this.start!==undefined)rows=rows.slice(this.start,this.end+1);
  if(this.maximum!==undefined)rows=rows.slice(0,this.maximum);
  if(this.fields!=='*')rows=rows.map(r=>Object.fromEntries(this.fields.split(',').map(k=>[k,r[k]])));
  return Promise.resolve({data:this.one?rows[0]||null:rows,error:null}).then(ok,no);
 }catch(error){return Promise.reject(error).then(ok,no);}}
}
const createClient=(url,key,options={})=>({from:table=>new Query(table,!!options.global),rpc:async(name,args)=>({data:role==='owner'||scopeOk(args.c,args.u,args.t),error:null}),auth:{getUser:async token=>({data:{user:token==='VALID'?{id:uid}:null},error:null})},storage:{from:()=>({upload:async(p,raw)=>{if(blobs.has(p))return {error:{message:'exists'}};blobs.set(p,new Uint8Array(raw));return {error:null};},download:async p=>({data:new Blob([blobs.get(p)]),error:null}),remove:async names=>{names.forEach(n=>blobs.delete(n));return {error:null};}})}});
const sourcePath=path.join(root,'supabase/documentos-v58/ppl-api-dashboard.ts'),source=fs.readFileSync(sourcePath,'utf8');
const context={createClient,Deno:{env:{get:()=>''},serve:fn=>{handler=fn;}},Response,Request,TextDecoder,Uint8Array,Date,crypto,atob,console,structuredClone,Map,Set};
vm.createContext(context);vm.runInContext(stripTypeScriptTypes(source.replace("import {createClient} from 'npm:@supabase/supabase-js@2';",''),{mode:'transform'}),context);
const call=(action,body={},token='VALID')=>handler(new Request('https://test.invalid',{method:'POST',headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{})},body:JSON.stringify({action,companyId:cid,...body})}));
const expect=(value,expected,note)=>{assert.deepEqual(value,expected,note);checks++;};
const catalog=JSON.parse(fs.readFileSync(path.join(root,'ppl-documents-catalog.json'),'utf8'));
const signed='data:image/png;base64,iVBORw0KGgo=';
function document(templateId='certificates-4-v3',changes={}){
 const template=catalog.find(t=>t.id===templateId),values={unit:'PORTO',cnpj:'',job_title:'FORGED',name:'FORGED',employee_number:'FORGED',nameReceipt:'FORGED',description:'Descrição de atividade de teste, integral.',date:'2026-11-03',signatureMode:'Em papel',workerSignature:'',...changes};
 return {id:crypto.randomUUID(),kind:'document',unit:'PORTO',team:'PINTURA',payload:{title:'ORDEM DE SERVIÇO — TESTE',category:'Documento de campo',code:templateId,revision:String(template.version||1),date:'2026-11-03',responsible:'Gestor de teste',documentData:{templateId,version:template.version||1,employeeId:eid,values}}};
}
async function save(doc){const response=await call('management-save',doc);const data=await response.json();return {response,data};}
(async()=>{
 const legacy=catalog.find(t=>t.id==='certificates-4'),v2=catalog.find(t=>t.id==='certificates-4-v2'),v3=catalog.find(t=>t.id==='certificates-4-v3');
 expect(v3.version,3);expect(v3.renderVersion,58);expect(v3.fields.find(f=>f.name==='workerSignature').required,false);expect(v2.retired,true);expect(v2.fields.find(f=>f.name==='workerSignature').required,true);expect(legacy.fields.find(f=>f.name==='workerSignature').required,true);
 expect((await call('management-list',{},'')).status,401);expect((await call('management-list',{},'INVALID')).status,401);expect((await (await call('management-list')).json()).moduleVersion,58);
 let paper=document(),result=await save(paper);expect(result.response.status,200,JSON.stringify(result.data));expect(result.response.headers.get('X-PPL-API-Version'),'58');
 let stored=tables.ppl_management_entries.find(r=>r.id===paper.id),snapshot=structuredClone(stored.payload.documentData);
 expect(snapshot.values.signatureMode,'Em papel');expect(snapshot.values.workerSignature,'');expect(snapshot.values.name,'COLABORADOR FICTÍCIO');expect(snapshot.values.employee_number,'QA-OS-58');expect(snapshot.values.job_title,'FUNÇÃO FICTÍCIA');expect(snapshot.employee.id,eid);
 let r=await save(document('certificates-4-v3',{signatureMode:'No sistema',workerSignature:''}));expect(r.response.status,400);assert(r.data.error.includes('Assine'));checks++;
 r=await save(document('certificates-4-v3',{signatureMode:'Em papel',workerSignature:signed}));expect(r.response.status,400);assert(r.data.error.includes('Remova'));checks++;
 r=await save(document('certificates-4-v3',{signatureMode:'Outro'}));expect(r.response.status,400);
 r=await save(document('certificates-4-v3',{signatureMode:''}));expect(r.response.status,400);
 r=await save(document('certificates-4-v3',{signatureMode:'No sistema',workerSignature:'invalid'}));expect(r.response.status,400);
 r=await save(document('certificates-4-v3',{description:''}));expect(r.response.status,400);
 const digital=document('certificates-4-v3',{signatureMode:'No sistema',workerSignature:signed});r=await save(digital);expect(r.response.status,200,JSON.stringify(r.data));expect(tables.ppl_management_entries.find(x=>x.id===digital.id).payload.documentData.values.workerSignature,signed);
 expect((await save(document('certificates-4-v2',{workerSignature:signed}))).response.status,400,'Retired v2 must not issue new documents');
 // Historical v2 remains readable, its signature is not weakened during an explicit edit.
 const oldDoc=document('certificates-4-v2',{workerSignature:signed});const oldSnapshot={templateId:v2.id,version:2,employee:structuredClone(tables.ppl_employees[0]),values:{...oldDoc.payload.documentData.values,name:'COLABORADOR FICTÍCIO',nameReceipt:'COLABORADOR FICTÍCIO',job_title:'FUNÇÃO FICTÍCIA',employee_number:'QA-OS-58'}};
 tables.ppl_management_entries.push({id:oldDoc.id,company_id:cid,kind:'document',unit:'PORTO',team:'PINTURA',version:1,payload:{...structuredClone(oldDoc.payload),documentData:oldSnapshot}});
 let list=await (await call('management-list')).json();expect(list.rows.find(x=>x.id===oldDoc.id).payload.documentData.values.workerSignature,signed);
 r=await save({...oldDoc,version:1,payload:{...oldDoc.payload,documentData:{...oldDoc.payload.documentData,values:{...oldDoc.payload.documentData.values,workerSignature:''}}}});expect(r.response.status,400);expect(tables.ppl_management_entries.find(x=>x.id===oldDoc.id).version,1);
 const changingTemplate={...paper,id:oldDoc.id,version:1};expect((await save(changingTemplate)).response.status,400);
 // Editing a generic title without resending form data preserves the registered snapshot.
 const preserved=structuredClone(paper);delete preserved.payload.documentData;
 r=await save({...preserved,version:1});expect(r.response.status,200);expect(tables.ppl_management_entries.find(x=>x.id===paper.id).payload.documentData,snapshot);
 expect((await save({...paper,version:1})).response.status,409);
 // Company, employee and manager scope denial occur before persistence.
 const invalidEmployee=document();invalidEmployee.payload.documentData.employeeId=other;expect((await save(invalidEmployee)).response.status,400);
 expect((await call('management-list',{companyId:other})).status,200);role='manager';expect((await call('management-list',{companyId:other})).status,403);
 expect((await save({...document(),unit:'FORBIDDEN'})).response.status,403);expect((await save(document())).response.status,200);role='owner';
 // New print exports attach separate bytes, never overwrite the original attachment.
 const original=Buffer.from('%PDF-1.7\nORIGINAL FICTICIO'),print=Buffer.from('%PDF-1.7\nIMPRESSAO FICTICIA');
 const originalName='PPL-historico-original.pdf',printName='PPL_ORDEM DE SERVICO_COLABORADOR FICTICIO.pdf';
 let response=await call('management-file-put',{entryId:paper.id,name:originalName,base64:original.toString('base64')});expect(response.status,200);const originalId=(await response.json()).id;
 response=await call('management-file-put',{entryId:paper.id,name:printName,base64:print.toString('base64')});expect(response.status,200);const printId=(await response.json()).id;expect(blobs.size,2);
 response=await call('management-file-get',{entryId:paper.id,fileId:originalId});expect(response.status,200);expect(Buffer.from(await response.arrayBuffer()),original);
 response=await call('management-file-get',{entryId:paper.id,fileId:printId});expect(response.status,200);expect(Buffer.from(await response.arrayBuffer()),print);assert(response.headers.get('Content-Disposition').includes(encodeURIComponent(printName)));checks++;
 expect((await call('management-file-get',{entryId:paper.id,fileId:printId,companyId:other})).status,403);
 const file=tables.ppl_management_files.find(x=>x.id===printId);blobs.set(file.path,Buffer.from('CORROMPIDO'));expect((await call('management-file-get',{entryId:paper.id,fileId:printId})).status,409);
 active=false;expect((await call('management-list')).status,403);active=true;
 // Outside the catalog/OS guard/version markers, the full visual57 API is byte-preserved.
 const base=fs.readFileSync(path.join(root,'supabase/visual-v57/ppl-api-dashboard.ts'),'utf8');
 const withoutCatalog=s=>s.replace(/^const pplDocumentTemplates=.*\r?\n/m,'');
 const guard="if(t.id==='certificates-4-v3'){if(values.signatureMode==='No sistema'&&!values.workerSignature)fail('Assine no sistema ou selecione Em papel.');if(values.signatureMode==='Em papel'&&values.workerSignature)fail('Remova a assinatura digital para emitir a ordem com assinatura em papel.');}";
 const normalized=source.replace("'X-PPL-API-Version':'58'","'X-PPL-API-Version':'57'").replace("moduleVersion:58});","moduleVersion:48});").replace(guard,'');
 expect(withoutCatalog(normalized),withoutCatalog(base),'Unrelated APTO/security/record routes must remain identical');
 const raw=source.slice(source.indexOf('const pplDocumentTemplates=')+'const pplDocumentTemplates='.length,source.indexOf('\n',source.indexOf('const pplDocumentTemplates='))).trim().replace(/;$/,'');expect(JSON.parse(raw),catalog);
 const baseRaw=base.slice(base.indexOf('const pplDocumentTemplates=')+'const pplDocumentTemplates='.length,base.indexOf('\n',base.indexOf('const pplDocumentTemplates='))).trim().replace(/;$/,'');
 const oldCatalog=JSON.parse(baseRaw);
 expect(catalog.filter(t=>t.id!=='certificates-4-v2'&&t.id!=='certificates-4-v3'),oldCatalog.filter(t=>t.id!=='certificates-4-v2'),'Other document models remain unchanged');
 expect(v2,{...oldCatalog.find(t=>t.id==='certificates-4-v2'),retired:true},'V2 only changes issuance availability');
 console.log(`PASS OS58: ${checks} isolated API checks; paper/digital modes, legacy signatures, snapshots, version conflicts, scope and file integrity; no SQL or production access.`);
})().catch(error=>{console.error(error);process.exitCode=1;});
