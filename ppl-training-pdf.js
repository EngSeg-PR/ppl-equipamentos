/* Vector layout for PPL training documents. Original evidence attachments remain immutable. */
window.PRTrainingPDF=(()=>{
 const clean=x=>String(x??'').normalize('NFC').replace(/[\u2010-\u2015]/g,'-').replace(/[“”]/g,'"').replace(/[‘’]/g,"'").replace(/[^\u0020-\u007e\u00a0-\u00ff\n]/g,'');
 const date=x=>/^\d{4}-\d{2}-\d{2}$/.test(x||'')?x.split('-').reverse().join('/'):clean(x);
 async function make(template,values,trace,participants=[]){
  const {PDFDocument,StandardFonts,rgb}=PDFLib,doc=await PDFDocument.create(),regular=await doc.embedFont(StandardFonts.Helvetica),bold=await doc.embedFont(StandardFonts.HelveticaBold),black=rgb(.04,.09,.12),gray=rgb(.94,.95,.96),green=rgb(.55,.8,.28),extra=[];
  const response=await fetch('assets/ppl-logo-oficial.png');if(!response.ok)throw Error('Logo PPL indisponível.');const logo=await doc.embedPng(await response.arrayBuffer());
  const wrap=(value,font,size,width)=>{const lines=[];for(const para of clean(value).split('\n')){let line='';for(const word of para.split(/\s+/)){if(!word)continue;const parts=font.widthOfTextAtSize(word,size)>width?[...word]:[word];for(const part of parts){const next=line?line+(parts.length===1?' ':'')+part:part;if(font.widthOfTextAtSize(next,size)>width&&line){lines.push(line);line=part;}else line=next;}}lines.push(line);}return lines;};
  function text(page,b,value,{size=9,min=7,font=regular,align='left',justify=false,label='',vertical='center'}={}){
   value=clean(value);if(!value)return;let lines;for(;size>=min;size-=.25){lines=wrap(value,font,size,b.w-8);if(lines.length*size*1.18-size*.18<=b.h-(b.h<16?2:4))break;}
   if(size<min){extra.push((label||'Campo')+': '+value);value='['+extra.length+']';size=Math.min(9,b.h-4);lines=[value];}
   const height=lines.length*size*1.18-size*.18,top=vertical==='top'?b.y+3:b.y+(b.h-height)/2;
   lines.forEach((line,i)=>{const width=font.widthOfTextAtSize(line,size),x=align==='center'?b.x+(b.w-width)/2:b.x+4,y=page.getHeight()-top-size-i*size*1.18;
    if(justify&&i<lines.length-1&&line.includes(' ')){const words=line.split(' '),sum=words.reduce((n,w)=>n+font.widthOfTextAtSize(w,size),0),gap=(b.w-8-sum)/(words.length-1);let cursor=b.x+4;for(const word of words){page.drawText(word,{x:cursor,y,size,font,color:black});cursor+=font.widthOfTextAtSize(word,size)+gap;}}
    else page.drawText(line,{x,y,size,font,color:black});
   });
  }
  function box(page,x,y,w,h,fill){page.drawRectangle({x,y:page.getHeight()-y-h,width:w,height:h,borderWidth:.55,borderColor:black,...(fill?{color:fill}:{})});return {x,y,w,h};}
  async function signature(page,b,data){if(!data)return;const im=await doc.embedPng(data),scale=Math.min((b.w-10)/im.width,(b.h-4)/im.height),w=im.width*scale,h=im.height*scale;page.drawImage(im,{x:b.x+(b.w-w)/2,y:page.getHeight()-b.y-b.h+(b.h-h)/2,width:w,height:h});}
  function drawLogo(page,b){const scale=Math.min(b.w/logo.width,b.h/logo.height),w=logo.width*scale,h=logo.height*scale;page.drawImage(logo,{x:b.x+(b.w-w)/2,y:page.getHeight()-b.y-b.h+(b.h-h)/2,width:w,height:h});}
  const W=841.89,H=595.28,M=17,usable=W-2*M;
  if(template.type==='attendance'){
   const syllabus=clean(values.syllabus),programLines=wrap(syllabus,regular,8.4,usable-153),programHeight=Math.min(112,Math.max(56,programLines.length*10+8));
   const tableTop=139+programHeight,headerHeight=18,rowHeight=20,rowsPerPage=Math.max(1,Math.floor((H-60-tableTop-headerHeight)/rowHeight)),pageCount=Math.max(1,Math.ceil(participants.length/rowsPerPage));
   for(let sheet=0;sheet<pageCount;sheet++){
    const page=doc.addPage([W,H]);const header=box(page,M,15,usable,40);box(page,M,15,135,40);drawLogo(page,{x:M+8,y:20,w:119,h:29});text(page,{x:M+135,y:15,w:usable-278,h:40},'LISTA DE PRESENÇA',{font:bold,size:12,align:'center'});box(page,W-M-143,15,143,40);text(page,{x:W-M-140,y:18,w:137,h:15},'FMG-GP-01-05',{font:bold,size:8});text(page,{x:W-M-140,y:35,w:137,h:13},'Rev. 12',{size:8});
    box(page,M,61,usable,18);text(page,{x:M,y:61,w:142,h:18},'Tipo de treinamento:',{font:bold,size:8});const types=['Integração','Gestão','Operacional','Requisito Legal','Requisito do Cliente','Campanha'],tw=(usable-143)/6;types.forEach((type,n)=>{const x=M+143+n*tw,b={x,y:66,w:6,h:6};box(page,b.x,b.y,b.w,b.h);if(values.type===type){page.drawLine({start:{x:b.x+1,y:H-b.y-1},end:{x:b.x+5,y:H-b.y-5},thickness:.9,color:black});page.drawLine({start:{x:b.x+1,y:H-b.y-5},end:{x:b.x+5,y:H-b.y-1},thickness:.9,color:black});}text(page,{x:x+8,y:61,w:tw-9,h:18},type,{size:7.1,min:6.8});});
    box(page,M,79,usable,20);text(page,{x:M,y:79,w:115,h:20},'Unidade de trabalho:',{size:8,font:bold});text(page,{x:M+115,y:79,w:229,h:20},values.unit==='PELOTIZAÇÃO'?'PELOTIZAÇÃO - UPSL':values.unit,{size:8.5,label:'Unidade'});text(page,{x:M+345,y:79,w:112,h:20},'Data da realização:',{size:8,font:bold});text(page,{x:M+457,y:79,w:100,h:20},date(values.date),{size:8.5,align:'center'});text(page,{x:M+560,y:79,w:94,h:20},'Carga horária:',{size:8,font:bold});text(page,{x:M+654,y:79,w:usable-654,h:20},values.hours?String(values.hours).replace('.',',')+' h':'',{size:8.5,align:'center'});
    box(page,M,99,usable,20);text(page,{x:M,y:99,w:191,h:20},'Nome / tema principal do treinamento:',{font:bold,size:7.8});text(page,{x:M+191,y:99,w:usable-191,h:20},values.title,{font:bold,size:9,min:7,label:'Tema'});
    box(page,M,119,usable,programHeight);text(page,{x:M,y:119,w:146,h:programHeight},'Conteúdo programático / documentos abordados:',{size:8,font:bold});text(page,{x:M+147,y:119,w:usable-147,h:programHeight},syllabus,{size:8.4,min:8,justify:true,vertical:'top',label:'Conteúdo programático'});
    const py=119+programHeight;for(const [offset,width,label,value] of [[0,295,'Nome do procedimento',values.procedureName],[295,215,'Código',values.procedureCode],[510,125,'Revisão conferida',values.procedureRevision],[635,usable-635,'Data da revisão',date(values.procedureDate)]]){box(page,M+offset,py,width,20,gray);text(page,{x:M+offset,y:py,w:width,h:10},label,{font:bold,size:6.1,min:6});text(page,{x:M+offset,y:py+10,w:width,h:10},value,{size:7.5,min:6.5,label});}
    const cols=[{key:'number',label:'Nº',w:28},{key:'employee_number',label:'Matrícula',w:83},{key:'name',label:'Nome completo',w:255},{key:'job_title',label:'Função',w:150},{key:'signature',label:'Assinatura',w:usable-516}];let cx=M;for(const c of cols){box(page,cx,tableTop,c.w,headerHeight,gray);text(page,{x:cx,y:tableTop,w:c.w,h:headerHeight},c.label,{font:bold,size:8,align:'center'});cx+=c.w;}
    const slice=participants.slice(sheet*rowsPerPage,(sheet+1)*rowsPerPage);for(let n=0;n<rowsPerPage;n++){let x=M;const person=slice[n],top=tableTop+headerHeight+n*rowHeight;for(const c of cols){const b=box(page,x,top,c.w,rowHeight);if(person){if(c.key==='signature')await signature(page,b,values.participantSignatures?.[person.id]?.data);else text(page,b,c.key==='number'?String(sheet*rowsPerPage+n+1):person[c.key],{size:8,min:7,align:c.key==='number'?'center':'left',label:'Participante '+(sheet*rowsPerPage+n+1)+' / '+c.label});}x+=c.w;}}
    const fy=H-50;box(page,M,fy,usable/2,29);box(page,M+usable/2,fy,usable/2,29);text(page,{x:M,y:fy,w:56,h:29},'Instrutor:',{font:bold,size:8});text(page,{x:M+56,y:fy,w:usable/2-56,h:29},values.instructor,{size:8.5,label:'Instrutor'});const sb={x:M+usable/2+70,y:fy+1,w:usable/2-140,h:20};await signature(page,sb,values.instructorSignature?.data);page.drawLine({start:{x:sb.x,y:H-fy-21},end:{x:sb.x+sb.w,y:H-fy-21},thickness:.6,color:black});text(page,{x:sb.x,y:fy+21,w:sb.w,h:8},'Assinatura do instrutor',{size:6,min:6,align:'center'});
    text(page,{x:M,y:H-18,w:usable,h:12},'Página '+(sheet+1)+' de '+pageCount+' · '+(values.status==='Realizado'?'Realização declarada':'Planejado - presenças a confirmar'),{size:7,align:'center'});
   }
  }else{
   const page=doc.addPage([W,H]),c=template.certificateContent;page.drawRectangle({x:35,y:45,width:W-70,height:H-90,borderWidth:5,borderColor:green});
   text(page,{x:56,y:65,w:W-112,h:45},c.subject,{font:bold,size:15,min:12,align:'center'});text(page,{x:56,y:109,w:W-112,h:16},'SEGURANÇA DO TRABALHO, SAÚDE OCUPACIONAL E MEIO AMBIENTE | SSMA',{font:bold,size:7.6,align:'center'});
   const raw=String(values.cpf||'').replace(/\D/g,''),cpf=raw.length===11?raw.replace(/(\d{3})(\d{3})(\d{3})(\d{2})/,'$1.$2.$3-$4'):clean(values.cpf||'');
   const statement='Certificamos que '+clean(values.name||values.nameReceipt)+', '+(cpf?'CPF '+cpf+', ':'')+c.intro;
   text(page,{x:58,y:141,w:W-116,h:89},statement,{size:10.5,min:9,justify:true,vertical:'top',label:'Declaração do certificado'});
   text(page,{x:58,y:240,w:W-116,h:17},'Conteúdo programático',{font:bold,size:10});text(page,{x:58,y:260,w:W-116,h:112},c.syllabus,{size:9.3,min:8.5,justify:true,vertical:'top',label:'Conteúdo programático do certificado'});
   for(const [x,name,sig,label] of [[94,values.instructorName,values.instructorSignature,'Instrutor / responsável'],[454,values.nameReceipt||values.name,values.workerSignature,'Participante']]){const b={x,y:391,w:294,h:41};await signature(page,b,sig);page.drawLine({start:{x,y:H-433},end:{x:x+294,y:H-433},thickness:.65,color:black});text(page,{x,y:437,w:294,h:24},name,{size:9,min:7.5,align:'center',label});text(page,{x,y:463,w:294,h:14},label,{size:8,align:'center'});}
   text(page,{x:58,y:505,w:350,h:20},'Data do treinamento: '+date(values.date),{size:9});drawLogo(page,{x:W-190,y:492,w:128,h:48});
  }
  // Append provenance and full values that could not fit without reducing legibility.
  let page=doc.addPage([595.28,841.89]),y=62;const heading=()=>text(page,{x:32,y:25,w:531,h:27},'IDENTIFICAÇÃO E RASTREABILIDADE',{font:bold,size:14});heading();const details=clean(trace).replace(/\b\d{4}-\d{2}-\d{2}\b/g,date)+(extra.length?'\n\nCOMPLEMENTOS DOS CAMPOS\n'+extra.map((x,n)=>'['+(n+1)+'] '+x).join('\n\n'):'');for(const line of wrap(details,regular,9.5,523)){if(y>788){page=doc.addPage([595.28,841.89]);heading();y=62;}text(page,{x:32,y,w:531,h:15},line,{size:9.5,min:9.5});y+=15;}
  doc.setTitle(template.title);return new Blob([await doc.save()],{type:'application/pdf'});
 }
 return {make,dateLabel:date};
})();
