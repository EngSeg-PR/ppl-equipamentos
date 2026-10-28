/* Somente dados sintéticos em PostgreSQL descartável. Nunca produção. */
const assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
const {createHarness,assessment,ids}=require('./attention51-server.cjs');
const harnessOptions={sourceFile:'supabase/visual-v57/ppl-api-dashboard.ts',migrations:['supabase/executantes-v54/ATIVAR-v54.sql','supabase/acesso-v55/ATIVAR-v55.sql','supabase/visual-v57/CLASSIFICACAO-v57.sql','supabase/visual-v57/ATIVAR-v57.sql']};
function visualAssessment(overrides={}) {
 const schedule=Array.from({length:30},(_,i)=>({kind:i%5===4?'nogo':'go',waitMs:800,position:i%3}));
 const trials=schedule.map((s,i)=>({seq:i+1,shownMs:800+i*2000,closedMs:1800+i*2000}));
 const responses=[{tMs:200,source:'pointer'},...trials.filter(t=>schedule[t.seq-1].kind==='go').map(t=>({tMs:t.shownMs+200,source:'pointer'})),{tMs:8850,source:'keyboard'}].sort((a,b)=>a.tMs-b.tMs).map((r,i)=>({seq:i+1,...r}));
 return {id:randomUUID(),employeeId:ids.employee,unit:'PORTO',team:'MECÂNICA',moment:'inicio',startedAt:'2026-10-28T12:00:00.000Z',finishedAt:'2026-10-28T12:00:59.800Z',durationMs:59800,status:'completa',schedule,trials,responses,technical:{runtime:'web',width:390,height:844,pixelRatio:1},interruption:null,protocolVersion:'visual-v1',appVersion:'0.3.0',...overrides};
}
async function test() {
 const h=await createHarness(harnessOptions);let checks=0;
 const eq=(a,b)=>{assert.deepEqual(a,b);checks++;};
 const read=async r=>{const d=await r.json();assert.equal(r.status,200,JSON.stringify(d));checks++;return d;};
 const own=(a,b={},token='')=>h.call(a,b,'',token);
 const submit=(a,token)=>own('attention-employee-submit',{assessment:a},token);
 try {
 const login=await read(await own('executor-login',{employeeId:ids.employee,password:'QA-1'})),token=login.executorToken;
 const a=visualAssessment();const result=await read(await submit(a,token));eq(result.moduleVersion,57);
 const m=result.assessment.metrics;
 eq(m.respostas_validas,24);eq(m.omissoes,0);eq(m.comissoes,1);eq(m.fora_estimulo,1);eq(m.toques_extras,0);
 eq(m.media_reacao_ms,200);eq(m.mediana_reacao_ms,200);eq(m.dp_reacao_ms,0);eq(m.p10_reacao_ms,200);eq(m.p90_reacao_ms,200);eq(m.quartos_media_ms,[200,200,200,200]);eq(m.maior_atraso_ms,0);
 eq((await read(await submit(a,token))).status,'duplicada');
 eq((await submit({...a,responses:[]},token)).status,409);
 const partial=visualAssessment({status:'incompleta',durationMs:1000,finishedAt:'2026-10-28T12:00:01Z',trials:[{seq:1,shownMs:800,closedMs:null}],responses:[],interruption:'Tela saiu de foco'});
 const p=await read(await submit(partial,token));eq(p.assessment.metrics.omissoes,0);eq(p.assessment.metrics.media_reacao_ms,null);
 const empty=visualAssessment({status:'incompleta',durationMs:0,finishedAt:'2026-10-28T12:00:00Z',trials:[],responses:[],technical:{}});
 await read(await submit(empty,token));
 const micro=visualAssessment({status:'incompleta',durationMs:1801,finishedAt:'2026-10-28T12:00:01.801Z',trials:[{seq:1,shownMs:800,shownUs:800123,closedMs:1801}],responses:[{seq:1,tMs:1000,tUs:1000456,source:'pointer'}]});
 eq((await read(await submit(micro,token))).assessment.metrics.media_reacao_ms,200.3);
 const omitted=visualAssessment({responses:[]});eq((await read(await submit(omitted,token))).assessment.metrics.omissoes,24);
 const invalid=[
  {durationMs:90001},{status:'incompleta'},{trials:a.trials.slice(1)},
  {schedule:a.schedule.slice(1)},{schedule:a.schedule.map(s=>({...s,kind:'go'}))},
  {schedule:a.schedule.map(s=>({...s,waitMs:799}))},
  {trials:[{seq:1,shownMs:799,closedMs:1799},...a.trials.slice(1)]},
  {trials:[{...a.trials[0],closedMs:null},...a.trials.slice(1)]},
  {responses:[{seq:1,tMs:-1,source:'pointer'}]},
  {responses:[{seq:1,tMs:900,source:'pointer'},{seq:2,tMs:800,source:'pointer'}]},
  {responses:[{seq:1,tMs:900,source:'robot'}]},
  {metrics:{respostas_validas:999}},{technical:{cpf:'não permitido'}},
  {technical:{runtime:'web',width:-1,height:844,pixelRatio:1}},
  {finishedAt:'2026-10-28T12:00:59.000Z'},
 ];
 for(const change of invalid)eq((await submit(visualAssessment(change),token)).status,400);
 eq((await submit(visualAssessment({employeeId:ids.owner}),token)).status,403);
 eq((await own('attention-employee-submit',{companyId:ids.other,assessment:visualAssessment()},token)).status,401);
 eq((await submit(visualAssessment(),'')).status,401);
 await read(await h.call('attention-submit',{assessment:visualAssessment()},'RESTRICTED'));
 eq((await h.call('attention-submit',{assessment:visualAssessment({unit:'FERROVIA'})},'RESTRICTED')).status,403);
 eq((await h.call('attention-submit',{companyId:ids.other,assessment:visualAssessment()},'MANAGER')).status,403);
 eq((await h.call('attention-history-detail',{id:a.id},'MANAGER')).status,426);
 const detail=await read(await h.call('attention-history-detail',{id:a.id,visualVersion:1},'MANAGER'));eq(detail.assessment.trials,a.trials);eq(detail.assessment.responses,a.responses);
 const hist=await read(await own('attention-employee-history',{includeVisual:true},token));eq(hist.rows.every(r=>r.employee_id===ids.employee),true);eq(hist.rows.length,6);
 eq((await read(await own('attention-employee-history',{},token))).rows.length,0);
 const old=assessment();await read(await submit(old,token));eq((await read(await h.call('attention-history-detail',{id:old.id},'OWNER'))).assessment.grid,old.grid);
 eq((await read(await h.call('attention-dashboard-list',{},'OWNER'))).summary.total,7);
 for(const role of ['OWNER','MANAGER',null]) {
  if(role)await assert.rejects(()=>h.scoped('SELECT ppl_attention_visual_submit_v57($1,$2,$3,$4)',[ids.company,ids.employee,true,a],role));
  else await assert.rejects(()=>h.db.query('SET ROLE anon').then(()=>h.db.query('SELECT ppl_attention_visual_submit_v57($1,$2,$3,$4)',[ids.company,ids.employee,true,a])).finally(()=>h.db.query('RESET ROLE')));
  checks++;
 }
 await assert.rejects(()=>h.db.query('DELETE FROM ppl_attention_assessments WHERE id=$1',[a.id]));checks++;
 console.log('PASS visual57: '+checks+' verificações; métricas recalculadas, isolamento, eventos inválidos, repetição, protocolo antigo e gestão.');
 } finally {await h.close();}
}
module.exports={harnessOptions,visualAssessment};if(require.main===module)test().catch(e=>{console.error(e);process.exitCode=1;});
