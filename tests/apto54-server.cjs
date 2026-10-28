/* Real disposable PostgreSQL, synthetic local records only. No production access. */
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {stripTypeScriptTypes}=require('node:module');
const {createHarness:baseHarness,assessment,ids,identities}=require('./attention51-server.cjs');
const root=path.resolve(__dirname,'..');
async function createHarness54(){
 const h=await baseHarness();
 try{
  // Match production's schema-qualified, fixed-search-path access helper.
  await h.db.query("CREATE OR REPLACE FUNCTION public.ppl_can_read_company(c uuid,u text,t text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT public.ppl_attention_actor_allowed_v51(auth.uid(),c,u,t) $$");
  const sql=fs.readFileSync(path.join(root,'supabase/executantes-v54/attention-followup.sql'),'utf8');await h.db.query(sql);await h.db.query(sql);
  const fragment=fs.readFileSync(path.join(root,'supabase/executantes-v54/attention-followup.fragment.ts'),'utf8');
  class RequestError extends Error{constructor(message,status=400){super(message);this.status=status;}}
  const context={RequestError,Date,Number,Response,uuid:v=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v),fail:message=>{throw new RequestError(message);}};
  vm.createContext(context);
  const fragmentCall=vm.runInContext(stripTypeScriptTypes(`(async function(b,selected,scoped){const respond=(value,status=200)=>Response.json(value,{status});${fragment}\nthrow Error('Unknown action');})`,{mode:'transform'}),context);
  h.call54=async(action,body={},token='OWNER')=>{
   if(!['attention-dashboard-list','attention-followup-detail','attention-followup-save'].includes(action))return h.call(action,body,token);
   if(!identities[token])return Response.json({error:'Faça login.'},{status:401});
   const b={action,companyId:ids.company,...body},authorized=await h.db.query("SELECT 1 FROM ppl_access p WHERE user_id=$1 AND active AND(role='owner' OR EXISTS(SELECT 1 FROM ppl_company_access ca WHERE ca.user_id=p.user_id AND ca.company_id=$2 AND ca.active))",[identities[token],b.companyId]);
   if(!authorized.rowCount)return Response.json({error:'Empresa fora do seu acesso.'},{status:403});
   const scoped={rpc:async(name,params)=>{try{const keys=Object.keys(params),result=await h.scoped('SELECT public.'+name+'('+keys.map((key,i)=>key+'=>$'+(i+1)).join(',')+') AS value',Object.values(params),token);return{data:result.rows[0].value,error:null};}catch(error){return{data:null,error};}}};
   try{return await fragmentCall(b,{id:b.companyId},scoped);}catch(error){return Response.json({error:error.message},{status:error.status||500});}
  };
  return h;
 }catch(error){await h.close();throw error;}
}
async function main(){
 const h=await createHarness54();let checks=0;
 const check=(actual,expected)=>{assert.deepEqual(actual,expected);checks++;};
 const read=async response=>{const data=await response.json();check(response.status,200);return data;};
 try{
  check((await h.call54('attention-dashboard-list',{},'')).status,401);
  const empty=await read(await h.call54('attention-dashboard-list'));check(empty.summary,{total:0,complete:0,incomplete:0,people:0,untracked:0,open:0,inProgress:0,concluded:0});check(empty.rows,[]);
  const a=assessment(),b=assessment({unit:'FERROVIA',status:'incompleta',durationMs:0,touches:[],finishedAt:'2026-10-24T12:00:00Z'});
  await read(await h.call('attention-submit',{assessment:a}));await read(await h.call('attention-submit',{assessment:b}));
  for(let i=0;i<53;i++)await read(await h.call('attention-submit',{assessment:assessment({startedAt:'2026-10-24T14:00:00Z',finishedAt:'2026-10-24T14:00:05.200Z'})}));
  const snapshot=(await h.db.query('SELECT payload FROM ppl_attention_assessments WHERE id=$1',[a.id])).rows[0].payload;
  const all=await read(await h.call54('attention-dashboard-list'));check(all.rows.length,50);check(all.summary.total,55);check(all.summary.complete,54);check(all.summary.incomplete,1);check(all.nextOffset,50);
  const next=await read(await h.call54('attention-dashboard-list',{offset:50}));check(next.rows.length,5);check(next.nextOffset,null);check(next.summary.total,55);
  check((await read(await h.call54('attention-dashboard-list',{},'RESTRICTED'))).summary.total,54);
  check((await read(await h.call54('attention-dashboard-list',{employeeNumber:'QA-1',dateFrom:'2026-10-24',dateTo:'2026-10-24',status:'incompleta'}))).summary.total,1);
  check((await read(await h.call54('attention-dashboard-list',{employeeNumber:'QA'}))).summary.total,0);
  check((await h.call54('attention-dashboard-list',{dateFrom:'2026-02-30'})).status,400);
  check((await h.call54('attention-dashboard-list',{dateFrom:'2026-10-25',dateTo:'2026-10-24'})).status,400);
  check((await h.call54('attention-dashboard-list',{status:'apto'})).status,400);
  check((await h.call54('attention-dashboard-list',{followupStatus:'invalid'})).status,400);
  check((await h.call54('attention-dashboard-list',{companyId:ids.other},'MANAGER')).status,403);
  check((await h.call54('attention-followup-detail',{id:b.id},'RESTRICTED')).status,404);
  check((await h.call54('attention-followup-save',{id:b.id,status:'aberta',note:'Providência de teste',expectedRevision:0},'RESTRICTED')).status,404);
  const before=await read(await h.call54('attention-followup-detail',{id:a.id}));check(before.current,null);check(before.events,[]);
  const first=await read(await h.call54('attention-followup-save',{id:a.id,status:'aberta',note:'Orientação operacional de teste',expectedRevision:0}));check(first.current.revision,1);check(first.current.actor_id,ids.owner);check(first.events.length,1);
  check((await h.call54('attention-followup-save',{id:a.id,status:'concluida',note:'Conflito de teste',expectedRevision:0})).status,409);
  const concurrent=await Promise.all(['Atualização A','Atualização B'].map(note=>h.call54('attention-followup-save',{id:a.id,status:'em_andamento',note,expectedRevision:1},'MANAGER')));check(concurrent.map(r=>r.status).sort(),[200,409]);
  const history=await read(await h.call54('attention-followup-detail',{id:a.id}));check(history.events.length,2);check(history.current.revision,2);
  const done=await read(await h.call54('attention-followup-save',{id:a.id,status:'concluida',note:'Providência concluída no teste',expectedRevision:2}));check(done.events.length,3);
  const filtered=await read(await h.call54('attention-dashboard-list',{followupStatus:'concluida'}));check(filtered.summary.total,1);check(filtered.summary.concluded,1);check(filtered.rows[0].followup_revision,3);
  check((await h.db.query('SELECT payload FROM ppl_attention_assessments WHERE id=$1',[a.id])).rows[0].payload,snapshot);
  await assert.rejects(()=>h.scoped('INSERT INTO ppl_attention_followup_events_v54(company_id,assessment_id,revision,status,note,actor_id,actor_name) VALUES($1,$2,4,$3,$4,$5,$6)',[ids.company,a.id,'aberta','Inserção indevida',ids.owner,'QA'],'OWNER'));checks++;
  await assert.rejects(()=>h.db.query('UPDATE ppl_attention_followup_events_v54 SET note=$1',['Alteração indevida']));checks++;
  await assert.rejects(()=>h.db.query('DELETE FROM ppl_attention_followup_events_v54'));checks++;
  const outside=await h.scoped('SELECT * FROM ppl_attention_followup_events_v54 WHERE assessment_id=$1',[b.id],'RESTRICTED');check(outside.rows,[]);
  await h.db.query('UPDATE ppl_access SET active=false WHERE user_id=$1',[ids.manager]);check((await h.call54('attention-followup-save',{id:a.id,status:'aberta',note:'Acesso revogado',expectedRevision:3},'MANAGER')).status,403);
  fs.writeFileSync(path.join(h.out,'apto54-summary.json'),JSON.stringify({checks,passed:true,migrationRuns:2,realPostgreSQL:true,syntheticLocalRecords:55,productionWrites:0},null,2));
  console.log('PASS apto54 server: '+checks+' verificações, SQL real/RLS, filtros/total55/página50, auditoria append-only, concorrência e imutabilidade. '+h.out);
 }finally{await h.close();}
}
module.exports={createHarness54,assessment,ids};
if(require.main===module)main().catch(error=>{console.error(error);process.exitCode=1;});
