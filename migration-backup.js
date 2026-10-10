/* Portable backup of the selected company's local inspections and exact PDF bytes. */
(()=>{
 const button=document.querySelector('#backup'),restore=document.querySelector('#restore');if(!button||!restore)return;
 const legacyRestore=restore.onchange;
 async function digest(bytes){return [...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(x=>x.toString(16).padStart(2,'0')).join('');}
 function encode(bytes){let s='';for(let i=0;i<bytes.length;i+=32768)s+=String.fromCharCode(...bytes.subarray(i,i+32768));return btoa(s);}
 button.textContent='Backup com inspeções e PDFs';
 button.onclick=async()=>{if(busy)return;busy=true;button.disabled=true;try{
  const records=await all(),pdfs=[];for(const r of records){if(r.status!=='recorded')continue;let blob;try{blob=cachedPDFBlob(await transaction('pdfs','readonly',s=>s.get(r.key)));}catch{}if(!blob&&pdfMemory.has(r.key))blob=new Blob([pdfMemory.get(r.key)],{type:'application/pdf'});if(blob){const bytes=new Uint8Array(await blob.arrayBuffer());pdfs.push({key:r.key,base64:encode(bytes),sha256:await digest(bytes)});}}
  const data={format:'ppl-local-backup',schema:2,exportedAt:stamp(),origin:location.origin,companyId:window.PRContext?.company?.id||null,records,pdfs,management:await transaction('management','readonly',s=>s.getAll()),missingPDFs:records.filter(r=>r.status==='recorded'&&!pdfs.some(p=>p.key===r.key)).map(r=>r.key)};
  const json=JSON.stringify(data),blob=new Blob([json],{type:'application/json'});if(blob.size>100*1024*1024)throw Error('Backup excede 100 MB. Preserve os arquivos e solicite uma exportação dividida antes de migrar.');
  download(json,'application/json','PRS-backup-inspecoes-PDFs-'+dateToday()+'.json');message(`Backup preparado: ${records.length} registros e ${pdfs.length} PDFs originais desta empresa. ${data.missingPDFs.length} registros sem cópia PDF local disponível. Guarde o arquivo antes de trocar de endereço.`);
 }catch(e){message('Backup não concluído: '+e.message,true);}finally{busy=false;button.disabled=false;}};
 restore.onchange=async event=>{if(busy)return;const file=event.target.files[0];if(!file)return;let data;try{if(file.size>100*1024*1024)throw Error('Backup maior que 100 MB.');data=JSON.parse(await file.text());}catch(e){message('Restauração: '+e.message,true);restore.value='';return;}
  if(data.schema!==2){await legacyRestore(event);return;}busy=true;
  try{
   if(data.format!=='ppl-local-backup'||!Array.isArray(data.records)||!data.records.every(validImport)||!Array.isArray(data.pdfs)||new Set(data.records.map(r=>r.key)).size!==data.records.length)throw Error('Backup inválido ou modelo incompatível.');
   const company=window.PRContext?.company;if(data.companyId&&company?.id!==data.companyId)throw Error('Selecione a mesma empresa do backup antes de restaurar.');
   if(company&&data.records.some(r=>r.company?r.company.id!==company.id:company.slug!=='ppl'))throw Error('Backup contém registros de outra empresa.');
   if(data.management!==undefined&&(!Array.isArray(data.management)||!data.management.every(r=>validManagementBackup('management',r))))throw Error('Histórico local inválido.');
   const verified=[],keys=new Set();for(const pdf of data.pdfs){if(keys.has(pdf.key)||!data.records.some(r=>r.key===pdf.key&&r.status==='recorded')||typeof pdf.base64!=='string'||!/^[A-Za-z0-9+/]+={0,2}$/.test(pdf.base64)||!/^[a-f0-9]{64}$/.test(pdf.sha256))throw Error('PDF sem vínculo válido.');keys.add(pdf.key);const bytes=Uint8Array.from(atob(pdf.base64),c=>c.charCodeAt(0));if(new TextDecoder().decode(bytes.slice(0,5))!=='%PDF-'||await digest(bytes)!==pdf.sha256)throw Error('PDF corrompido ou alterado; restauração interrompida.');const old=cachedPDFBlob(await transaction('pdfs','readonly',s=>s.get(pdf.key)));if(old&&await digest(await old.arrayBuffer())!==pdf.sha256)throw Error('Já existe outro PDF para esta revisão. Nenhum arquivo será sobrescrito.');verified.push({key:pdf.key,bytes:bytes.buffer});}
   const existing=new Map((await all()).map(r=>[r.key,r]));for(const r of data.records){const old=existing.get(r.key);if(old&&recordContent(old)!==recordContent(r))throw Error('Registro existente difere do backup. Nenhum registro será sobrescrito.');}
   for(const row of data.management||[]){const old=await transaction('management','readonly',s=>s.get(row.key));if(old&&JSON.stringify(old)!==JSON.stringify(row))throw Error('Histórico local existente difere do backup. Nenhum registro será sobrescrito.');}
   let added=0;for(const r of data.records){if(!existing.has(r.key)){const row=structuredClone(r);row.pdfStatus='pending';row.syncStatus='local-only';await put(row);added++;}}
   for(const row of verified){await transaction('pdfs','readwrite',s=>s.put(row));const r=await getRecord(row.key);r.pdfStatus='ready';await put(r);}
   for(const row of data.management||[]){const old=await transaction('management','readonly',s=>s.get(row.key));if(!old)await transaction('management','readwrite',s=>s.put(row));}
   await list();message(`Restaurados ${added} novos registros e preservados ${verified.length} PDFs originais. Registros iguais foram mantidos. O recebimento central será conferido novamente.`);
  }catch(e){message('Restauração não concluída: '+e.message+'. Preserve o backup; uma nova tentativa mantém os registros já restaurados.',true);}finally{busy=false;restore.value='';}
 };
})();
