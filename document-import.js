(()=>{
const loaders=new Map();
function script(src,global){if(window[global])return Promise.resolve();if(!loaders.has(src))loaders.set(src,new Promise((ok,no)=>{const s=document.createElement('script');s.src=src;s.onload=ok;s.onerror=()=>{loaders.delete(src);s.remove();no(Error('Não foi possível carregar o leitor. Conecte-se e tente novamente.'));};document.head.append(s);}));return loaders.get(src);}
window.PR_DOCUMENT_KIND=file=>{const ext=file.name.split('.').pop().toLowerCase();if(['png','jpg','jpeg','webp'].includes(ext))return 'photo';if(['pdf','xlsx','xls','docx'].includes(ext))return ext;throw Error('Escolha PDF, Excel (.xlsx ou .xls), Word (.docx) ou foto PNG, JPEG ou WebP.');};
window.PR_DOCUMENT_OCR=async(canvas,cancelled,progress)=>{
 await script('vendor/ocr/tesseract.min.js','Tesseract');let worker,timer;
 try{const run=async()=>{worker=await Tesseract.createWorker('por',1,{workerPath:new URL('vendor/ocr/worker.min.js',location.href).href,corePath:new URL('vendor/ocr/core/',location.href).href,langPath:new URL('vendor/ocr/lang',location.href).href,workerBlobURL:false,logger:m=>{if(!cancelled())progress('Leitura do PDF digitalizado: '+Math.round((m.progress||0)*100)+'%');}});if(cancelled())throw Error('Leitura cancelada.');await worker.setParameters({tessedit_pageseg_mode:3,user_defined_dpi:'300'});return (await worker.recognize(canvas)).data.text;};return await Promise.race([run(),new Promise((_,no)=>timer=setTimeout(()=>no(Error('A leitura demorou. Use páginas mais nítidas ou divida o PDF.')),180000))]);}finally{clearTimeout(timer);await worker?.terminate();}
};
window.PR_READ_DOCUMENT=async(file,progress=()=>{},recognize=async()=>{throw Error('Este PDF é digitalizado. Envie fotos das páginas para leitura.');})=>{
 const kind=PR_DOCUMENT_KIND(file),bytes=await file.arrayBuffer();if(bytes.byteLength>15000000)throw Error('O arquivo deve ter até 15 MB.');let result='';
 if(kind==='pdf'){
  const pdfjs=await import('./vendor/documents/pdf.min.mjs');pdfjs.GlobalWorkerOptions.workerSrc=new URL('vendor/documents/pdf.worker.min.mjs',location.href).href;
  const task=pdfjs.getDocument({data:new Uint8Array(bytes),isEvalSupported:false,stopAtErrors:true});let doc;
  try{doc=await task.promise;if(doc.numPages>80)throw Error('Importe no máximo 80 páginas por arquivo.');const parts=[];for(let n=1;n<=doc.numPages;n++){progress('Lendo página '+n+' de '+doc.numPages+'…');const page=await doc.getPage(n),content=await page.getTextContent();let lines=[],line='',lastY=null;for(const item of content.items){if(typeof item.str!=='string')continue;const y=item.transform[5];if(lastY!==null&&Math.abs(y-lastY)>3&&line){lines.push(line);line='';}line+=(line?' ':'')+item.str;lastY=y;if(item.hasEOL){lines.push(line);line='';lastY=null;}}if(line)lines.push(line);let text=lines.join('\n');if(text.replace(/\s/g,'').length<20){const viewport=page.getViewport({scale:Math.min(2,2200/Math.max(page.view[2],page.view[3]))}),canvas=document.createElement('canvas');canvas.width=Math.ceil(viewport.width);canvas.height=Math.ceil(viewport.height);await page.render({canvasContext:canvas.getContext('2d'),viewport}).promise;text=await recognize(canvas,n);}parts.push(text);page.cleanup();}result=parts.join('\n\n');}finally{await task.destroy();}
 }else if(kind==='xlsx'||kind==='xls'){
  await script('vendor/documents/xlsx.full.min.js','XLSX');const book=XLSX.read(bytes,{type:'array',cellFormula:false,cellHTML:false,cellStyles:false,bookVBA:false});if(book.SheetNames.length>80)throw Error('Importe no máximo 80 abas por arquivo.');result=book.SheetNames.map(name=>{progress('Lendo aba '+name+'…');return 'ABA: '+name+'\n'+XLSX.utils.sheet_to_csv(book.Sheets[name],{FS:' ',blankrows:false});}).join('\n\n');
 }else if(kind==='docx'){
  await script('vendor/documents/mammoth.browser.min.js','mammoth');result=(await mammoth.extractRawText({arrayBuffer:bytes})).value;
 }else throw Error('Use a leitura de foto para esta imagem.');
 if(!result.trim())throw Error('Nenhum texto encontrado. Confira o arquivo de origem.');if(result.length>1000000)throw Error('Conteúdo muito extenso. Divida o arquivo por checklist.');return {text:result,kind};
};
})();
