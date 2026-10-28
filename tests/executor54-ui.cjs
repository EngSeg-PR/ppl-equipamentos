/* Real executant UI with isolated fake service. No production requests or records. */
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require('playwright');
const {MODEL}=require('../model.js');
const root=path.resolve(__dirname,'..'),out=path.resolve(root,'../qa-executor54');
const ids={company:'11111111-1111-4111-8111-111111111111',employee:'22222222-2222-4222-8222-222222222222',other:'33333333-3333-4333-8333-333333333333'};
const company={id:ids.company,slug:'ppl',name:'EMPRESA FICTÍCIA DE TESTE',version:1,logoData:''};
const employee={id:ids.employee,name:'Colaborador de teste com nome longo para verificar o acesso',employee_number:'QA-123',job_title:'Função de teste',job_description:'Descrição fictícia'};
const publicContext={company,models:[{kind:'checklist',active:true,snapshot:MODEL}],employees:[],executorAccessRequired:true,moduleVersion:54};
const mime={'.html':'text/html;charset=utf-8','.css':'text/css','.js':'text/javascript','.json':'application/json','.png':'image/png','.pdf':'application/pdf'};
let denyContext=false,sessionDenied=false,loginCalls=0;
const calls=[];
async function main(){
 fs.mkdirSync(out,{recursive:true});let browser;
 const server=http.createServer((req,res)=>{
  const url=new URL(req.url,'http://127.0.0.1');
  const relative=decodeURIComponent(url.pathname).slice(1)||'index.html',file=path.resolve(root,relative);
  if(relative==='sw.js')return res.writeHead(404).end();
  if(!file.startsWith(root+path.sep))return res.writeHead(403).end();
  try{res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));}catch{res.writeHead(404).end();}
 });
 try{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  console.log('executor54: iniciar navegador isolado');browser=await chromium.launch({headless:true,...(process.env.PRS_CHROME_PATH?{executablePath:process.env.PRS_CHROME_PATH}:{})});
  const context=await browser.newContext({viewport:{width:1440,height:1000}}),page=await context.newPage(),errors=[];
  page.setDefaultTimeout(18000);page.setDefaultNavigationTimeout(25000);page.on('pageerror',error=>{errors.push(error.message);console.log('UI error:',error.message);});
  await context.route('**/*',async route=>{
   const request=route.request(),url=new URL(request.url());
   if(url.hostname==='127.0.0.1')return route.continue();
   assert(url.pathname.includes('/functions/v1/'),'Unexpected external request: '+url.pathname);
   if(request.method()==='OPTIONS')return route.fulfill({status:204,headers:{'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'*','Access-Control-Allow-Methods':'POST, OPTIONS'}});const body=request.postDataJSON(),token=request.headers()['x-ppl-executor'];
   calls.push({action:body.action,header:token,hasPayloadToken:Object.hasOwn(body,'executorToken')});
   const reply=(data,status=200)=>route.fulfill({status,headers:{'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'*'},contentType:'application/json',body:JSON.stringify(data)});
   if(request.method()==='OPTIONS')return reply({});
   if(body.action==='company-context')return denyContext?reply({error:'Empresa suspensa para novos registros.'},403):reply(publicContext);
   if(body.action==='executor-directory')return reply({company,employees:[{id:employee.id,name:employee.name},{id:ids.other,name:'Outro colaborador fictício'}],executorAccessRequired:true});
   if(body.action==='executor-login'){
    loginCalls++;assert.equal(body.employeeId,employee.id);
    if(body.password!=='QA-123')return reply({error:'Acesso inválido.'},401);
    return reply({company,employee,executorToken:'FAKE-EXECUTOR-SESSION-LOCAL-ONLY',expiresAt:new Date(Date.now()+12*3600000).toISOString(),moduleVersion:54});
   }
   if(body.action==='executor-session'){
    assert.equal(token,'FAKE-EXECUTOR-SESSION-LOCAL-ONLY');
    return sessionDenied?reply({error:'Sessão revogada.'},401):reply({company,employee,expiresAt:new Date(Date.now()+12*3600000).toISOString(),moduleVersion:54});
   }
   if(body.action==='executor-logout')return reply({ok:true});
   if(body.action==='submit')return reply({error:'Envios fictícios não são recebidos neste teste.'},503);
   return reply({error:'Ação de teste não esperada: '+body.action},400);
  });
  const address='http://127.0.0.1:'+server.address().port+'/executant.html?company=ppl';
  console.log('executor54: abrir interface local');await page.goto(address);console.log('executor54: aguardar autenticação');await page.getByRole('heading',{name:'Acesso do executante',exact:true}).waitFor();
  await page.waitForFunction(()=>document.querySelector('[name=executorEmployee]')?.options.length===3);
  assert.equal(await page.evaluate(async()=>{await PPL_CONTEXT_READY;return (await all()).length;}),0,'Abrir acesso não cria rascunho');
  await page.selectOption('[name=executorEmployee]',employee.id);await page.fill('[name=executorPassword]','ERRADA');await page.getByRole('button',{name:'Entrar',exact:true}).click();
  await page.getByText('Acesso inválido.',{exact:true}).waitFor();assert.equal(await page.inputValue('[name=executorPassword]'),'');
  await page.fill('[name=executorPassword]','QA-123');await page.getByRole('button',{name:'Entrar',exact:true}).click();await page.locator('.executor-dialog').waitFor({state:'detached'});
  await page.selectOption('#equipment-select','cinto-y');await page.click('#new');
  await page.locator('#form [name=inspector]').waitFor();assert.equal(await page.inputValue('[name=inspector]'),employee.name);assert.equal(await page.inputValue('[name=employee]'),employee.employee_number);
  assert.equal(await page.locator('select[name=staffId]').count(),0);
  assert.equal(await page.evaluate(async()=>(await all()).length),0,'Identidade automática não cria rascunho');
  await page.evaluate(id=>{document.querySelector('[name=staffId]').value=id;},ids.other);
  await page.fill('[name=belt]','TAG FICTÍCIA');await page.waitForFunction(async()=>(await all()).length===1);
  const first=await page.evaluate(()=>JSON.parse(JSON.stringify(current)));
  assert.equal(first.staff.id,employee.id);assert.equal(first.fields.inspector,employee.name);
  assert(!JSON.stringify(first).includes('FAKE-EXECUTOR-SESSION'),'Token fora do registro');
  assert(!JSON.stringify(first).includes('executorPassword'),'Senha fora do registro');
  await context.setOffline(true);await page.evaluate(()=>PRExecutor.ensure(PRContext.company.id)).then(value=>assert.equal(value,true));
  await page.fill('[name=belt]','TAG FICTÍCIA OFFLINE');await page.waitForFunction(async()=>(await all())[0].fields.belt==='TAG FICTÍCIA OFFLINE');
  await page.setViewportSize({width:390,height:844});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
  await page.screenshot({path:path.join(out,'executante-mobile.png'),fullPage:false});
  await context.setOffline(false);await page.setViewportSize({width:1440,height:1000});
  await page.locator('[name=type]').first().check();
  for(const radio of await page.locator('input[name^="answer-"][value="Conforme"]').all())await radio.check();
  await page.evaluate(()=>{
   const canvas=document.createElement('canvas');canvas.width=300;canvas.height=80;const ctx=canvas.getContext('2d');ctx.moveTo(10,20);ctx.lineTo(280,60);ctx.stroke();
   current.signature={data:canvas.toDataURL('image/png'),createdAt:stamp(),kind:'drawn-electronic'};
   current.workerPhoto={name:'FOTO FICTÍCIA DE TESTE.jpg',data:canvas.toDataURL('image/jpeg'),createdAt:stamp(),captureMethod:'camera'};
  });
  await page.getByRole('button',{name:'Salvar inspeção e preparar PDF',exact:true}).click();
  await page.getByRole('heading',{name:'Registro concluído',exact:true}).waitFor();
  await page.locator('#completed-pdf-output .pdf-download').waitFor();
  assert.equal(await page.evaluate(()=>current),null,'Finalização volta à escolha do novo checklist');
  assert.equal(await page.evaluate(async()=>(await all()).filter(row=>row.status==='draft').length),0,'Finalização não deixa rascunho');
  const completed=await page.evaluate(async()=>(await all())[0]);assert.equal(completed.staff.id,employee.id);
  await context.setOffline(true);await page.click('#pending-nav');await page.getByRole('button',{name:'Ver / salvar PDF',exact:true}).click();
  await page.locator('#pdf-output .pdf-download').waitFor();
  const download=page.waitForEvent('download');await page.locator('#pdf-output .pdf-download').click();
  const item=await download;await item.saveAs(path.join(out,'inspecao-ficticia-offline.pdf'));
  const bytes=fs.readFileSync(path.join(out,'inspecao-ficticia-offline.pdf'));assert.equal(bytes.subarray(0,5).toString(),'%PDF-');assert(bytes.length>1000);
  const originalJson=await page.evaluate(()=>JSON.stringify(current));
  await page.getByRole('button',{name:'Criar correção',exact:true}).click();
  await page.waitForFunction(()=>current?.status==='draft'&&current.revision===2);
  assert.equal(await page.evaluate(()=>current.staff.id),employee.id);assert.equal(await page.evaluate(async()=>JSON.stringify((await all()).find(row=>row.revision===1))),originalJson,'Correção conserva snapshot original');
  assert.equal(await page.evaluate(other=>PRExecutor.canEdit({company:PRContext.company,staff:{id:other}}),ids.other),false,'Outro colaborador não pode editar o rascunho');
  const draftBeforeExpiry=await page.evaluate(()=>JSON.stringify(current));
  await page.evaluate(()=>{window.originalNow=Date.now;const future=Date.now()+13*3600000;Date.now=()=>future;});
  assert.equal(await page.evaluate(()=>PRExecutor.current()),null,'Sessão expira após o prazo autorizado');
  await page.fill('[name=belt]','ALTERAÇÃO SEM ACESSO');
  assert.equal(await page.evaluate(()=>JSON.stringify(current)),draftBeforeExpiry,'Campos não alteram o registro após expiração');
  await page.evaluate(()=>{window.cameraAttempts=0;PRLiveCamera.take=async()=>{window.cameraAttempts++;return null;};void captureLivePhoto();});
  await page.getByRole('heading',{name:'Acesso do executante',exact:true}).waitFor();
  assert.equal(await page.evaluate(()=>window.cameraAttempts),0,'Câmera exige sessão válida');
  await page.getByRole('button',{name:'Consultar pendências e PDFs deste aparelho'}).click();
  assert.equal(await page.evaluate(async()=>(await all()).length),2,'Expiração não apaga a fila');
  await page.evaluate(()=>{Date.now=window.originalNow;PRExecutor.configure(PRContext,'ppl');});
  await context.setOffline(false);sessionDenied=true;
  await page.evaluate(()=>{void PRExecutor.ensure(PRContext.company.id);});
  await page.getByRole('heading',{name:'Acesso do executante',exact:true}).waitFor();assert.equal(await page.evaluate(()=>PRExecutor.current()),null,'Revogação não usa perfil offline');
  await page.getByRole('button',{name:'Consultar pendências e PDFs deste aparelho'}).click();
  assert.equal(await page.evaluate(async()=>(await all()).length),2,'Revogação conserva registro e rascunho');
  await page.click('#checklist-nav');
  if(!await page.locator('#storage-tools').evaluate(el=>el.open))await page.locator('#storage-tools>summary').click();
  await page.locator('#records [data-key]').filter({hasText:'Rascunho'}).click();
  await page.getByText('Rascunho preservado',{exact:true}).waitFor();assert(await page.locator('[name=belt]').isDisabled());
  assert.equal(await page.evaluate(()=>PRExecutor.canEdit(current)),false);
  denyContext=true;await page.reload();await page.getByRole('heading',{name:'Acesso do executante',exact:true}).waitFor();
  await page.getByRole('button',{name:'Consultar pendências e PDFs deste aparelho'}).click();
  assert.equal(await page.evaluate(async()=>(await all()).length),2,'Empresa negada conserva acesso local');
  assert.deepEqual(await page.evaluate(()=>PRContext.employees),[],'Contexto negado não restaura diretório');
  await page.screenshot({path:path.join(out,'consulta-local-mobile.png'),fullPage:false});
  assert.equal(loginCalls,2);assert(calls.some(x=>x.action==='executor-session'&&x.header));assert(calls.every(x=>!x.hasPayloadToken));assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'resultado.json'),JSON.stringify({passed:true,loginServerContract:true,identityFixed:true,noDraftOnOpen:true,offlinePriorSession:true,revokedReadOnly:true,queuePreserved:true,expiryBlocksEditsAndCamera:true,otherEmployeeDraftBlocked:true,deniedContextLocalAccess:true,noTokenInPayload:true,completedReturnsHome:true,pdfDownloadOffline:true,correctionSnapshotPreserved:true,viewports:[1440,390]},null,2));
  console.log('PASS executor54 UI: login/erro, autoria fixa, sem rascunho na prévia, offline autorizado, revogação, preservação local e 1440/390 px.');
 }finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
}
main().catch(error=>{console.error(error);process.exitCode=1;});
