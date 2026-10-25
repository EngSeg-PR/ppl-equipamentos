/* Isolated PostgreSQL + actual Edge Function handler. Never contacts production. */
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const { spawnSync } = require('node:child_process');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '..'), workspace = path.resolve(root, '../..');
const { Client, Pool } = require(process.env.PRS_PG_MODULE || path.join(workspace, 'work/sql-validation/node_modules/pg'));
const pgRoot = process.env.PRS_PG_ROOT || path.join(workspace, 'work/sql-validation/package/native');
const ids = { company:'11111111-1111-4111-8111-111111111111', other:'22222222-2222-4222-8222-222222222222', employee:'33333333-3333-4333-8333-333333333333', owner:'44444444-4444-4444-8444-444444444444', manager:'55555555-5555-4555-8555-555555555555', restricted:'66666666-6666-4666-8666-666666666666' };
const identities = { OWNER:ids.owner, MANAGER:ids.manager, RESTRICTED:ids.restricted };
function execute(file, args) {
  const result = spawnSync(file, args, { windowsHide:true, stdio:'ignore', timeout:60000 });
  if (result.error || result.status !== 0) throw Error(path.basename(file) + ': ' + (result.error || result.status));
}
async function createHarness() {
  const out = path.join(workspace, 'work', 'attention51-' + Date.now()); fs.mkdirSync(out, {recursive:true});
  const data = path.join(out, 'data'), ctl = path.join(pgRoot, 'bin/pg_ctl.exe'), port = Number(process.env.PRS_PG_PORT || 55473);
  execute(path.join(pgRoot, 'bin/initdb.exe'), ['-D',data,'-U','postgres','-A','trust','--encoding=UTF8','--no-locale','--no-sync']);
  execute(ctl, ['-D',data,'-l',path.join(out,'server.log'),'-o',`-p ${port} -c listen_addresses=127.0.0.1`,'-w','start']);
  const connection = {host:'127.0.0.1',port,user:'postgres',database:'postgres'}, db = new Client(connection), pool = new Pool({...connection,max:8});
  try {
    await db.connect();
    await db.query(`
      CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
      CREATE SCHEMA auth;
      CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      GRANT USAGE ON SCHEMA public,auth TO anon,authenticated,service_role;
      CREATE TABLE ppl_companies(id uuid PRIMARY KEY,name text,slug text,status text,brand_version int DEFAULT 1,logo_data text DEFAULT '',profile jsonb DEFAULT '{}');
      CREATE TABLE ppl_employees(id uuid PRIMARY KEY,company_id uuid REFERENCES ppl_companies(id),name text,employee_number text,job_title text,job_description text DEFAULT '',cpf text DEFAULT '',active boolean DEFAULT true);
      CREATE TABLE ppl_access(user_id uuid PRIMARY KEY,name text,role text,active boolean DEFAULT true);
      CREATE TABLE ppl_company_access(user_id uuid,company_id uuid,scope_mode text,active boolean DEFAULT true);
      CREATE TABLE ppl_scopes(user_id uuid,company_id uuid,unit text,team text);
      CREATE FUNCTION ppl_can_read_company(c uuid,u text,t text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
      SELECT EXISTS(SELECT 1 FROM ppl_access p WHERE p.user_id=auth.uid() AND p.active AND (p.role='owner' OR EXISTS(SELECT 1 FROM ppl_company_access ca WHERE ca.user_id=p.user_id AND ca.company_id=c AND ca.active AND (ca.scope_mode='company' OR EXISTS(SELECT 1 FROM ppl_scopes s WHERE s.user_id=p.user_id AND s.company_id=c AND s.unit=u AND s.team=t))))) $$;
      INSERT INTO ppl_companies(id,name,slug,status)VALUES('${ids.company}','EMPRESA DE TESTE','ppl','ready'),('${ids.other}','OUTRA EMPRESA DE TESTE','other','ready');
      INSERT INTO ppl_employees(id,company_id,name,employee_number,job_title,cpf)VALUES('${ids.employee}','${ids.company}','COLABORADOR DE TESTE','QA-1','CONDUTOR','52998224725');
      INSERT INTO ppl_access(user_id,name,role)VALUES('${ids.owner}','PROPRIETÁRIO DE TESTE','owner'),('${ids.manager}','GESTOR DE TESTE','manager'),('${ids.restricted}','ACESSO RESTRITO DE TESTE','manager');
      INSERT INTO ppl_company_access(user_id,company_id,scope_mode)VALUES('${ids.manager}','${ids.company}','company'),('${ids.restricted}','${ids.company}','teams');
      INSERT INTO ppl_scopes VALUES('${ids.restricted}','${ids.company}','PORTO','MECÂNICA');
    `);
    const migration = fs.readFileSync(path.join(root,'supabase/triagem-v51/ATIVAR-v51.sql'),'utf8');
    await db.query(migration); await db.query(migration);
    async function scoped(sql,args=[],token=null,rpc=false) {
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        if (token) { await client.query('SET LOCAL ROLE authenticated'); await client.query("SELECT set_config('request.jwt.claim.sub',$1,true)",[identities[token] || '']); }
        else if (rpc) await client.query('SET LOCAL ROLE service_role');
        const result = await client.query(sql,args); await client.query('COMMIT'); return result;
      } catch(e) { await client.query('ROLLBACK'); throw e; }
      finally { client.release(); }
    }
    const identifier = s => { if (!/^[a-z_][a-z0-9_]*$/.test(s)) throw Error('Invalid identifier'); return '"'+s+'"'; };
    class Query {
      constructor(table, token) { this.table=table;this.token=token;this.filters=[];this.sorts=[];this.fields='*'; }
      select(fields='*'){this.fields=fields;return this;}
      eq(k,v){this.filters.push([k,'=',v]);return this;}
      gte(k,v){this.filters.push([k,'>=',v]);return this;}
      lt(k,v){this.filters.push([k,'<',v]);return this;}
      in(k,v){this.filters.push([k,'ANY',v]);return this;}
      order(k,o={}){this.sorts.push(identifier(k)+(o.ascending===false?' DESC':' ASC'));return this;}
      limit(n){this.maximum=n;return this;}
      range(start,end){this.offset=start;this.maximum=end-start+1;return this;}
      maybeSingle(){this.one=true;return this;} single(){this.one=true;return this;}
      async run(){try{
        const args=[],where=this.filters.map(([k,op,v])=>`${identifier(k)} ${op==='ANY'?'= ANY(':op+' '}$${args.push(v)}${op==='ANY'?')':''}`);
        const fields=this.fields==='*'?'*':this.fields.split(',').map(identifier).join(',');
        const sql=`SELECT ${fields} FROM ${identifier(this.table)}${where.length?' WHERE '+where.join(' AND '):''}${this.sorts.length?' ORDER BY '+this.sorts.join(','):''}${this.maximum===undefined?'':' LIMIT '+Number(this.maximum)}${this.offset?' OFFSET '+Number(this.offset):''}`;
        const result=await scoped(sql,args,this.token);return {data:this.one?result.rows[0]||null:result.rows,error:null};
      }catch(error){return {data:null,error};}}
      then(ok,no){return this.run().then(ok,no);}
    }
    function createClient(url,key,options){const token=options?.global?.headers?.Authorization?.replace(/^Bearer /,'') || null;return {
      from:table=>new Query(table,token),
      auth:{getUser:async token=>({data:{user:identities[token]?{id:identities[token]}:null}})},
      async rpc(name,params){try{const keys=Object.keys(params),result=await scoped(`SELECT public.${identifier(name)}(${keys.map((k,i)=>identifier(k)+'=>$'+(i+1)).join(',')}) AS value`,Object.values(params),token,!token);return {data:result.rows[0].value,error:null};}catch(error){return {data:null,error};}},
    };}
    let handler;
    const source=fs.readFileSync(path.join(root,'supabase/triagem-v51/ppl-api-dashboard.ts'),'utf8').replace("import {createClient} from 'npm:@supabase/supabase-js@2';",'');
    const context={createClient,Deno:{env:{get:key=>key==='PPL_ALLOWED_ORIGINS'?'http://127.0.0.1:8766,http://127.0.0.1:8765':'TEST'},serve:fn=>handler=fn},Response,Request,TextDecoder,TextEncoder,Uint8Array,Date,crypto,atob,structuredClone,Map,Set};
    vm.createContext(context);vm.runInContext(stripTypeScriptTypes(source,{mode:'transform'}),context);
    const call=(action,body={},token='OWNER')=>handler(new Request('https://test.invalid',{method:'POST',headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{})},body:JSON.stringify({action,companyId:ids.company,...body})}));
    return {db,pool,handler,call,out,scoped,async close(){await pool.end();await db.end();execute(ctl,['-D',data,'-m','fast','-w','stop']);}};
  } catch(e){await pool.end().catch(()=>{});await db.end().catch(()=>{});execute(ctl,['-D',data,'-m','fast','-w','stop']);throw e;}
}
function assessment(extra={}) { return {id:crypto.randomUUID(),employeeId:ids.employee,unit:'PORTO',team:'MECÂNICA',moment:'inicio',startedAt:'2026-10-24T12:00:00Z',finishedAt:'2026-10-24T12:00:05.200Z',status:'completa',durationMs:5200,grid:[3,1,4,2],touches:[{seq:1,tMs:1200,touched:1,expected:1,correct:true},{seq:2,tMs:2500,touched:3,expected:2,correct:false},{seq:3,tMs:3300,touched:2,expected:2,correct:true},{seq:4,tMs:4400,touched:3,expected:3,correct:true},{seq:5,tMs:5200,touched:4,expected:4,correct:true}],protocolVersion:'sequencia-v1',appVersion:'0.2.0',...extra}; }
async function test() {
  const h=await createHarness();let checks=0;
  const expect=(a,b,message)=>{assert.deepEqual(a,b,message);checks++;};
  const read=async r=>{const d=await r.json();expect(r.status,200,JSON.stringify(d));return d;};
  try {
    expect((await h.call('attention-context',{},'')).status,401);expect((await h.call('attention-context',{},'INVALID')).status,401);
    const ctx=await read(await h.call('attention-context',{},'RESTRICTED'));expect(ctx.companies.length,1);expect(ctx.employees[0].cpf,undefined);expect(ctx.scopes,[{unit:'PORTO',team:'MECÂNICA'}]);
    expect((await h.call('attention-context',{companyId:ids.other},'MANAGER')).status,403);
    const a=assessment(),first=await read(await h.call('attention-submit',{assessment:a},'RESTRICTED'));expect(first.status,'ok');expect(first.assessment.metrics.quartis_ms,[1200,2100,1100,800]);expect(first.assessment.metrics.erros,1);
    expect((await read(await h.call('attention-submit',{assessment:a}))).status,'duplicada');
    expect((await h.db.query('SELECT count(*)::int n FROM ppl_attention_assessments')).rows[0].n,1);
    expect((await h.call('attention-submit',{assessment:{...a,team:'OUTRA'}})).status,409);
    expect((await h.call('attention-submit',{assessment:assessment({unit:'FERROVIA'})},'RESTRICTED')).status,403);
    expect((await h.call('attention-submit',{companyId:ids.other,assessment:assessment()})).status,404);
    expect((await h.call('attention-submit',{assessment:assessment({metrics:{erros:0}})})).status,400);
    for(const modified of [assessment({grid:[1,1,3,4]}),assessment({durationMs:180001}),assessment({status:'incompleta'}),assessment({touches:[{seq:1,tMs:100,touched:2,expected:1,correct:true}]})]) expect((await h.call('attention-submit',{assessment:modified})).status,400);
    const b=assessment({unit:'FERROVIA',status:'incompleta',touches:[],durationMs:0,finishedAt:'2026-10-24T12:00:00Z'});await read(await h.call('attention-submit',{assessment:b}));
    const own=await read(await h.call('attention-history-list',{},'RESTRICTED'));expect(own.rows.length,1);expect(own.rows[0].id,a.id);
    expect((await h.call('attention-history-detail',{id:b.id},'RESTRICTED')).status,404);
    const paged=await read(await h.call('attention-history-list',{limit:1}));expect(paged.rows.length,1);expect(paged.nextOffset,1);
    expect((await h.call('attention-history-list',{dateFrom:'2026-02-30'})).status,400);
    const detail=await read(await h.call('attention-history-detail',{id:a.id}));expect(detail.assessment.touches,a.touches);
    await h.db.query('UPDATE ppl_employees SET name=$1,active=false WHERE id=$2',['NOME NOVO',ids.employee]);
    expect((await read(await h.call('attention-submit',{assessment:a}))).status,'duplicada');
    expect((await read(await h.call('attention-history-detail',{id:a.id}))).assessment.employee_name,'COLABORADOR DE TESTE');
    expect((await h.call('attention-submit',{assessment:assessment()})).status,404);
    await h.db.query('UPDATE ppl_access SET active=false WHERE user_id=$1',[ids.manager]);expect((await h.call('attention-history-list',{},'MANAGER')).status,403);
    await assert.rejects(()=>h.scoped('DELETE FROM ppl_attention_assessments',[],'OWNER'));checks++;
    await assert.rejects(()=>h.db.query('UPDATE ppl_attention_assessments SET employee_name=$1',['ALTERADO']));checks++;
    await assert.rejects(()=>h.scoped('SELECT ppl_attention_submit_v51($1,$2,$3)',[ids.company,ids.owner,a],'OWNER'));checks++;
    fs.writeFileSync(path.join(h.out,'summary.json'),JSON.stringify({checks,passed:true,sqlMigrationRuns:2,realPostgreSQL:true,authHarness:true},null,2));
    console.log(`PASS attention51: ${checks} verificações; SQL real, API, RLS, idempotência, rejeições, métricas e preservação. ${h.out}`);
  } finally { await h.close(); }
}
module.exports={createHarness,assessment,ids,identities};
if(require.main===module)test().catch(e=>{console.error(e);process.exitCode=1;});
