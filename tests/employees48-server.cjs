const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict'),{stripTypeScriptTypes}=require('module');
const {PGlite}=require(process.env.PRS_PGLITE_MODULE||'@electric-sql/pglite');
const cid='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222',eid='33333333-3333-4333-8333-333333333333',uid='44444444-4444-4444-8444-444444444444',mid='55555555-5555-4555-8555-555555555555';
(async()=>{
 const db=new PGlite();let handler;
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;
 CREATE TABLE ppl_companies(id uuid PRIMARY KEY,name text,slug text,status text,brand_version int DEFAULT 1,logo_data text DEFAULT '',profile jsonb DEFAULT '{}',department text DEFAULT '',contract_manager text DEFAULT '',safety_engineer text DEFAULT '');
 CREATE TABLE ppl_employees(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),company_id uuid REFERENCES ppl_companies(id),name text NOT NULL,employee_number text NOT NULL,job_title text NOT NULL,job_description text DEFAULT '',cpf text DEFAULT '',active boolean DEFAULT true,created_at timestamptz DEFAULT now(),UNIQUE(company_id,employee_number));
 CREATE TABLE ppl_access(user_id uuid PRIMARY KEY,name text,role text,active boolean DEFAULT true);
 CREATE TABLE ppl_company_access(user_id uuid,company_id uuid,scope_mode text,active boolean DEFAULT true);
 CREATE TABLE ppl_company_models(company_id uuid,snapshot jsonb,kind text,active boolean);
 CREATE TABLE ppl_brand_versions(company_id uuid,version int,snapshot jsonb);
 CREATE TABLE ppl_inspections(key text PRIMARY KEY,id uuid,revision int,company_id uuid,record_kind text,content_hash text,pdf_hash text,pdf_path text,received_at timestamptz DEFAULT now(),unit text,team text,payload jsonb);
 INSERT INTO ppl_companies(id,name,slug,status)VALUES('${cid}','EMPRESA FICTÍCIA','ppl','ready'),('${other}','OUTRA FICTÍCIA','other','ready');
 INSERT INTO ppl_access(user_id,name,role)VALUES('${uid}','PROPRIETÁRIO FICTÍCIO','owner'),('${mid}','GESTOR FICTÍCIO','manager');
 INSERT INTO ppl_company_access(user_id,company_id,scope_mode)VALUES('${mid}','${cid}','company');
 INSERT INTO ppl_employees(id,company_id,name,employee_number,job_title,job_description,cpf)VALUES('${eid}','${cid}','PESSOA FICTÍCIA','QA-1','PINTOR','Descrição original','52998224725');`);
 const migration=fs.readFileSync(path.join(__dirname,'../supabase/cadastros-v48/ATIVAR-v48.sql'),'utf8');await db.exec(migration);await db.exec(migration);
 const original=(await db.query('SELECT * FROM ppl_employees WHERE id=$1',[eid])).rows[0];assert(original.job_id);assert.equal((await db.query('SELECT count(*)::int n FROM ppl_jobs')).rows[0].n,1);
 class Query{
  constructor(table){this.table=table;this.filters=[];this.fields='*';}select(fields='*'){this.fields=fields;return this;}eq(k,v){this.filters.push([k,v]);return this;}order(k,o={}){this.sort=[k,o.ascending===false];return this;}limit(n){this.maximum=n;return this;}maybeSingle(){this.one=true;return this;}single(){this.one=true;return this;}insert(v){this.inserted=v;return this;}update(v){this.updated=v;return this;}
  async run(){try{const args=[],where=this.filters.map(([k,v])=>`${k}=$${args.push(v)}`).join(' AND ');let sql;if(this.inserted){const keys=Object.keys(this.inserted);sql=`INSERT INTO ${this.table}(${keys})VALUES(${keys.map(k=>'$'+args.push(this.inserted[k]&&typeof this.inserted[k]==='object'?JSON.stringify(this.inserted[k]):this.inserted[k])).join(',')}) RETURNING ${this.fields}`;}else if(this.updated){const sets=Object.entries(this.updated).map(([k,v])=>`${k}=$${args.push(v)}`);sql=`UPDATE ${this.table} SET ${sets} ${where?'WHERE '+where:''} RETURNING ${this.fields}`;}else{sql=`SELECT ${this.fields} FROM ${this.table} ${where?'WHERE '+where:''}${this.sort?' ORDER BY '+this.sort[0]+(this.sort[1]?' DESC':''):''}${this.maximum?' LIMIT '+this.maximum:''}`;}const result=await db.query(sql,args);return {data:this.one?result.rows[0]||null:result.rows,error:null};}catch(error){return {data:null,error};}}then(ok,no){return this.run().then(ok,no);}
 }
 const client={from:t=>new Query(t),auth:{getUser:async token=>({data:{user:['OWNER','MANAGER'].includes(token)?{id:token==='OWNER'?uid:mid}:null}})},rpc:async(name,params)=>{if(name==='ppl_reserve_intake')return {data:true};try{const keys=Object.keys(params),q=`SELECT public.${name}(${keys.map((k,i)=>k+'=> $'+(i+1)).join(',')}) AS value`,r=await db.query(q,keys.map(k=>params[k]));return {data:r.rows[0].value};}catch(error){return {error};}}};
 const source=fs.readFileSync(path.join(__dirname,'../supabase/cadastros-v48/ppl-api-dashboard.ts'),'utf8').replace("import {createClient} from 'npm:@supabase/supabase-js@2';",'');const context={createClient:()=>client,Deno:{env:{get:()=>''},serve:fn=>handler=fn},Response,Request,TextDecoder,TextEncoder,Uint8Array,Date,crypto,atob,structuredClone,Map,Set};vm.createContext(context);vm.runInContext(stripTypeScriptTypes(source,{mode:'transform'}),context);
 const call=(action,body={},token='OWNER')=>handler(new Request('https://test.invalid',{method:'POST',headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{})},body:JSON.stringify({action,companyId:cid,...body})}));
 const read=async response=>{const data=await response.json();assert.equal(response.status,200,JSON.stringify(data));return data;};
 let data=await read(await call('employees'));assert.equal(data.jobs.length,1);assert.equal(data.moduleVersion,48);assert.equal(data.rows[0].cpf,'52998224725');
 assert.equal((await call('employee-update',{},'')).status,401);assert.equal((await call('employee-update',{},'MANAGER')).status,403);
 const update={employeeId:eid,expectedUpdatedAt:original.updated_at.toISOString(),name:'NOME FICTÍCIO CORRIGIDO',employeeNumber:'QA-2',jobTitle:'ENCARREGADO',jobDescription:'Descrição da nova função',cpf:'529.982.247-25'};
 data=await read(await call('employee-update',update));assert.equal(data.employee.name,update.name);assert.equal(data.employee.cpf,'52998224725');assert.equal(data.employee.employee_number,'QA-2');assert.equal(data.employee.job_title,'ENCARREGADO');assert.equal(data.employee.job_description,update.jobDescription);assert.equal(data.employee.id,eid);
 assert.equal((await call('employee-update',update)).status,409,'stale update blocked');
 assert.equal((await call('employee-update',{...update,employeeId:crypto.randomUUID()})).status,404);
 const jobs=(await read(await call('employees'))).jobs,job=jobs.find(j=>j.title==='ENCARREGADO');assert(job);assert.equal(jobs.length,2,'old function remains reusable after employee moves');
 assert.equal((await call('employee-create',{name:'OUTRO FICTÍCIO',employeeNumber:'QA-2',jobTitle:job.title,jobDescription:job.description,jobId:job.id})).status,409);
 assert.equal((await call('employee-create',{name:'OUTRO FICTÍCIO',employeeNumber:'QA-2',jobTitle:'FUNÇÃO NÃO SALVA',jobDescription:'Fictícia'})).status,409);
 assert.equal((await db.query("SELECT count(*)::int n FROM ppl_jobs WHERE title='FUNÇÃO NÃO SALVA'")).rows[0].n,0,'failed employee write rolls back its new function');
 assert.equal((await call('employee-create',{name:'OUTRO FICTÍCIO',employeeNumber:'QA-3',jobTitle:job.title,jobDescription:job.description,cpf:'11111111111'})).status,400);
 assert.equal((await call('employee-create',{companyId:other,name:'OUTRO FICTÍCIO',employeeNumber:'QA-3',jobTitle:job.title,jobDescription:job.description,jobId:job.id})).status,400);
 const colleague=await read(await call('employee-create',{name:'OUTRO FICTÍCIO',employeeNumber:'QA-3',jobId:job.id,jobTitle:job.title,jobDescription:'Descrição específica',updateJobTemplate:false}));assert.equal(colleague.employee.job_description,'Descrição específica');
 assert.equal((await read(await call('employees'))).jobs.find(j=>j.id===job.id).description,job.description);
 const current=(await read(await call('employees'))).rows.find(p=>p.id===eid);
 await read(await call('employee-update',{...update,expectedUpdatedAt:current.updated_at,jobId:job.id,jobDescription:'Padrão revisado',updateJobTemplate:true}));
 data=await read(await call('employees'));assert.equal(data.jobs.find(j=>j.id===job.id).description,'Padrão revisado');assert.equal(data.rows.find(p=>p.id===colleague.employee.id).job_description,'Descrição específica','never bulk rewrite coworkers');
 const history=(await db.query('SELECT * FROM ppl_employee_history WHERE employee_id=$1',[eid])).rows;assert.equal(history.length,2);assert.equal(history[0].changed_by,uid);assert(!('cpf' in history[0]));
 assert.equal((await client.rpc('ppl_employee_snapshot_matches_v48',{c:cid,e:eid,n:original.name,m:'QA-1',j:'PINTOR'})).data,true);
 assert.equal((await client.rpc('ppl_employee_snapshot_matches_v48',{c:cid,e:eid,n:original.name,m:'QA-2',j:'ENCARREGADO'})).data,false,'mixed historical identities rejected');
 assert.equal((await client.rpc('ppl_employee_snapshot_matches_v48',{c:other,e:eid,n:original.name,m:'QA-1',j:'PINTOR'})).data,false);
 await assert.rejects(()=>db.exec('UPDATE ppl_employee_history SET name=\'MODIFICADO\''));
 const ctx=await read(await call('company-context',{slug:'ppl'},''));assert(!('cpf' in ctx.employees[0]));assert(!('jobs' in ctx));assert(!('history' in ctx));
 // Exercise the real public submit path with a pre-edit employee identity and immutable model/brand.
 const model=ctx.models.find(m=>m.active).snapshot,brand=ctx.company;await db.query('INSERT INTO ppl_brand_versions(company_id,version,snapshot)VALUES($1,1,$2)',[cid,brand]);
 const now=new Date().toISOString(),id=crypto.randomUUID(),image='data:image/png;base64,AAAA',record={id,revision:1,key:id+':1',status:'recorded',kind:'checklist',company:brand,staff:{id:eid},model,fields:{type:model.types[0],date:'2026-10-20',belt:'QA-FICTÍCIO',inspector:original.name,employee:original.employee_number,functionName:original.job_title},signature:{kind:'drawn-electronic',data:image,createdAt:now},workerPhoto:{name:'FICTÍCIA',data:image,createdAt:now},answers:model.items.map(item=>({itemId:item.id,value:'Conforme',notes:'',photos:[]})),recordedAt:now};
 await read(await call('submit',{record},''));const preserved=(await db.query('SELECT payload FROM ppl_inspections WHERE key=$1',[record.key])).rows[0].payload;assert.equal(preserved.fields.inspector,original.name);assert.equal(preserved.fields.employee,'QA-1');assert.equal(preserved.fields.functionName,'PINTOR');
 await read(await call('submit',{record},''));assert.equal((await db.query('SELECT count(*)::int n FROM ppl_inspections')).rows[0].n,1,'idempotent retry');
 const forged=structuredClone(record);forged.id=crypto.randomUUID();forged.key=forged.id+':1';forged.fields.functionName='ENCARREGADO';assert.equal((await call('submit',{record:forged},'')).status,400);
 for(const role of ['anon','authenticated']){await db.exec('SET ROLE '+role);await assert.rejects(()=>db.exec('SELECT * FROM public.ppl_jobs'));await assert.rejects(()=>db.exec('SELECT * FROM public.ppl_employee_history'));await assert.rejects(()=>db.exec(`SELECT public.ppl_employee_snapshot_matches_v48('${cid}','${eid}','x','y',NULL)`));await db.exec('RESET ROLE');}
 await db.exec(migration);assert.equal((await db.query('SELECT count(*)::int n FROM ppl_employee_history')).rows[0].n,2);await db.close();console.log('PASS employees48: migration twice, owner-only full edits, CPF privacy, durable company jobs, explicit template update, uniqueness/conflicts/rollback, immutable identity history and offline submit/retry.');
})().catch(error=>{console.error(error);process.exitCode=1});
