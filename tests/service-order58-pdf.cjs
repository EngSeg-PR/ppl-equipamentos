/* Generated QA documents are fictitious and never sent to production. */
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const PDFLib=require('../vendor/pdf-lib.min.js');
const root=path.resolve(__dirname,'..'),out=path.resolve(process.env.PRS_QA_OUTPUT||path.join(root,'../qa-os58/rendered'));
const logo=fs.readFileSync(path.join(root,'assets/ppl-logo-oficial.png'));
const catalog=JSON.parse(fs.readFileSync(path.join(root,'ppl-documents-catalog.json'),'utf8'));
const template=catalog.find(t=>t.type==='service-order'&&t.serviceOrderContent&&!t.retired)||catalog.find(t=>t.id==='certificates-4-v2');
let recording;
const PDFDocument={async create(){
 const doc=await PDFLib.PDFDocument.create(),addPage=doc.addPage.bind(doc),embedPng=doc.embedPng.bind(doc);
 doc.addPage=(...args)=>{const page=addPage(...args),drawText=page.drawText.bind(page);const number=doc.getPageCount();page.drawText=(text,options)=>{recording.text.push({text,x:options.x,y:options.y,size:options.size,width:options.font.widthOfTextAtSize(text,options.size),page:number});return drawText(text,options);};return page;};
 doc.embedPng=(...args)=>{recording.pngEmbeds++;return embedPng(...args);};
 return doc;
}};
const scope={window:{},PDFLib:{...PDFLib,PDFDocument},Blob,fetch:async url=>{assert.equal(url,'assets/ppl-logo-oficial.png');return new Response(logo);}};
new Function('window','PDFLib','Blob','fetch',fs.readFileSync(path.join(root,'ppl-service-order-pdf.js'),'utf8'))(scope.window,scope.PDFLib,scope.Blob,scope.fetch);
const description='Realiza o tratamento mecânico da superfície a ser pintada, utilizando a pistola de agulha e a lixadeira, faz todo tratamento necessário antes\nde fazer a\naplicação da tinta, através da pistola de pintura, rolo ou pincel.';
// Synthetic pen strokes, never a real person's signature.
const syntheticSignature='iVBORw0KGgoAAAANSUhEUgAAAQQAAABGCAYAAAAq7+rZAAAC4ElEQVR4nO3d0W3bMBSGUTvQAN6jc3TqztE9skEKo8gtEDSBHVsi/8tzngr0RbLIj7Tk2Oe3t7cTwNWLlwF4JwhAEQSgCAJQBAEoggAUQQCKIABFEIAiCEARBKAIAlAEASiCABRBAIogAEUQiHD58dM3+Rzg7BuTSArB6+9f53FH01/bHYIVJf/6uYbHa7lDsKrk+ioCdgf7206NWFF6XbtrAFzTY7UJwmcDx6qSGYKP/+c6HiM+CFaQfiFgnK1zDAyw3BDYHYyxdXt7YMcwJzuCDFvXGNgd5D71cR3HiQqCVebva5ASO49/80R8DuGWJwidV5W0ED5yvJ2vY4LpdwirPk5MvBeSFi6CgnBPCDqtKok3TJ8Vgk7XMdWUQVhtV5D6lsiOoJ8tPQQzTpTu0dsjBKnXsZtpgpA8QVb5wx07gv625IGWsKqkR+CIECRcx1UMDULXXcGzIzBqwtgRrPcZlGFBeOZgmyUgXQJ3ZAjsDv5v1BOlLXXSzPIIrksEruwIjjfLOB4ShC6Tp8t5jA7BaruDy52Tf8RrsiVOoBEDadTNwT3P1Y5g3Yk/LAjJq2mHJwSzhqDL7uASPPkPDcJeIdh7IHWNwCwhSHa5Y/Knvq67BCFxV5B4zKkhmH13cGm26g8Nwp6D79kDafYIPHq+s4VgRitP/l2DMPvkSjvOrl9OMtOHrL7yOsnrFRmEIybZIwOp832BlBAcyeQfFISZV9uVIpDy9mCP3cEKN/oignBkDG4dSJ0i8Mg5p53rLaz6kwZhxl3BjMe0t7QQ3LM7MPlDgjBi4n02kFaMQGIIvmLihwdh9G8frBqB9BB8PPZbQpBybt1862vYj/ptgFV/qq3beXe6t9Pdt24qjryIKw+g1HN/31mmHv9Kpv+hlhUHks8SMMr0QVjViiFkPEEAysu/fwKrEwSgCAJQBAEoggAUQQCKIABFEIAiCEARBKAIAlAEASiCABRBAE7v/gA9zFy/alZa/AAAAABJRU5ErkJggg==';
const values=Object.freeze({unit:'PELOTIZAÇÃO - UPSL',cnpj:'12.345.678/0001-90',name:'COLABORADOR FICTÍCIO PARA VERIFICAÇÃO DO LAYOUT',nameReceipt:'COLABORADOR FICTÍCIO PARA VERIFICAÇÃO DO LAYOUT',job_title:'FUNÇÃO FICTÍCIA DE VERIFICAÇÃO',employee_number:'QA-OS-58',date:'2026-11-03',description,workerSignature:'data:image/png;base64,'+syntheticSignature,signatureMode:'No sistema'});
const before=JSON.stringify(values),trace='HOMOLOGAÇÃO LOCAL - NÃO É DOCUMENTO REAL\nID QA-OS-58\nModelo '+template.id;
async function generate(name,v,options){
 recording={text:[],pngEmbeds:0};const blob=await scope.window.PRServiceOrderPDF.make(template,v,trace,options);const bytes=Buffer.from(await blob.arrayBuffer()),doc=await PDFLib.PDFDocument.load(bytes);assert.equal(bytes.subarray(0,5).toString(),'%PDF-');assert(bytes.length>10000);
 const result={name,pages:doc.getPageCount(),bytes:bytes.length,...recording};fs.writeFileSync(path.join(out,name+'.pdf'),bytes);return result;
}
(async()=>{
 fs.mkdirSync(out,{recursive:true});
 const digital=await generate('os58-assinatura-digital',values),paper=await generate('os58-para-impressao',values,{print:true}),paperMode=await generate('os58-assinatura-em-papel',{...values,signatureMode:'Em papel'});
 assert.equal(digital.pngEmbeds,2,'Signed copy retains signature image');assert.equal(paper.pngEmbeds,1,'Print copy contains logo only, without signature image');assert.equal(paperMode.pngEmbeds,1,'Paper mode also omits signature');
 assert.equal(JSON.stringify(values),before,'Generating a paper copy must not mutate historical values/signature');
 for(const result of [digital,paper,paperMode]){
  const heading=result.text.findIndex(x=>x.text==='DESCRIÇÃO DA ATIVIDADE'),next=result.text.findIndex((x,n)=>n>heading&&x.text==='RISCO POTENCIAL');assert(heading>=0&&next>heading);
  const lines=result.text.slice(heading+1,next);assert(lines.some(x=>x.text==='de fazer a'),'Short manual paragraph is one naturally spaced line');
  assert(lines.every(x=>x.x===31),'Activity description is left aligned');
  assert(lines.every(x=>x.width<=533.28+.1),'Description fits inside its content area');
  assert(result.text.some(x=>x.text.includes(values.name)),'Participant name retained');assert(result.text.some(x=>x.text==='03/11/2026'),'Brazilian date retained');
 }
 assert(!digital.text.some(x=>x.text.includes('pendente de coleta')));
 assert(paper.text.some(x=>x.text==='Assinatura em papel - pendente de coleta'));
 assert(paper.text.some(x=>x.text.includes('Situação: aguardando coleta.')));
 const long=await generate('os58-descricao-extensa',{...values,description:('Descrição fictícia completa para conferir paginação e preservar todas as informações. ').repeat(150)+'FIM INTEGRAL DA DESCRIÇÃO'}, {print:true});
 assert(long.pages>paper.pages);assert(long.text.some(x=>x.text.includes('FIM INTEGRAL DA DESCRIÇÃO')));
 fs.writeFileSync(path.join(out,'verificacao-pdf58.json'),JSON.stringify({passed:true,files:[digital,paper,paperMode,long].map(({text,...result})=>result),leftAlignedDescription:true,shortParagraphNoForcedSpaces:true,originalValuesPreserved:true,signedOriginalRetainsImage:true,printCopyWithoutSignature:true,longDescriptionComplete:true},null,2));
 console.log('PASS OS58 PDF: descrição alinhada sem espaços forçados, cópia física sem assinatura e original preservado, conteúdo extenso integral. '+out);
})().catch(error=>{console.error(error);process.exitCode=1;});
