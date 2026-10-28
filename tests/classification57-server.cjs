const assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
const {createHarness,ids}=require('./attention51-server.cjs');
const {harnessOptions,visualAssessment}=require('./visual57-server.cjs');
async function main(){const h=await createHarness(harnessOptions);let checks=0;const eq=(a,b)=>{assert.deepEqual(a,b);checks++;};
 const read=async r=>{const d=await r.json();eq(r.status,200);return d;};
 try{
  const cfg=(await read(await h.call('attention-rules-get',{},'OWNER'))).config;
  eq(cfg.individualMinimum,30);eq(cfg.habituation,6);eq(cfg.validation,'experimental');
  eq((await h.call('attention-rules-get',{},'MANAGER')).status,403);
  eq((await h.call('attention-rules-save',{config:cfg,expectedRevision:0},'MANAGER')).status,403);
  eq((await h.call('attention-rules-get',{},'')).status,401);
  const r=await read(await h.call('attention-rules-save',{config:cfg,expectedRevision:0},'OWNER'));eq(r.revision,1);
  eq((await h.call('attention-rules-save',{config:cfg,expectedRevision:0},'OWNER')).status,409);
  for(const config of [{...cfg,z2:cfg.z1},{...cfg,z1:-1},{...cfg,individualMinimum:1},{...cfg,validation:'validado'},{...cfg,unknown:1}])eq((await h.call('attention-rules-save',{config,expectedRevision:1},'OWNER')).status,400);
  const a=visualAssessment(),saved=await read(await h.call('attention-submit',{assessment:a},'OWNER'));
  eq(saved.assessment.metrics.classification.state,'base_em_formacao');eq(saved.assessment.metrics.classification.level,null);
  const metrics={...saved.assessment.metrics,antecipacoes:0,comissoes:0,declinio_ms:0};delete metrics.classification;
  const classify=async(m=metrics,status='completa',tech={})=>(await h.db.query('SELECT ppl_attention_classify_v57($1,$2,$3,$4,$5,$6,$7) c',[ids.company,ids.employee,randomUUID(),'2026-10-28T11:00:00Z',status,m,tech])).rows[0].c;
  eq((await classify({...metrics,respostas_validas:0})).level,'Comportamento Inseguro');
  eq((await classify(metrics,'incompleta')).state,'nao_interpretavel');
  eq((await classify(metrics,'completa',{multitouch:true})).eligible,false);
  eq((await classify({...metrics,maior_atraso_ms:251})).state,'qualidade_insuficiente');
  // Fixtures estatísticas exclusivamente neste banco descartável: não são avaliações reais.
  async function seed(person,company,n,job='CONDUTOR'){
   if(person!==ids.employee)await h.db.query('INSERT INTO ppl_employees(id,company_id,name,employee_number,job_title) VALUES($1,$2,$3,$4,$5)',[person,company,'SOMENTE TESTE',randomUUID(),job]);
   for(let i=0;i<n;i++){
    const m={...metrics,mediana_reacao_ms:i%2?300:100,classification:{eligible:true,state:'base_em_formacao'}};
    await h.db.query(`INSERT INTO ppl_attention_assessments(id,company_id,employee_id,employee_name,employee_number,job_title,employee_snapshot,unit,team,moment,started_at,finished_at,status,duration_ms,metrics,protocol_version,app_version,payload,created_by)
      VALUES($1,$2,$3,'SOMENTE TESTE','QA',$4,'{}','PORTO','MECÂNICA','inicio',$5,$5,'completa',0,$6,'visual-v1','TESTE','{}',$7)`,[randomUUID(),company,person,job,new Date(Date.UTC(2026,9,1,12,0,i)),m,ids.owner]);
   }
  }
  await seed(ids.employee,ids.company,36);
  eq((await classify()).state,'base_em_formacao');
  for(let i=0;i<5;i++)await seed(randomUUID(),ids.company,12);
  await seed(randomUUID(),ids.other,12);await seed(randomUUID(),ids.company,12,'OUTRO CARGO');
  for(const [value,level,z] of [[200,'Normal',0],[300,'Normal',1],[350,'Limítrofe',1.5],[450,'Alterado',2.5],[550,'Significativamente Alterado',3.5]]){
   const c=await classify({...metrics,mediana_reacao_ms:value});eq(c.level,level);eq(c.worstZ,z);eq(c.individualCount,30);eq(c.populationCount,30);eq(c.populationPeople,5);
   eq(c.scores.find(s=>s.parameter==='mediana_reacao_ms').mean,200);eq(c.scores.find(s=>s.parameter==='mediana_reacao_ms').sd,100);
  }
  const zero=await classify({...metrics,omissoes:metrics.omissoes+1});eq(zero.level,null);eq(zero.state,'referencia_insuficiente');
  const changed=await read(await h.call('attention-rules-save',{config:{...cfg,z1:2,z2:3,z3:4},expectedRevision:1},'OWNER'));eq(changed.revision,2);
  eq((await classify({...metrics,mediana_reacao_ms:350})).level,'Normal');
  const inserirReferencia=async(i,m)=>h.db.query(`INSERT INTO ppl_attention_assessments SELECT (jsonb_populate_record(NULL::ppl_attention_assessments,to_jsonb(a)||jsonb_build_object('id',gen_random_uuid(),'started_at',$2::timestamptz,'finished_at',$2::timestamptz,'metrics',$3::jsonb))).* FROM ppl_attention_assessments a WHERE id=$1`,[a.id,`2026-10-28T10:59:${String(i).padStart(2,'0')}Z`,m]);
  for(let i=0;i<3;i++)await inserirReferencia(i,{...metrics,classification:{eligible:true,state:'classificada',ruleVersion:2,level:'Alterado'}});
  const recurrence=await classify();eq(recurrence.recurrence.flag,true);eq(recurrence.level,'Normal');eq(recurrence.recurrence.count,3);
  await inserirReferencia(30,{...metrics,declinio_ms:null,classification:{eligible:true,state:'base_em_formacao'}});
  const missing=await classify();eq(missing.level,null);eq(missing.state,'referencia_insuficiente');eq(missing.scores.find(s=>s.reference==='individual'&&s.parameter==='declinio_ms').sampleCount,29);
  const original=await read(await h.call('attention-history-detail',{id:a.id,visualVersion:1},'OWNER'));eq(original.assessment.metrics.classification.ruleVersion,1);eq(original.assessment.metrics.classification.state,'base_em_formacao');
  await assert.rejects(()=>h.db.query('DELETE FROM ppl_attention_rules_v57'));checks++;
  console.log('PASS classificação57: '+checks+' verificações; cinco níveis, base ausente, habituação, duas bases, Gauss, limites, dispersão nula, isolamento, revisão e permissões.');
 }finally{await h.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
