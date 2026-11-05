/* Actual local PostgreSQL. Synthetic companies only; never contacts Supabase. */
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),deps=process.env.PRS_PG_DEPS||'C:/Users/Paulo Ricardo/OneDrive/Documentos/ChatGPT/SISTEMA APTO/work/sql-validation';
const {Client}=require(path.join(deps,'node_modules/pg'));
const native=path.join(deps,'package/native/bin'),out=path.resolve(root,'../qa-ppl59/sql-'+Date.now()),data=path.join(out,'data');
const port=Number(process.env.PRS_PG_PORT||55489),connection={host:'127.0.0.1',port,user:'postgres',database:'postgres'};
const cid='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222',owner='44444444-4444-4444-8444-444444444444',manager='55555555-5555-4555-8555-555555555555';
const models=JSON.parse(fs.readFileSync(path.join(root,'ppl-checklist-models-v59.json'),'utf8'));
const sql=fs.readFileSync(path.join(root,'supabase/checklists-v59/ATIVAR-v59.sql'),'utf8');let checks=0;
function run(exe,args){const r=spawnSync(path.join(native,exe),args,{windowsHide:true,stdio:'ignore',timeout:60000});if(r.error||r.status!==0)throw Error(exe+': '+(r.error||r.status));}
const expect=(a,b,message)=>{assert.deepEqual(a,b,message);checks++;};
function revision(id,label,tag){return {id,company_id:cid,revision:label,source_filename:'REVISAO-FICTICIA.xls',source_hash:crypto.createHash('sha256').update('source-'+tag).digest('hex'),source_mime:'application/vnd.ms-excel',source_path:cid+'/checklist-revisions/'+tag+'/source.xls',source_size:9,request_hash:crypto.createHash('sha256').update('request-'+tag).digest('hex')};}
function batch(id){return models.map((m,n)=>({kind:'checklist',active:n!==0,snapshot:{...structuredClone(m),version:'59-'+id}}));}
async function state(db){return (await db.query(`SELECT model_id,version,active FROM public.ppl_company_models ORDER BY model_id COLLATE "C",version COLLATE "C"`)).rows;}
const rpc=(db,r,m,expected,custom,actor=owner)=>db.query('SELECT public.ppl_publish_checklist_revision_v59($1,$2,$3,$4,$5) AS value',[JSON.stringify(r),JSON.stringify(m),expected,JSON.stringify(custom),actor]);
(async()=>{let db,started=false;fs.mkdirSync(out,{recursive:true});try{
 run('initdb.exe',['-D',data,'-U','postgres','-A','trust','--encoding=UTF8','--no-locale','--no-sync']);
 run('pg_ctl.exe',['-D',data,'-l',path.join(out,'server.log'),'-o',`-p ${port} -c listen_addresses=127.0.0.1`,'-w','start']);started=true;
 db=new Client(connection);await db.connect();await db.query(`
 CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role BYPASSRLS;
 GRANT USAGE ON SCHEMA public TO anon,authenticated,service_role;
 CREATE TABLE public.ppl_companies(id uuid PRIMARY KEY,slug text);
 CREATE TABLE public.ppl_access(user_id uuid PRIMARY KEY,role text,active boolean);
 CREATE TABLE public.ppl_company_models(company_id uuid,model_id text NOT NULL,version text NOT NULL,kind text NOT NULL,snapshot jsonb NOT NULL,active boolean NOT NULL DEFAULT true,created_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(company_id,model_id,version));
 CREATE TABLE public.ppl_inspections(id text,payload jsonb,pdf_path text);
 INSERT INTO public.ppl_companies VALUES('${cid}','ppl'),('${other}','other');
 INSERT INTO public.ppl_access VALUES('${owner}','owner',true),('${manager}','manager',true);
 INSERT INTO public.ppl_inspections VALUES('INSPECAO-FICTICIA','{"original":true}','historico.pdf');
 `);
 await db.query(sql);await db.query(sql);checks+=2;
 const initialEvidence=JSON.stringify((await db.query('TABLE public.ppl_inspections')).rows);
 await db.query('INSERT INTO public.ppl_company_models VALUES($1,$2,$3,$4,$5,$6)',[cid,models[0].id,'HISTORICO','checklist',models[0],false]);
 await db.query('INSERT INTO public.ppl_company_models VALUES($1,$2,$3,$4,$5,$6)',[cid,models[1].id,'HISTORICO','checklist',models[1],true]);
 const prior=await state(db),priorSnapshots=JSON.stringify((await db.query('SELECT snapshot FROM public.ppl_company_models ORDER BY model_id')).rows);
 for(const role of ['anon','authenticated']){await db.query('SET ROLE '+role);await assert.rejects(()=>db.query('TABLE public.ppl_checklist_revisions'),/permission denied/);await assert.rejects(()=>rpc(db,{},[],null,[]),/permission denied/);await assert.rejects(()=>db.query('SELECT public.ppl_hide_checklist_model_v59($1,$2,$3)',[cid,models[1],owner]),/permission denied/);await db.query('RESET ROLE');checks+=3;}
 const id1=crypto.randomUUID(),r1=revision(id1,'Rev.06','one'),m1=batch(id1);
 await db.query('SET ROLE service_role');await assert.rejects(()=>rpc(db,r1,m1,null,prior,manager),/revision_owner_required/);await assert.rejects(()=>rpc(db,{...r1,company_id:other},m1,null,prior),/revision_ppl_required/);await db.query('RESET ROLE');checks+=2;
 let result=await rpc(db,r1,m1,null,prior);expect(result.rows[0].value.modelCount,46);expect(result.rows[0].value.idempotent,false);
 expect((await db.query('SELECT count(*)::int n FROM public.ppl_checklist_revisions')).rows[0].n,1);
 expect((await db.query('SELECT count(*)::int n FROM public.ppl_company_models WHERE active')).rows[0].n,45);
 expect((await db.query('SELECT active FROM public.ppl_company_models WHERE version=$1',['HISTORICO'])).rows.every(r=>!r.active),true);
 expect(JSON.stringify((await db.query('SELECT snapshot FROM public.ppl_company_models WHERE version=$1 ORDER BY model_id',['HISTORICO'])).rows),priorSnapshots);
 expect((await rpc(db,r1,m1,null,prior)).rows[0].value.idempotent,true);
 await assert.rejects(()=>rpc(db,{...r1,request_hash:'0'.repeat(64)},m1,null,prior),/revision_file_conflict/);checks++;
 const beforeFailed=JSON.stringify(await state(db)),badId=crypto.randomUUID(),bad=revision(badId,'Rev.07','bad'),badModels=batch(badId);badModels[0].active='not-a-boolean';
 await assert.rejects(()=>rpc(db,bad,badModels,id1,JSON.parse(beforeFailed)),/invalid input syntax for type boolean/);checks++;
 expect(JSON.stringify(await state(db)),beforeFailed,'Failed insert rolls back all deactivations');expect((await db.query('SELECT count(*)::int n FROM public.ppl_checklist_revisions')).rows[0].n,1,'Failed insert rolls back revision row');
 const id2=crypto.randomUUID(),r2=revision(id2,'Rev.07','two'),m2=batch(id2),currentState=await state(db);await assert.rejects(()=>rpc(db,r2,m2,null,currentState),/revision_conflict/);checks++;
 const frozenState=await state(db),a=new Client(connection),b=new Client(connection);await a.connect();await b.connect();const id3=crypto.randomUUID(),r3=revision(id3,'Rev.08','three');
 try{const settled=await Promise.allSettled([rpc(a,r2,m2,id1,frozenState),rpc(b,r3,batch(id3),id1,frozenState)]);expect(settled.filter(r=>r.status==='fulfilled').length,1,'Concurrent writers have one winner');expect(settled.filter(r=>r.status==='rejected').length,1);expect(settled.find(r=>r.status==='rejected').reason.message.includes('revision_conflict'),true);}finally{await a.end();await b.end();}
 expect((await db.query('SELECT count(*)::int n FROM public.ppl_checklist_revisions')).rows[0].n,2);expect((await db.query('SELECT count(*)::int n FROM public.ppl_company_models WHERE active')).rows[0].n,45);
 expect((await db.query('SELECT model_id FROM public.ppl_company_models WHERE active GROUP BY model_id HAVING count(*)>1')).rows,[]);
 const currentModels=(await db.query('SELECT snapshot FROM public.ppl_company_models WHERE active ORDER BY model_id')).rows.map(r=>r.snapshot),currentSnapshot=currentModels[0];
 await assert.rejects(()=>db.query('SELECT public.ppl_hide_checklist_model_v59($1,$2,$3)',[cid,m1.find(m=>m.snapshot.id===currentSnapshot.id).snapshot,owner]),/revision_models_conflict/);checks++;
 const currentSnapshotBytes=JSON.stringify(currentSnapshot);await db.query('SELECT public.ppl_hide_checklist_model_v59($1,$2,$3)',[cid,currentSnapshot,owner]);
 expect((await db.query('SELECT count(*)::int n FROM public.ppl_company_models WHERE active')).rows[0].n,44,'Owner removal does not revive an older version');expect(JSON.stringify((await db.query('SELECT snapshot FROM public.ppl_company_models WHERE model_id=$1 AND version=$2',[currentSnapshot.id,currentSnapshot.version])).rows[0].snapshot),currentSnapshotBytes,'Owner removal preserves snapshot content');
 const id4=crypto.randomUUID(),r4=revision(id4,'Rev.09','four'),m4=batch(id4);m4.find(m=>m.snapshot.id===currentSnapshot.id).active=false;
 const head=(await db.query('SELECT id FROM public.ppl_checklist_revisions ORDER BY sequence DESC LIMIT 1')).rows[0].id,deleteTarget=currentModels[1],custom=await state(db),writer=new Client(connection),remover=new Client(connection);await writer.connect();await remover.connect();
 try{const settled=await Promise.allSettled([rpc(writer,r4,m4,head,custom),remover.query('SELECT public.ppl_hide_checklist_model_v59($1,$2,$3)',[cid,deleteTarget,owner])]);expect(settled.filter(r=>r.status==='fulfilled').length,1,'Publication and removal share the company lock');expect(settled.filter(r=>r.status==='rejected').length,1);expect(/revision_models_conflict/.test(settled.find(r=>r.status==='rejected').reason.message),true);}finally{await writer.end();await remover.end();}
 expect(JSON.stringify((await db.query('TABLE public.ppl_inspections')).rows),initialEvidence,'Inspection and PDF pointers untouched');
 const summary={passed:true,checks,realPostgreSQL:true,migrationRuns:2,syntheticOnly:true,features:['owner/PPL only','private table and RPC','immutable previous snapshots','CAS','concurrent publication','rollback after deactivation','one active revision','historical inspection preserved']};fs.writeFileSync(path.join(out,'resultado.json'),JSON.stringify(summary,null,2));console.log('PASS SQL59: '+checks+' checks; local PostgreSQL, two migration runs, permissions, concurrency and complete rollback.');console.log(out);
 }finally{if(db)await db.end();if(started)run('pg_ctl.exe',['-D',data,'-m','fast','-w','stop']);}
})().catch(e=>{console.error(e);process.exitCode=1;});
