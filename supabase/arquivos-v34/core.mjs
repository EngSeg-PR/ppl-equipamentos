export class RequestError extends Error { constructor(message,status=400){super(message);this.status=status;} }
export function canonical(value){
 if(Array.isArray(value))return '['+value.map(canonical).join(',')+']';
 if(value&&typeof value==='object')return '{'+Object.keys(value).sort().map(k=>JSON.stringify(k)+':'+canonical(value[k])).join(',')+'}';
 return JSON.stringify(value);
}
const fail=message=>{throw new RequestError(message);};
export function normalizeRecord(input,models){
 if(!input||typeof input!=='object'||Array.isArray(input))fail('Registro inválido.');
 const r=structuredClone(input);delete r.syncStatus;delete r.pdfStatus;
 if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(r.id)||!Number.isInteger(r.revision)||r.revision<1||r.revision>10000||r.key!==`${r.id}:${r.revision}`||r.status!=='recorded')fail('Identificação ou revisão inválida.');
 const model=models.find(m=>m.id===r.model?.id&&m.version===r.model?.version);
 if(!model||canonical(model)!==canonical(r.model))fail('Modelo não reconhecido. Atualize o aplicativo ou revise a migração.');
 if(!r.fields||typeof r.fields!=='object')fail('Campos ausentes.');
 for(const [k,v] of Object.entries(r.fields))if(typeof v!=='string'||v.length>10000||k.length>100)fail('Campo inválido.');
 for(const k of ['type','date','belt','inspector','employee'])if(!r.fields[k]?.trim())fail('Preencha os campos obrigatórios.');
 if(!model.types.includes(r.fields.type))fail('Tipo de inspeção inválido.');
 const day=new Date(r.fields.date+'T12:00:00Z');
 const today=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Fortaleza',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
 if(!/^\d{4}-\d{2}-\d{2}$/.test(r.fields.date)||!Number.isFinite(day.valueOf())||day.toISOString().slice(0,10)!==r.fields.date||r.fields.date>today)fail('Data de inspeção inválida.');
 if(r.revision>1&&!r.fields.reason?.trim())fail('Informe o motivo da revisão.');
 for(const field of model.identifiers||[]){if(field.required&&!r.fields[field.name]?.trim())fail('Identificação complementar ausente.');if(field.type==='date'&&r.fields[field.name]){const value=r.fields[field.name],d=new Date(value+'T12:00:00Z');if(!/^\d{4}-\d{2}-\d{2}$/.test(value)||!Number.isFinite(d.valueOf())||d.toISOString().slice(0,10)!==value||value>today)fail('Data complementar inválida.');}}
 const image=value=>typeof value==='string'&&value.length<6000000&&/^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/]+={0,2}$/.test(value);
 const photo=p=>!!p&&typeof p.name==='string'&&p.name.length<=500&&image(p.data)&&Number.isFinite(Date.parse(p.createdAt));
 if(!r.signature||r.signature.kind!=='drawn-electronic'||!image(r.signature.data)||!Number.isFinite(Date.parse(r.signature.createdAt))||!photo(r.workerPhoto))fail('Foto do colaborador e assinatura são obrigatórias.');
 if(!Array.isArray(r.answers)||r.answers.length!==model.items.length)fail('Itens incompletos.');
 let photos=0;
 for(let i=0;i<model.items.length;i++){
  const a=r.answers[i];
  if(a.itemId!==model.items[i].id||!['Conforme','Não Conforme','Não Aplicável'].includes(a.value)||typeof a.notes!=='string'||a.notes.length>10000||!Array.isArray(a.photos))fail('Resposta inválida.');
  if(model.reportLayout?.type==='excel-original'){const item=model.items[i];if(!item.choices.includes(a.sourceValue))fail('Resposta original do checklist inválida.');if(item.boxes.answer){if(a.sourceValue==='NA'&&a.value!=='Não Aplicável')fail('Classificação incompatível com resposta original.');if(a.sourceValue!=='NA'&&a.value==='Não Aplicável')fail('Classificação incompatível com resposta original.');}else{const expected=['Conforme','Não Conforme','Não Aplicável'].includes(a.sourceValue)?a.sourceValue:item.nonConformingValues.includes(a.sourceValue)?'Não Conforme':'Conforme';if(a.value!==expected)fail('Classificação diverge da resposta original.');}}if(a.value==='Não Aplicável'&&!a.notes.trim())fail('Justifique Não Aplicável.');
  if(a.photos.length>3)fail('Limite de três fotos por item.');
  for(const p of a.photos){if(!photo(p))fail('Evidência inválida.');photos++;}
 }
 if(photos>model.items.length*3)fail('Quantidade de evidências inválida.');
 if(!Number.isFinite(Date.parse(r.recordedAt)))fail('Horário declarado inválido.');
 return r;
}
export function allows(profile,scopes,unit,team){return !!profile?.active&&(profile.role==='owner'||(profile.role==='manager'&&scopes.some(s=>s.unit===unit&&s.team===team)));}
export function managerInput(input){
 const email=String(input.email||'').trim().toLowerCase(),name=String(input.name||'').trim(),password=String(input.password||'');
 if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||!name||name.length>150||password.length<12||password.length>128)fail('Informe nome, e-mail e senha de 12 a 128 caracteres.');
 const scopes=input.scopes;
 if(!Array.isArray(scopes)||!scopes.length||scopes.length>100||scopes.some(s=>!s||typeof s.unit!=='string'||typeof s.team!=='string'||!s.unit.trim()||!s.team.trim()||s.unit.length>150||s.team.length>150))fail('Informe ao menos uma unidade/equipe válida.');
 return {email,name,password,scopes:[...new Map(scopes.map(s=>{const v={unit:s.unit.trim(),team:s.team.trim()};return [JSON.stringify(v),v];})).values()]};
}
