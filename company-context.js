window.PRContext={company:null,employees:[],models:[],kind:'checklist'};
window.PPL_CONTEXT_READY=(async()=>{
 const slug=new URLSearchParams(location.search).get('company')||'ppl';
 let context;
 try{context=await PR.context(slug);}
 catch(error){
  // Restore only static branding/models, never a denied employee directory.
  let cached;try{cached=JSON.parse(localStorage.getItem('pr-context:'+slug));}catch{}
  context={company:cached?.company||null,models:cached?.models||[],defaults:cached?.defaults||{},employees:[],
   accessDenied:true,executorAccessRequired:true,moduleVersion:54,localReadOnly:true,errorMessage:error.message};
 }
 Object.assign(PRContext,context,{slug});
 if(context.company)PRContext.company={...context.company,defaults:context.defaults||context.company.defaults||{}};
 const registry=MODEL_REGISTRY;
 for(const m of context.models||[])if(!registry.some(x=>x.id===m.snapshot.id&&x.version===m.snapshot.version))registry.push(m.snapshot);
 try{for(let n=0;n<localStorage.length;n++){const key=localStorage.key(n);if(key?.startsWith('pr-context:')){const cached=JSON.parse(localStorage.getItem(key));for(const m of cached.models||[])if(!registry.some(x=>x.id===m.snapshot.id&&x.version===m.snapshot.version))registry.push(m.snapshot);}}}catch{}
 window.PRExecutor?.configure(PRContext,slug);
 const base=EQUIPMENT_CATALOG.map(x=>({...x}));
 window.PRSelectKind=kind=>{
  PRContext.kind=kind;
  const available=(context.models||[]).filter(m=>m.active&&m.kind===kind),entries=available.map(m=>base.find(x=>x.modelId===m.snapshot.id)||{id:m.snapshot.id,name:m.snapshot.equipmentName||m.snapshot.title,modelId:m.snapshot.id});
  if(slug==='ppl'&&kind==='checklist')entries.push(...base.filter(x=>!x.modelId));
  entries.sort((a,b)=>a.name.localeCompare(b.name,'pt-BR'));
  EQUIPMENT_CATALOG.splice(0,EQUIPMENT_CATALOG.length,...entries);
 };
 PRSelectKind('checklist');
 if(context.company){
  const logo=document.querySelector('header .brand img');logo.src=context.company.logoData;logo.alt=context.company.name;
  document.querySelector('header .brand').href='company.html?company='+encodeURIComponent(slug);
  document.querySelector('aside .eyebrow').textContent=context.company.name+' · EXECUTANTE';
  const title=document.querySelector('.header-title');title.firstChild.textContent=context.company.name;
  document.title=context.company.name+' · Executante';
 }
 return PRContext;
})();
