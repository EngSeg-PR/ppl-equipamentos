/* Integração local descartável: PostgreSQL real + handler54. Nunca usa produção. */
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {stripTypeScriptTypes}=require('node:module');
const {createHarness,ids,identities,assessment}=require('./attention51-server.cjs');
const root=path.resolve(__dirname,'..');
const otherEmployee='77777777-7777-4777-8777-777777777777';
function identifier(s){if(!/^[a-z_][a-z0-9_]*$/.test(s))throw Error('Identificador inválido');return '"'+s+'"';}
async function test(){
 const h=await createHarness();let checks=0;const expect=(a,b,message)=>{assert.deepEqual(a,b,message);checks++;};
 try{
  await h.db.query(`
   ALTER TABLE ppl_companies ADD COLUMN department text DEFAULT '',ADD COLUMN contract_manager text DEFAULT '',ADD COLUMN safety_engineer text DEFAULT '';
   CREATE TABLE ppl_company_models(company_id uuid,model_id text,version text,snapshot jsonb,kind text,active boolean DEFAULT true);
   CREATE TABLE ppl_brand_versions(company_id uuid,version int,snapshot jsonb);
   CREATE TABLE ppl_inspections(key text PRIMARY KEY,id uuid,revision int,company_id uuid,record_kind text,content_hash text,pdf_hash text DEFAULT '',pdf_path text DEFAULT '',unit text,team text,payload jsonb,received_at timestamptz DEFAULT now());
   CREATE TABLE ppl_employee_history(company_id uuid,employee_id uuid,name text,employee_number text,job_title text);
   CREATE FUNCTION ppl_employee_snapshot_matches_v48(c uuid,e uuid,n text,m text,j text DEFAULT NULL) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT EXISTS(SELECT 1 FROM ppl_employees WHERE company_id=c AND id=e AND name=n AND (m IS NULL OR employee_number=m) AND (j IS NULL OR job_title=j)) OR EXISTS(SELECT 1 FROM ppl_employee_history WHERE company_id=c AND employee_id=e AND name=n AND (m IS NULL OR employee_number=m) AND (j IS NULL OR job_title=j)); $$;
   CREATE FUNCTION ppl_reserve_intake(n int) RETURNS boolean LANGUAGE sql AS $$ SELECT true $$;
   GRANT EXECUTE ON FUNCTION ppl_employee_snapshot_matches_v48(uuid,uuid,text,text,text),ppl_reserve_intake(int) TO service_role;
   INSERT INTO ppl_employees(id,company_id,name,employee_number,job_title)VALUES('${otherEmployee}','${ids.other}','OUTRO COLABORADOR','QA-OTHER','CONDUTOR');
  `);
  const migration=fs.readFileSync(path.join(root,'supabase/executantes-v54/ATIVAR-v54.sql'),'utf8');
  await h.db.query(migration);await h.db.query(migration);
  await h.db.query("CREATE OR REPLACE FUNCTION public.ppl_can_read_company(c uuid,u text,t text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT public.ppl_attention_actor_allowed_v51(auth.uid(),c,u,t) $$");
  const followupFile=path.join(root,'supabase/executantes-v54/attention-followup.sql');
  if(fs.existsSync(followupFile))await h.db.query(fs.readFileSync(followupFile,'utf8'));
  class Query{
   constructor(table,token){this.table=table;this.token=token;this.filters=[];this.sorts=[];this.fields='*';}
   select(v='*'){this.fields=v;return this;}eq(k,v){this.filters.push([k,'=',v]);return this;}
   gte(k,v){this.filters.push([k,'>=',v]);return this;}lt(k,v){this.filters.push([k,'<',v]);return this;}
   in(k,v){this.filters.push([k,'ANY',v]);return this;}order(k,o={}){this.sorts.push(identifier(k)+(o.ascending===false?' DESC':' ASC'));return this;}
   limit(n){this.maximum=n;return this;}range(a,b){this.offset=a;this.maximum=b-a+1;return this;}
   insert(v){this.mutation='insert';this.values=v;return this;}update(v){this.mutation='update';this.values=v;return this;}
   maybeSingle(){this.one=true;return this;}single(){this.one=true;return this;}
   async run(){try{
    const args=[],fieldList=this.fields==='*'?'*':this.fields.split(',').map(identifier).join(',');let sql;
    const where=()=>this.filters.map(([k,op,v])=>`${identifier(k)} ${op==='ANY'?'= ANY(':op+' '}$${args.push(v)}${op==='ANY'?')':''}`).join(' AND ');
    if(this.mutation==='insert'){
     const keys=Object.keys(this.values);sql=`INSERT INTO ${identifier(this.table)}(${keys.map(identifier)})VALUES(${keys.map(k=>'$'+args.push(this.values[k]))}) RETURNING ${fieldList}`;
    }else if(this.mutation==='update'){
     const keys=Object.keys(this.values),set=keys.map(k=>`${identifier(k)}=$${args.push(this.values[k])}`).join(',');
     sql=`UPDATE ${identifier(this.table)} SET ${set}${this.filters.length?' WHERE '+where():''} RETURNING ${fieldList}`;
    }else sql=`SELECT ${fieldList} FROM ${identifier(this.table)}${this.filters.length?' WHERE '+where():''}${this.sorts.length?' ORDER BY '+this.sorts.join(','):''}${this.maximum===undefined?'':' LIMIT '+Number(this.maximum)}${this.offset?' OFFSET '+Number(this.offset):''}`;
    const result=await h.scoped(sql,args,this.token);return {data:this.one?result.rows[0]||null:result.rows,error:null};
   }catch(error){return {data:null,error};}}
   then(ok,no){return this.run().then(ok,no);}
  }
  function createClient(url,key,options){const token=options?.global?.headers?.Authorization?.replace(/^Bearer /,'')||null;return {
   from:table=>new Query(table,token),auth:{getUser:async token=>({data:{user:identities[token]?{id:identities[token]}:null}})},
   async rpc(name,params){try{const keys=Object.keys(params),result=await h.scoped(`SELECT public.${identifier(name)}(${keys.map((k,i)=>identifier(k)+'=>$'+(i+1)).join(',')})AS value`,Object.values(params),token,!token);return {data:result.rows[0].value,error:null};}catch(error){return {data:null,error};}}
  };}
  let handler;const source=fs.readFileSync(path.join(root,'supabase/executantes-v54/ppl-api-dashboard.ts'),'utf8').replace("import {createClient} from 'npm:@supabase/supabase-js@2';",'');
  const context={createClient,Deno:{env:{get:k=>k==='PPL_ALLOWED_ORIGINS'?'http://127.0.0.1:8766':'TEST'},serve:f=>handler=f},Response,Request,TextDecoder,TextEncoder,Uint8Array,Date,crypto,atob,structuredClone,Map,Set};
  vm.createContext(context);vm.runInContext(stripTypeScriptTypes(source,{mode:'transform'}),context);
  const call=(action,body={},jwt='',executorToken='')=>handler(new Request('https://test.invalid',{method:'POST',headers:{'content-type':'application/json',...(jwt?{authorization:'Bearer '+jwt}:{}),...(executorToken?{'X-PPL-Executor':executorToken}:{})},body:JSON.stringify({action,companyId:ids.company,...body})}));
  const read=async response=>{const data=await response.json();expect(response.status,200,JSON.stringify(data));return data;};
  const publicContext=await read(await call('company-context'));expect(publicContext.moduleVersion,54);expect(publicContext.employees,[]);expect(publicContext.executorAccessRequired,false);
  const directory=await read(await call('executor-directory'));expect(Object.keys(directory.employees[0]).sort(),['id','name']);expect(JSON.stringify(directory).includes('QA-1'),false);expect(JSON.stringify(directory).includes('52998224725'),false);
  expect((await call('company-context',{},'INVALID')).status,401);expect((await call('company-context',{companyId:ids.other},'MANAGER')).status,403);
  const manager=await read(await call('company-context',{},'MANAGER'));expect(manager.employees[0].employee_number,'QA-1');expect(manager.employees[0].cpf,undefined);
  expect((await call('executor-login',{employeeId:otherEmployee,password:'QA-OTHER'})).status,401);
  expect((await call('executor-login',{employeeId:ids.employee,password:'ERRADA'})).status,401);
  const login=await read(await call('executor-login',{employeeId:ids.employee,password:'QA-1'}));assert.match(login.executorToken,/^[a-f0-9]{64}$/);checks++;
  expect(login.employee.cpf,undefined);expect(login.employee.employee_number,'QA-1');assert(Date.parse(login.expiresAt)>Date.now()+11.9*3600000);checks++;
  const saved=(await h.db.query('SELECT * FROM ppl_executor_sessions')).rows[0];expect(saved.token_hash===login.executorToken,false);expect(saved.token_hash,await crypto.subtle.digest('SHA-256',new TextEncoder().encode(login.executorToken)).then(x=>Buffer.from(x).toString('hex')));
  const own=await read(await call('company-context',{},'',login.executorToken));expect(own.employees.length,1);expect(own.employees[0].id,ids.employee);
  expect((await call('executor-session',{companyId:ids.other},'',login.executorToken)).status,401);
  expect((await call('executor-config',{required:true},'MANAGER')).status,403);
  await read(await call('executor-config',{required:true},'OWNER'));expect((await read(await call('company-context'))).executorAccessRequired,true);
  const custom={id:'qa-executor54',version:'1',title:'MODELO DE TESTE',types:['Rotina'],identifiers:[],items:[{id:'qa-1',text:'Item de teste'}]};
  await h.db.query('INSERT INTO ppl_company_models(company_id,model_id,version,snapshot,kind)VALUES($1,$2,$3,$4,$5)',[ids.company,custom.id,custom.version,custom,'checklist']);
  const company={id:ids.company,slug:'ppl',name:'EMPRESA DE TESTE',version:1,logoData:''};await h.db.query('INSERT INTO ppl_brand_versions VALUES($1,1,$2)',[ids.company,company]);
  const image='data:image/png;base64,iVBORw0KGgo=',now=new Date().toISOString(),id=crypto.randomUUID();
  const record={id,key:id+':1',revision:1,status:'recorded',kind:'checklist',company,staff:{id:ids.employee},model:custom,fields:{type:'Rotina',date:'2026-10-20',belt:'QA',inspector:'COLABORADOR DE TESTE',employee:'QA-1',functionName:'CONDUTOR',unit:'PORTO',team:'MECÂNICA'},answers:[{itemId:'qa-1',value:'Conforme',notes:'',photos:[]}],signature:{kind:'drawn-electronic',data:image,createdAt:now},workerPhoto:{name:'Foto de teste',data:image,createdAt:now},recordedAt:now};
  expect((await call('submit',{record})).status,401);expect((await call('submit',{record},'OWNER')).status,401);
  expect((await call('submit',{record:{...record,staff:{id:otherEmployee}}},'',login.executorToken)).status,403);
  expect((await call('submit',{record:{...record,fields:{...record.fields,inspector:'OUTRA PESSOA'}}},'',login.executorToken)).status,403);
  expect((await call('submit',{record:{...record,executorToken:login.executorToken}},'',login.executorToken)).status,400);
  await read(await call('submit',{record},'',login.executorToken));await read(await call('submit',{record},'',login.executorToken));
  expect((await h.db.query('SELECT count(*)::int n FROM ppl_inspections')).rows[0].n,1);expect((await h.db.query('SELECT payload FROM ppl_inspections')).rows[0].payload,record);
  const legacyId=crypto.randomUUID(),legacy={...record,id:legacyId,key:legacyId+':1'};delete legacy.company;delete legacy.staff;
  await read(await call('submit',{record:legacy},'',login.executorToken));
  expect((await h.db.query('SELECT payload FROM ppl_inspections WHERE key=$1',[legacy.key])).rows[0].payload,legacy);
  // Alteração cadastral: o resultado original permanece e uma sessão nova aceita a identidade histórica completa.
  await h.db.query('INSERT INTO ppl_employee_history SELECT company_id,id,name,employee_number,job_title FROM ppl_employees WHERE id=$1',[ids.employee]);
  await h.db.query("UPDATE ppl_employees SET name='NOME CORRIGIDO',employee_number='QA-2',job_title='FUNÇÃO NOVA' WHERE id=$1",[ids.employee]);
  expect((await call('executor-session',{},'',login.executorToken)).status,401);
  const second=await read(await call('executor-login',{employeeId:ids.employee,password:'QA-2'}));await read(await call('submit',{record},'',second.executorToken));
  await read(await call('executor-logout',{},'',second.executorToken));expect((await call('executor-session',{},'',second.executorToken)).status,401);
  const third=await read(await call('executor-login',{employeeId:ids.employee,password:'QA-2'}));await h.db.query('UPDATE ppl_employees SET active=false WHERE id=$1',[ids.employee]);expect((await call('executor-session',{},'',third.executorToken)).status,401);
  expect((await call('executor-login',{employeeId:ids.employee,password:'QA-2'})).status,401);
  await h.db.query('UPDATE ppl_employees SET active=true WHERE id=$1',[ids.employee]);await h.db.query('DELETE FROM ppl_executor_attempts');
  for(let i=0;i<8;i++)expect((await call('executor-login',{employeeId:ids.employee,password:'ERRADA'})).status,401);
  expect((await call('executor-login',{employeeId:ids.employee,password:'QA-2'})).status,429);
  await h.db.query("UPDATE ppl_executor_attempts SET window_start=now()-interval '16 minutes'");
  const afterLimit=await read(await call('executor-login',{employeeId:ids.employee,password:'QA-2'}));
  await h.db.query("UPDATE ppl_executor_sessions SET expires_at=issued_at+interval '1 second',issued_at=now()-interval '2 seconds' WHERE token_hash=$1",[await crypto.subtle.digest('SHA-256',new TextEncoder().encode(afterLimit.executorToken)).then(x=>Buffer.from(x).toString('hex'))]);
  // Ajuste direto de fixture para exercitar expiração, sem depender da espera do relógio.
  await h.db.query("UPDATE ppl_executor_sessions SET issued_at=now()-interval '3 hours',expires_at=now()-interval '1 hour'");expect((await call('executor-session',{},'',afterLimit.executorToken)).status,401);
  await assert.rejects(()=>h.scoped('SELECT * FROM ppl_executor_sessions',[],'OWNER'));checks++;
  await assert.rejects(()=>h.scoped('SELECT ppl_executor_issue_v54($1,$2,1,$3)',[ids.company,ids.employee,'a'.repeat(64)],'OWNER'));checks++;
  await assert.rejects(()=>h.scoped('SELECT * FROM ppl_executor_attempts',[],null,true));checks++;
  expect((await read(await call('owner-companies',{},'OWNER'))).moduleVersion,54);
  // API de atenção51 continua autenticada e funcional no handler54.
  expect((await call('attention-context')).status,401);expect((await read(await call('attention-context',{},'OWNER'))).moduleVersion,51);
  const a=assessment();await read(await call('attention-submit',{assessment:a},'OWNER'));expect((await read(await call('attention-history-list',{},'OWNER'))).rows.length,1);
  // Bloco APTO54 exercitado dentro do handler completo, além do teste detalhado do módulo.
  const dashboard=await read(await call('attention-dashboard-list',{},'OWNER'));expect(dashboard.summary.total,1);expect(dashboard.rows[0].id,a.id);
  expect((await call('attention-dashboard-list')).status,401);
  const followup=await read(await call('attention-followup-save',{id:a.id,status:'aberta',note:'Acompanhamento operacional de teste',expectedRevision:0},'OWNER'));expect(followup.current.revision,1);
  const followupDetail=await read(await call('attention-followup-detail',{id:a.id},'OWNER'));expect(followupDetail.current.status,'aberta');
  const cors=await handler(new Request('https://test.invalid',{method:'OPTIONS',headers:{Origin:'http://127.0.0.1:8766','Access-Control-Request-Headers':'x-ppl-executor'}}));expect(cors.status,204);assert(cors.headers.get('Access-Control-Allow-Headers').includes('x-ppl-executor'));checks++;
  expect((await handler(new Request('https://test.invalid',{method:'POST',headers:{Origin:'https://other.invalid','Content-Type':'application/json'},body:'{"action":"companies"}'}))).status,403);
  fs.writeFileSync(path.join(h.out,'executor54-summary.json'),JSON.stringify({passed:true,checks,sqlMigrationRuns:2,realPostgreSQL:true,productionAccess:false},null,2));
  console.log(`PASS executor54: ${checks} verificações SQL/API. ${h.out}`);
 }finally{await h.close();}
}
if(require.main===module)test().catch(e=>{console.error(e);process.exitCode=1;});

