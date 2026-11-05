/* Owner-only import of a reviewed PPL Excel revision. No workbook macros are executed. */
(()=>{
 'use strict';
 const MAX_BYTES=14*1024*1024,MAX_SHEETS=80;
 const amount=(count,singular,plural)=>count+' '+(count===1?singular:plural);
 const plain=value=>String(value??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/\s+/g,' ').trim();
 const text=value=>String(value??'').replace(/\r\n?/g,'\n').trim();
 const cell=(sheet,column,row)=>text(sheet[column+row]?.v);
 const number=value=>/^\d+(?:[.,]\d+)?$/.test(text(value));
 function diffItems(before,after){const compare=value=>String(value||'').normalize('NFC').replace(/\s+/g,' ').trim(),index=items=>{const seen=new Map();return new Map(items.map((item,n)=>{const number=String(item.sourceNumber||n+1),ordinal=(seen.get(number)||0)+1;seen.set(number,ordinal);return [number+'#'+ordinal,item];}));},old=index(before),next=index(after);return {added:[...next].filter(([key])=>!old.has(key)).length,removed:[...old].filter(([key])=>!next.has(key)).length,changed:[...next].filter(([key,item])=>old.has(key)&&compare(old.get(key).text)!==compare(item.text)).length};}
 function parseWorkbook(book,rows,XLSX){
  if(!book?.SheetNames?.length||book.SheetNames.length>MAX_SHEETS)throw Error('O arquivo precisa conter entre 1 e 80 abas.');
  const bases=rows.filter(row=>row.active&&row.kind!=='inspection'&&row.snapshot?.id?.startsWith('ppl-')&&!row.snapshot.reportTemplate?.startsWith('ppl-ssma'));
  const models=[],ignored=[],errors=[],warnings=[],seen=new Set();
  for(const sourceSheet of book.SheetNames){
   const sheet=book.Sheets[sourceSheet];if(!sheet?.['!ref']){ignored.push(sourceSheet);continue;}
   const range=XLSX.utils.decode_range(sheet['!ref']);if(range.e.r>999||range.e.c>79){errors.push('Aba “'+sourceSheet+'”: área maior que o limite de leitura (1.000 linhas / 80 colunas).');continue;}
   let header=0;for(let row=1;row<=Math.min(range.e.r+1,50);row++)if(plain(cell(sheet,'A',row))==='ITEM'&&plain(cell(sheet,'C',row)).startsWith('ITENS INSPECIONADOS')){header=row;break;}
   if(!header){const hasTechnicalRows=Object.keys(sheet).some(address=>/^C\d+$/.test(address)&&/\?$/.test(cell(sheet,'C',Number(address.slice(1)))));if(plain(sourceSheet)!=='VERSO'&&hasTechnicalRows)errors.push('Aba “'+sourceSheet+'”: não reconheci as colunas Item / Itens inspecionados do formulário PPL.');else ignored.push(sourceSheet);continue;}
   const matches=bases.filter(row=>row.snapshot.source?.sheet===sourceSheet);
   if(matches.length!==1){errors.push('Aba “'+sourceSheet+'”: '+(matches.length?'há mais de um modelo ativo correspondente.':'não existe um checklist PPL ativo com esse nome de aba. Confira o cadastro antes de publicar.'));continue;}
   const base=matches[0].snapshot;if(seen.has(base.id)){errors.push('O modelo “'+base.title+'” está repetido no arquivo.');continue;}seen.add(base.id);
   let formCode='',legend='',category='Verificação do equipamento',stopped=false;const items=[],guidance=[];
   for(const address of Object.keys(sheet).filter(address=>!address.startsWith('!'))){const value=text(sheet[address]?.v),normalized=plain(value);if(!value)continue;if(/FMO[- ]/.test(normalized)&&!formCode&&Number(address.replace(/^[A-Z]+/,''))<10)formCode=value.replace(/\s+/g,' ');if(/^NAS INSPECOES MARQUE/.test(normalized)&&!legend)legend=value.replace(/\s+/g,' ');if(/^COD\.?\s*(?:DE\s+)?ACAO\s*:/i.test(normalized)||/^COD\.?\s*(?:DE\s+)?ACAO\s*[-–]/i.test(normalized))guidance.push(value);}
   for(let row=header+1;row<=range.e.r+1;row++){
    const index=cell(sheet,'A',row),question=cell(sheet,'C',row);if(/^ASSINATURA/i.test(plain(index))){stopped=true;break;}if(!number(index)||!question||/^[\s.·…-]+$/.test(question))continue;
    if(/\/\s*TAG\s*$/i.test(question)){category=question.replace(/\s*\/\s*TAG\s*$/i,'').trim();continue;}
    if(question.length>6000){errors.push('Aba “'+sourceSheet+'”, linha '+row+': texto técnico muito extenso.');continue;}
    items.push({sourceNumber:index.replace(',','.'),sourceRow:row,category,text:question});
   }
   if(!items.length||items.length>200)errors.push('Aba “'+sourceSheet+'”: informe de 1 a 200 itens técnicos preenchidos.');
   if(new Set(items.map(item=>item.sourceNumber)).size!==items.length)warnings.push('Aba “'+sourceSheet+'”: há números de itens repetidos na fonte. Todos os itens serão preservados na ordem das linhas.');
   if(!stopped)errors.push('Aba “'+sourceSheet+'”: não encontrei o encerramento da tabela pela assinatura.');
   if(!/FMO[- ]/.test(plain(formCode)))errors.push('Aba “'+sourceSheet+'”: código do formulário não identificado.');
   if(!plain(legend).includes('NAO CONFORME')||!plain(legend).includes('NAO SE APLICA'))errors.push('Aba “'+sourceSheet+'”: legenda C / NC / N/A não identificada.');
   if(!guidance.length)errors.push('Aba “'+sourceSheet+'”: orientações do código de ação não identificadas.');
   models.push({baseModelId:base.id,expectedVersion:String(base.version),sourceSheet,formCode,legend,guidance,items,title:base.title,diff:diffItems(base.items,items)});
  }
  if(errors.length)throw Error(errors.slice(0,12).join('\n')+(errors.length>12?'\n… e mais '+(errors.length-12)+' ocorrência(s).':''));
  if(!models.length)throw Error('Nenhum checklist PPL compatível foi encontrado. Use o Excel de revisão do formulário PPL.');
  return {models,ignored,warnings};
 }
 let xlsxLoad;
 async function loadXLSX(){if(window.XLSX)return window.XLSX;if(!xlsxLoad)xlsxLoad=new Promise((resolve,reject)=>{const script=document.createElement('script');script.src='vendor/documents/xlsx.full.min.js';script.onload=()=>resolve(window.XLSX);script.onerror=()=>{xlsxLoad=null;script.remove();reject(Error('Não foi possível carregar o leitor de Excel. Conecte-se e tente novamente.'));};document.head.append(script);});return xlsxLoad;}
 function base64(bytes){let result='';for(let offset=0;offset<bytes.length;offset+=32768)result+=String.fromCharCode(...bytes.subarray(offset,offset+32768));return btoa(result);}
 function mount(host,options){
  const {companyId,company,models=[],pplRevision=null,moduleVersion=0,isCurrent=()=>true,onPublished=()=>{}}=options;
  if(company?.slug!=='ppl'){host.replaceChildren();return {tab:'models',companyId,destroy(){},hasUnsaved:()=>false};}
  const E=PR.escape;let alive=true,epoch=0,busy=false,parsed=null,source=null,dirty=false;
  const active=expected=>alive&&expected===epoch&&isCurrent();
  host.innerHTML='<section class="platform-box ppl-revision-box"><h2>Revisões dos checklists PPL</h2><p>Importe o Excel revisado para atualizar as perguntas e o formulário dos próximos preenchimentos. Registros anteriores, PDFs, rascunhos e modelos Vale mantêm suas versões.</p><p class="ppl-revision-current">'+(pplRevision?'Revisão publicada: <strong>'+E(pplRevision.revision)+'</strong> · '+E(amount(pplRevision.modelCount,'modelo','modelos'))+' · '+E(new Date(pplRevision.createdAt).toLocaleDateString('pt-BR')):'Modelos atuais: revisão inicial do sistema.')+'</p><div class="ppl-revision-fields"><label>Excel PPL da nova revisão<input type="file" data-revision-file accept=".xls,.xlsx,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"></label><label>Identificação da revisão<input type="text" data-revision-label maxlength="80" placeholder="Ex.: Rev.06 — 04/11/2026" autocomplete="off"></label></div><p class="platform-note">A leitura acontece neste aparelho. Confira todas as abas e as alterações antes de publicar. Os modelos internos ativos recebem a revisão atual. Abas ausentes preservam as perguntas da última versão; versões antigas ficam apenas no histórico. Para preservar vínculos, mantenha os nomes das abas correspondentes.</p><p class="ppl-revision-state" data-revision-state role="status" aria-live="polite"></p><div data-revision-preview></div><label class="ppl-revision-review"><input type="checkbox" data-revision-reviewed disabled> Conferi as perguntas, a legenda e as orientações com o documento revisado.</label><div class="ppl-revision-actions"><button type="button" data-revision-publish disabled>Publicar nova revisão PPL</button><button type="button" data-revision-cancel>Limpar importação</button></div>'+(moduleVersion<59?'<p class="platform-note">A publicação será liberada após ativar a atualização 59 no servidor.</p>':'')+'</section>';
  const file=host.querySelector('[data-revision-file]'),label=host.querySelector('[data-revision-label]'),reviewed=host.querySelector('[data-revision-reviewed]'),publish=host.querySelector('[data-revision-publish]'),cancel=host.querySelector('[data-revision-cancel]'),notice=host.querySelector('[data-revision-state]'),preview=host.querySelector('[data-revision-preview]');
  const state=value=>{if(alive)notice.textContent=value;};
  function controls(){file.disabled=busy;label.disabled=busy;reviewed.disabled=busy||!parsed;publish.disabled=busy||moduleVersion<59||!parsed||!source||!reviewed.checked||!label.value.trim();cancel.disabled=busy;}
  function reset(){++epoch;parsed=null;source=null;dirty=false;file.value='';label.value='';reviewed.checked=false;preview.replaceChildren();state('');controls();}
  function showPreview(){
   const itemCount=parsed.models.reduce((sum,model)=>sum+model.items.length,0),total=parsed.models.reduce((result,model)=>({added:result.added+model.diff.added,removed:result.removed+model.diff.removed,changed:result.changed+model.diff.changed}),{added:0,removed:0,changed:0});
   preview.innerHTML='<div class="ppl-revision-summary"><strong>'+parsed.models.length+' checklists · '+itemCount+' itens</strong><span>'+total.added+' novos · '+total.changed+' alterados · '+total.removed+' retirados</span></div><p class="platform-note">Arquivo: '+E(source.filename)+'. '+(parsed.ignored.length?'Abas sem checklist ignoradas: '+E(parsed.ignored.map(name=>'“'+name+'”').join(', '))+'.':'')+'</p>'+parsed.warnings.map(warning=>'<p class="ppl-revision-warning">'+E(warning)+'</p>').join('')+parsed.models.map(model=>'<details class="ppl-revision-model"><summary>'+E(model.title)+' <span>'+amount(model.items.length,'item','itens')+' · '+model.diff.added+' novos / '+model.diff.changed+' alterados / '+model.diff.removed+' retirados</span></summary><p class="platform-note">Aba “'+E(model.sourceSheet)+'” · '+E(model.formCode)+' · versão atual '+E(model.expectedVersion)+'</p><ol>'+model.items.map(item=>'<li><strong>'+E(item.sourceNumber)+'.</strong> '+E(item.text)+'</li>').join('')+'</ol><p class="ppl-revision-legend">'+E(model.legend)+'</p>'+model.guidance.map(value=>'<p class="ppl-revision-guidance">'+E(value)+'</p>').join('')+'</details>').join('');
  }
  file.onchange=async()=>{
   const expected=++epoch;parsed=null;source=null;dirty=false;reviewed.checked=false;preview.replaceChildren();const selected=file.files[0];if(!selected){state('');controls();return;}
   busy=true;controls();state('Lendo a revisão do Excel…');
   try{
    const extension=selected.name.split('.').pop().toLowerCase();if(!['xls','xlsx'].includes(extension)||!selected.size||selected.size>MAX_BYTES)throw Error('Escolha um Excel .xls ou .xlsx de até 14 MB.');
    const buffer=await selected.arrayBuffer();if(!active(expected))return;const XLSX=await loadXLSX();if(!active(expected))return;
    const book=XLSX.read(buffer,{type:'array',cellFormula:false,cellHTML:false,cellStyles:false,bookVBA:false});const result=parseWorkbook(book,models,XLSX);const sha=await crypto.subtle.digest('SHA-256',buffer);if(!active(expected))return;
    source={filename:selected.name,sha256:[...new Uint8Array(sha)].map(value=>value.toString(16).padStart(2,'0')).join(''),base64:base64(new Uint8Array(buffer)),mime:extension==='xls'?'application/vnd.ms-excel':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'};parsed=result;dirty=true;showPreview();state('Arquivo lido. Informe a identificação da revisão e confira a prévia antes de publicar.');
   }catch(error){if(active(expected)){parsed=null;source=null;state(error.message);}}
   finally{if(active(expected)){busy=false;controls();}}
  };
  label.oninput=()=>{reviewed.checked=false;controls();};reviewed.onchange=controls;cancel.onclick=reset;
  publish.onclick=async()=>{
   if(busy||!parsed||!source||!reviewed.checked||!label.value.trim()||moduleVersion<59)return;
   const expected=epoch,revision=label.value.trim(),payload={companyId,expectedRevisionId:pplRevision?.id||null,revision,source,models:parsed.models.map(({title,diff,...model})=>model)};
   busy=true;controls();state('Publicando a revisão e preservando as versões anteriores…');
   try{const result=await PR.call('ppl-revision-publish',payload,true);if(!active(expected))return;dirty=false;parsed=null;source=null;busy=false;reviewed.checked=false;controls();state('Revisão '+result.revision+' publicada: '+result.modelCount+' checklists atualizados.');try{await onPublished(result);}catch(error){if(active(expected))state('Revisão '+result.revision+' publicada. Não foi possível atualizar a lista: '+error.message+' Recarregue a tela para consultar a revisão atual.');}}
   catch(error){if(active(expected))state('A revisão não foi confirmada: '+error.message+' Confira a conexão. A importação permanece disponível para tentar novamente.');}
   finally{if(active(expected)){busy=false;controls();}}
  };
  controls();
  return {tab:'models',companyId,destroy(){alive=false;++epoch;parsed=null;source=null;host.replaceChildren();},hasUnsaved:()=>dirty||busy};
 }
 window.PRPPLRevisions={mount,parseWorkbook,diffItems};
})();
