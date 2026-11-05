/* PPL monthly equipment sheet. Source questions and recorded evidence are immutable inputs. */
window.PRPPLChecklistPDF=(()=>{
 'use strict';
 const clean=value=>String(value??'').normalize('NFC').replace(/[\u2010-\u2015]/g,'-').replace(/[“”]/g,'"').replace(/[‘’]/g,"'").replace(/\t/g,' ').replace(/[^\u0020-\u007e\u00a0-\u00ff\n]/g,'?');
 const date=value=>/^\d{4}-\d{2}-\d{2}$/.test(value||'')?value.split('-').reverse().join('/'):clean(value);
 const clock=value=>{try{return new Intl.DateTimeFormat('pt-BR',{dateStyle:'short',timeStyle:'medium',timeZone:'America/Fortaleza'}).format(new Date(value));}catch{return clean(value);}};
 const answerCode=value=>({'Conforme':'C','Não Conforme':'NC','Não Aplicável':'N/A'})[value]||'';
 async function make(r){
  if(r?.model?.reportLayout?.type!=='ppl-equipment-table')throw Error('Modelo PPL de equipamentos incompatível.');
  const {PDFDocument,StandardFonts,rgb}=PDFLib,doc=await PDFDocument.create(),font=await doc.embedFont(StandardFonts.Helvetica),bold=await doc.embedFont(StandardFonts.HelveticaBold),ink=rgb(0,0,0),gray=rgb(.94,.94,.94),white=rgb(1,1,1);
  const layout=r.model.reportLayout,fields=r.fields||{},items=r.model.items||[],answers=r.answers||[],W=841.89,H=595.28,M=22,U=W-2*M,footerTop=H-123;
  if(items.length!==answers.length)throw Error('As respostas não correspondem ao modelo preservado.');
  if(!/^\d{4}-\d{2}-\d{2}$/.test(fields.date||''))throw Error('Data da inspeção inválida.');
  const [year,month,day]=fields.date.split('-').map(Number),calendarDate=new Date(Date.UTC(year,month-1,day));
  if(calendarDate.getUTCFullYear()!==year||calendarDate.getUTCMonth()!==month-1||calendarDate.getUTCDate()!==day)throw Error('Data da inspeção inválida.');
  for(const answer of answers)if(!answerCode(answer.value))throw Error('O checklist possui resposta não preenchida.');
  let page,y,tablePages=[],legendOverflow=false,guidanceOverflow=false;
  const wrap=(value,size,width,f=font)=>{const lines=[];for(const paragraph of clean(value).split('\n')){let line='';for(const word of paragraph.trim().split(/\s+/)){if(!word)continue;const whole=f.widthOfTextAtSize(word,size)<=width,parts=whole?[word]:[...word];for(const part of parts){const candidate=line?line+(whole?' ':'')+part:part;if(f.widthOfTextAtSize(candidate,size)>width&&line){lines.push(line);line=part;}else line=candidate;}}lines.push(line);}return lines;};
  const text=(value,x,top,size=7,f=font,width=0,align='left')=>{const line=clean(value),dx=align==='center'?(width-f.widthOfTextAtSize(line,size))/2:align==='right'?width-f.widthOfTextAtSize(line,size):0;page.drawText(line,{x:x+dx,y:page.getHeight()-top-size,size,font:f,color:ink});};
  const rect=(x,top,w,h,fill)=>page.drawRectangle({x,y:page.getHeight()-top-h,width:w,height:h,borderWidth:.5,borderColor:ink,...(fill?{color:fill}:{})});
  const linesText=(lines,x,top,size,leading=1.2,f=font)=>lines.forEach((line,n)=>text(line,x,top+n*size*leading,size,f));
  async function image(data){if(typeof data!=='string')throw Error('Imagem de evidência indisponível.');if(data.startsWith('data:image/png;'))return doc.embedPng(data);if(/^data:image\/(?:jpeg|jpg);/.test(data))return doc.embedJpg(data);throw Error('Formato de imagem de evidência não suportado.');}
  let logo;if(r.company?.logoData)logo=await image(r.company.logoData);else{const response=await fetch('assets/ppl-logo-oficial.png');if(!response.ok)throw Error('Logo PPL indisponível no aparelho.');logo=await doc.embedPng(await response.arrayBuffer());}
  const drawLogo=(x,top,w,h)=>{const scale=Math.min(w/logo.width,h/logo.height);page.drawImage(logo,{x:x+(w-logo.width*scale)/2,y:page.getHeight()-top-h+(h-logo.height*scale)/2,width:logo.width*scale,height:logo.height*scale});};
  const equipment=layout.equipmentName||r.model.equipmentName||r.equipmentType?.name||r.model.title;
  function metadata(cells){const specifications=cells.map(([label,value,width])=>({label,lines:wrap(value,7.2,width-10),width})),height=Math.max(26,...specifications.map(s=>13+s.lines.length*8.5));let x=M;for(const spec of specifications){rect(x,y,spec.width,height);text(spec.label,x+5,y+3,6.1,bold);linesText(spec.lines,x+5,y+13,7.2,1.18);x+=spec.width;}y+=height;}
  function sheet(continued=false){
   page=doc.addPage([W,H]);tablePages.push(page);rect(M,18,U,44);rect(M,18,105,44);drawLogo(M+6,23,93,33);rect(W-M-89,18,89,44);
   const title=wrap(layout.documentTitle||'CHECK LIST DIÁRIO DE MÁQUINAS E EQUIPAMENTOS',10.2,U-210,bold);title.forEach((line,n)=>text(line,M+109,27+n*12,10.2,bold,U-202,'center'));
   const code=clean(layout.formCode||'').replace(layout.revision?/\s+REV\.?\s*\d+.*$/i:/$^/,'').trim(),revision=layout.revision?(/^(?:rev\b|modelo\b)/i.test(layout.revision)?clean(layout.revision):'REV. '+clean(layout.revision)):'';
   let codeLines=[...wrap(code,6.7,81,bold),...(revision?wrap(revision,6.7,81,bold):[])];if(codeLines.length*8.1>40){codeLines=['CÓDIGO / REVISÃO','Ver identificação anexa'];}const codeTop=18+(44-codeLines.length*8.1)/2;codeLines.forEach((line,n)=>text(line,W-M-85,codeTop+n*8.1,6.7,bold,81,'center'));
   y=67;metadata([['Unidade de Trabalho',fields.unit,U*.49],['Mês',String(month).padStart(2,'0'),U*.14],['Ano',String(year),U*.14],['Equipe',fields.team,U*.23]]);
   metadata([['Responsável pela Inspeção',fields.inspector,U*.40],['Equipamento',equipment,U*.36],['TAG / Placa',fields.belt,U*.24]]);
   if(continued){rect(M,y,U,14,gray);text('CONTINUAÇÃO - MESMO REGISTRO E MESMA DATA',M+5,y+3,6.8,bold);y+=14;}
   y+=5;tableHeader();
  }
  const columns=[27,304,40],dayWidth=(U-columns.reduce((sum,w)=>sum+w,0))/31,dayStart=M+columns.reduce((sum,w)=>sum+w,0);
  function tableHeader(){let x=M;for(const [n,label]of ['Item','Itens Inspecionados','Cód. de Ação'].entries()){rect(x,y,columns[n],29,gray);const lines=wrap(label,n===2?6:7,columns[n]-6,bold),size=n===2?6:7;lines.forEach((line,i)=>text(line,x+3,y+(29-lines.length*size*1.15)/2+i*size*1.15,size,bold,columns[n]-6,'center'));x+=columns[n];}rect(dayStart,y,dayWidth*31,14,gray);text('Dias do Mês',dayStart,y+3,7,bold,dayWidth*31,'center');for(let d=1;d<=31;d++){rect(dayStart+(d-1)*dayWidth,y+14,dayWidth,15,d===day?gray:white);text(String(d),dayStart+(d-1)*dayWidth,y+18,6.1,bold,dayWidth,'center');}y+=29;}
  function foot(){
   const height=27,x=dayStart+(day-1)*dayWidth;rect(M,footerTop,dayStart-M,height);text('Assinatura do Responsável pela inspeção',M+5,footerTop+8,7,bold);
   for(let d=1;d<=31;d++)rect(dayStart+(d-1)*dayWidth,footerTop,dayWidth,height,d===day?gray:undefined);
   text(r.signature?.data?'A':'-',x,footerTop+8,7,bold,dayWidth,'center');
   text('A: assinatura e identificação na folha anexa. Colunas vazias: sem registro neste PDF.',M,footerTop+31,6.1);
   let legend=clean(layout.legend||'NAS INSPEÇÕES MARQUE: C- CONFORME   NC- NÃO CONFORME   N/A- NÃO SE APLICA');if(legend.includes('\n')||bold.widthOfTextAtSize(legend,7)>U-10){legendOverflow=true;legend='C = CONFORME | NC = NÃO CONFORME | N/A = NÃO SE APLICA. Legenda completa na identificação anexa.';}
   rect(M,footerTop+43,U,18);text(legend,M+5,footerTop+48,7,bold,U-10,'center');
   const guidance=(Array.isArray(layout.guidance)?layout.guidance:[]).map(value=>wrap(value,6.1,U-8,bold));let top=footerTop+65;
   if(top+guidance.reduce((sum,lines)=>sum+lines.length*7.015+2,0)>H-32){guidanceOverflow=true;text('ORIENTAÇÕES DO FORMULÁRIO: conteúdo integral na identificação anexa.',M+4,top,6.1,bold);}else for(const lines of guidance){linesText(lines,M+4,top,6.1,1.15,bold);top+=lines.length*7.015+2;}
  }
  // Keep the same numbered question intact; very long questions continue explicitly on a new sheet.
  const categoryLabel=item=>item.category&&!/^verifica[çc][ãa]o do equipamento$/i.test(item.category)?clean(item.category):'';
  let questionSize=7.2;const itemHeight=(item,size)=>Math.max(14,wrap(item.text,size,columns[1]-8).length*(size+1.4)+6);
  sheet();const available=footerTop-y-4;
  const groupCount=items.reduce((sum,item,n)=>sum+(categoryLabel(item)&&categoryLabel(item)!==categoryLabel(items[n-1]||{})?1:0),0);
  while(items.reduce((sum,item)=>sum+itemHeight(item,questionSize),0)+groupCount*17>available&&questionSize>6.5)questionSize=Math.max(6.5,questionSize-.1);
  let previousCategory='';
  for(let n=0;n<items.length;n++){
   const item=items[n],answer=answers[n],allLines=wrap(item.text,questionSize,columns[1]-8),leading=questionSize+1.4;let offset=0;
   const category=categoryLabel(item);if(category&&category!==previousCategory){const groupLines=wrap(category,7,columns[1]-8,bold),height=Math.max(17,groupLines.length*8.4+6);if(footerTop-y<height+Math.max(14,leading+6)){foot();sheet(true);}rect(M,y,columns[0],height,gray);rect(M+columns[0],y,U-columns[0],height,gray);const groupNumber=/\./.test(String(item.sourceNumber))?String(item.sourceNumber).split('.')[0]:'';text(groupNumber,M+2,y+4,6.4,bold,columns[0]-4,'center');linesText(groupLines,M+columns[0]+4,y+3,7,1.2,bold);y+=height;}previousCategory=category;
   do{
    if(footerTop-y<Math.max(14,leading+6)){foot();sheet(true);}
    const count=Math.max(1,Math.floor((footerTop-y-6)/leading)),chunk=allLines.slice(offset,offset+count),height=Math.max(14,chunk.length*leading+6);
    let x=M;for(const width of [...columns,...Array(31).fill(dayWidth)]){rect(x,y,width,height);x+=width;}
    const number=String(item.sourceNumber??n+1);text(number+(offset?'*':''),M+2,y+4,6.4,font,columns[0]-4,'center');
    linesText(chunk,M+columns[0]+4,y+3,questionSize,leading/questionSize);
    const action=clean(answer.actionCode||'');if(action){const actionLines=wrap(action,6,columns[2]-4);if(actionLines.length*7>height-4)throw Error('Código de ação excede o campo do item '+number+'.');linesText(actionLines,M+columns[0]+columns[1]+2,y+3,6,1.15);}
    text(answerCode(answer.value),dayStart+(day-1)*dayWidth,y+(height-6.1)/2,6.1,bold,dayWidth,'center');
    y+=height;offset+=chunk.length;if(offset<allLines.length){foot();sheet(true);}
   }while(offset<allLines.length);
  }
  // Blank rows retain the physical sheet's writing grid, without inventing inspection answers.
  while(y+14<=footerTop){let x=M;for(const width of [...columns,...Array(31).fill(dayWidth)]){rect(x,y,width,14);x+=width;}y+=14;}
  if(y<footerTop){let x=M;for(const width of [...columns,...Array(31).fill(dayWidth)]){rect(x,y,width,footerTop-y);x+=width;}}
  foot();
  function annex(title){page=doc.addPage([595.28,841.89]);drawLogo(29,22,104,34);text(title,145,30,11,bold);page.drawLine({start:{x:29,y:775},end:{x:566,y:775},thickness:.8,color:ink});y=78;}
  function annexText(value,size=8.5,b=false){for(const line of wrap(value,size,537,b?bold:font)){if(y+size>798)annex('CONTINUAÇÃO DO REGISTRO');text(line,29,y,size,b?bold:font);y+=size+3.4;}y+=4;}
  annex('IDENTIFICAÇÃO E EVIDÊNCIAS DO REGISTRO');annexText(r.company?.name||'PPL Manutenção',10,true);annexText('Equipamento: '+equipment+' | TAG / Placa: '+(fields.belt||''));
  annexText('Data: '+date(fields.date)+' | Tipo de inspeção: '+(fields.type||''));annexText('Responsável: '+(fields.inspector||'')+' | Matrícula: '+(fields.employee||''));annexText('Função: '+(fields.functionName||'')+' | Unidade: '+(fields.unit||'')+' | Equipe: '+(fields.team||''));
  if(y+241>798)annex('IDENTIFICAÇÃO DO RESPONSÁVEL');const boxesTop=y+6,frameW=261,frameH=218;for(const x of [29,305])rect(x,boxesTop,frameW,frameH);text('ASSINATURA ELETRÔNICA DESENHADA',36,boxesTop+8,7,bold);text('FOTO DO COLABORADOR',312,boxesTop+8,7,bold);
  async function framePicture(data,x,top,width,height){const im=await image(data),size=im.scale(Math.min(width/im.width,height/im.height));page.drawImage(im,{x:x+(width-size.width)/2,y:page.getHeight()-top-height+(height-size.height)/2,width:size.width,height:size.height});}
  if(r.signature?.data)await framePicture(r.signature.data,38,boxesTop+31,243,137);
  text(r.signature?.data?'Sem certificado digital':'Sem assinatura registrada nesta versão',38,boxesTop+180,6.8);if(r.signature?.createdAt)text(clock(r.signature.createdAt),38,boxesTop+197,6.8);
  if(r.workerPhoto?.data)await framePicture(r.workerPhoto.data,314,boxesTop+27,243,158);if(r.workerPhoto?.createdAt)text(clock(r.workerPhoto.createdAt),314,boxesTop+197,6.8);
  y=boxesTop+frameH+17;annexText('ID '+r.id+' | Revisão do registro '+r.revision,7.4);annexText('Modelo '+r.model.id+' | Versão '+r.model.version,7.4);annexText('Código do formulário: '+(layout.formCode||'Não informado')+' | Revisão do documento: '+(layout.revision||'Não informada'),7.4);annexText('Criado: '+clock(r.createdAt)+' | Registrado: '+clock(r.recordedAt||r.updatedAt||r.createdAt),7.4);annexText('Horários do dispositivo em America/Fortaleza. Este registro não produz liberação automática do equipamento.',7.4);
  if(legendOverflow)annexText('Legenda original: '+layout.legend,8,true);if(guidanceOverflow){annexText('ORIENTAÇÕES INTEGRAIS DO FORMULÁRIO',9,true);for(const value of layout.guidance)annexText(value,8);}
  const details=[];for(const [label,key]of [['Situação do equipamento','beltState'],['Observação da situação / baixa','dispositionNotes'],['Avarias adicionais do talabarte','lanyardDamage'],['Motivo da correção','reason']])if(fields[key])details.push(label+': '+fields[key]);
  for(const identifier of r.model.identifiers||[])if(fields[identifier.name])details.push(identifier.label+': '+fields[identifier.name]);
  if(fields.notes)details.push('Observações gerais: '+fields.notes);for(let n=0;n<answers.length;n++)if(answers[n].notes)details.push('Item '+(items[n].sourceNumber??n+1)+': '+answers[n].notes);
  if(details.length){annex('VERSO - OBSERVAÇÕES DO CHECKLIST');for(const detail of details)annexText(detail);}
  const photos=[...(r.equipmentPhotos||[]).map(photo=>({photo,label:'Equipamento'})),...answers.flatMap((answer,n)=>(answer.photos||[]).map(photo=>({photo,label:'Item '+(items[n].sourceNumber??n+1)})))];
  for(let start=0;start<photos.length;start+=4){annex('ANEXO FOTOGRÁFICO DO EQUIPAMENTO');for(let n=0;n<Math.min(4,photos.length-start);n++){const {photo,label}=photos[start+n],x=29+(n%2)*276,top=86+Math.floor(n/2)*346;rect(x,top,261,329);text(label+' | Foto '+(start+n+1),x+8,top+8,8,bold);await framePicture(photo.data,x+8,top+29,245,269);if(photo.createdAt)text(clock(photo.createdAt),x+8,top+308,6.8);}}
  const pages=doc.getPages();pages.forEach((p,n)=>{page=p;const width=p.getWidth()-2*M;text('ID '+r.id+' | r'+r.revision+' | '+date(fields.date)+' | Página '+(n+1)+' de '+pages.length,M,p.getHeight()-15,6,font,width,'center');if(r.preview)text('DEMONSTRAÇÃO - NÃO É INSPEÇÃO REAL',M,p.getHeight()-25,7,bold,width,'center');});
  doc.setTitle((layout.documentTitle||r.model.title)+' - '+equipment);doc.setSubject('Checklist PPL '+r.id+' revisão '+r.revision);return doc.save();
 }
 return {make};
})();
