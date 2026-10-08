// Public device-local library. Does not grant access to the management panel.
let pendingView=false,pendingRefresh=0;
async function pendingInspections(records,readReceipt){
 const registered=records.filter(r=>r.status==='recorded');
 const rows=await Promise.all(registered.map(async record=>{let receipt;try{receipt=await readReceipt(record.key);}catch{}return {record,receipt};}));
 return rows.filter(x=>!x.receipt?.received_at||x.receipt.pdf_ready===false).sort((a,b)=>(b.record.recordedAt||b.record.updatedAt).localeCompare(a.record.recordedAt||a.record.updatedAt));
}
const originalShowChecklist=showChecklist;
showChecklist=function(){pendingView=false;pendingRefresh++;originalShowChecklist();$('#pending-nav').classList.remove('selected');};
async function showPending(){
 if(busy)return;
 const request=++pendingRefresh;
 pendingView=true;managementMode(false);$('#checklist-nav').classList.remove('selected');$('#pending-nav').classList.add('selected');$('#overview').hidden=true;
 $('.page-heading h2').textContent='Pendentes';$('.page-heading p').textContent='Inspeções e PDFs salvos neste aparelho, aguardando confirmação de envio.';
 const host=$('#workspace');host.innerHTML='<div class="panel"><p role="status">Consultando inspeções deste aparelho…</p></div>';
 try{
  const rows=await pendingInspections(await all(),key=>window.PPL_LOCAL_RECEIPT?.(key));
  if(!pendingView||request!==pendingRefresh)return;
  host.innerHTML=`<div class="panel"><h2>Inspeções pendentes (${rows.length})</h2><p>Abra a inspeção ou gere e salve o PDF mesmo sem internet. O envio ao painel de gestão será retomado automaticamente quando houver conexão.</p><div class="actions"><button type="button" class="primary" id="cloud-sync" ${window.PPL_PENDING_ENABLED?'':'disabled'}>Enviar pendentes</button><button type="button" id="pending-refresh">Atualizar lista</button></div></div>${rows.map(({record:r,receipt},index)=>`<article class="panel"><h3>${index===0?'Última inspeção pendente · ':''}${esc(equipmentLabel(r))}</h3><p><strong>${esc(r.fields.belt)}</strong><br>${esc(r.fields.inspector)} · matrícula ${esc(r.fields.employee)}<br>${localTime(r.recordedAt||r.updatedAt)}</p><p>${receipt?.received_at?'Inspeção recebida pelo servidor; PDF pendente de envio.':'Pendente de sincronização com o painel de gestão.'}</p><p>PDF: ${r.pdfStatus==='ready'?'cópia disponível neste navegador':'pode ser gerado a partir do registro salvo'}.</p><small>ID ${esc(r.id)} · revisão ${r.revision}</small><div class="actions"><button type="button" data-pending-open="${esc(r.key)}">Ver inspeção</button><button type="button" class="primary" data-pending-pdf="${esc(r.key)}">Ver / salvar PDF</button></div></article>`).join('')}${rows.length?'':'<div class="panel"><p>Não há inspeções pendentes neste navegador.</p><p>Registros confirmados continuam em Registros e backup. Inspeções de outro aparelho não aparecem nesta aba local.</p></div>'}`;
  $('#pending-refresh').onclick=showPending;
  $('#cloud-sync').onclick=()=>window.PPL_SEND_PENDING?.();
  host.querySelectorAll('[data-pending-open]').forEach(b=>b.onclick=()=>openPendingInspection(b.dataset.pendingOpen,false));
  host.querySelectorAll('[data-pending-pdf]').forEach(b=>b.onclick=()=>openPendingInspection(b.dataset.pendingPdf,true));
 }catch(error){if(pendingView&&request===pendingRefresh)host.innerHTML='<div class="panel"><p class="error">Não foi possível consultar os registros locais: '+esc(storageError(error))+'. Não limpe os dados do navegador.</p><button type="button" id="pending-retry">Tentar novamente</button></div>';const retry=$('#pending-retry');if(retry)retry.onclick=showPending;}
}
async function openPendingInspection(key,pdf){
 if(busy)return;
 try{const record=await getRecord(key);if(!record){message('Registro não encontrado neste navegador.',true);return;}current=record;const preparation=render();const back=document.createElement('button');back.type='button';back.textContent='Voltar para Pendentes';back.onclick=showPending;$('#workspace').prepend(back);message('Inspeção preservada neste aparelho. Você pode consultar e salvar o PDF sem internet.');if(pdf){await preparation;$('#pdf-output')?.scrollIntoView({behavior:'smooth',block:'center'});}}
 catch(error){message('Não foi possível abrir o registro: '+storageError(error),true);}
}
$('#pending-nav').onclick=showPending;
window.addEventListener('ppl-cloud-received',()=>{if(pendingView&&!busy)showPending();});
document.addEventListener('click',event=>{if(event.target.closest('#management-nav')){pendingView=false;pendingRefresh++;$('#pending-nav').classList.remove('selected');}},true);
