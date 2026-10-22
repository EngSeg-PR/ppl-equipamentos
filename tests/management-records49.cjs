/* Real management page: authenticated mocks only, with delayed responses across module/session changes. */
const fs=require('fs'),path=require('path'),http=require('http'),assert=require('assert/strict');
const {chromium}=require(process.env.PRS_PLAYWRIGHT_MODULE||'playwright'),{PDFDocument}=require('../vendor/pdf-lib.min.js');
const root=path.resolve(__dirname,'..'),out=path.resolve(process.env.PRS_QA_OUTPUT||require('os').tmpdir()+'/prs-records49');fs.mkdirSync(out,{recursive:true});
const companyId='11111111-1111-4111-8111-111111111111',employeeId='22222222-2222-4222-8222-222222222222',inspectionId='33333333-3333-4333-8333-333333333333';
const employee={id:employeeId,name:'COLABORADOR FICTÍCIO',employee_number:'QA-49',job_title:'TÉCNICO FICTÍCIO'},company={id:companyId,slug:'ppl',name:'EMPRESA FICTÍCIA',version:1,logoData:''};
const row={key:inspectionId+':1',id:inspectionId,revision:1,company_id:companyId,record_kind:'inspection',received_at:'2026-10-22T10:00:00Z',pdf_ready:true,payload:{id:inspectionId,revision:1,kind:'inspection',company,staff:{id:employeeId},fields:{inspector:employee.name,employee:employee.employee_number,functionName:employee.job_title,date:'2026-10-22',belt:'ÁREA FICTÍCIA',type:'Rotina',unit:'PORTO',team:'SESMT'},model:{id:'qa49',version:'1',equipmentName:'Inspeção fictícia',title:'Inspeção fictícia'},answers:[{itemId:'qa',value:'Conforme',notes:'',photos:[]}]}};
function gate(){let release,seen;const wait=new Promise(r=>release=r),started=new Promise(r=>seen=r);return {wait,release,started,seen};}
const server=http.createServer((req,res)=>{try{const file=path.join(root,new URL(req.url,'http://localhost').pathname);res.setHeader('content-type',file.endsWith('.js')?'text/javascript':file.endsWith('.css')?'text/css':file.endsWith('.json')?'application/json':'text/html');res.end(fs.readFileSync(file));}catch{res.writeHead(404);res.end();}});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const browser=await chromium.launch({headless:true,...(process.env.PRS_CHROME_PATH?{executablePath:process.env.PRS_CHROME_PATH}:{})});
 try{
  const pdf=await PDFDocument.create();pdf.addPage([595,842]).drawText('INSPECAO FICTICIA - TESTE LOCAL');const pdfBytes=await pdf.save();
  let initial=gate(),delayedPDF=null,lists=0,events=0;
  const ctx=await browser.newContext({serviceWorkers:'block',viewport:{width:1440,height:1000}});
  await ctx.addInitScript(()=>{const create=URL.createObjectURL.bind(URL),revoke=URL.revokeObjectURL.bind(URL);window.__pdfUrls={created:[],revoked:[]};URL.createObjectURL=blob=>{const url=create(blob);window.__pdfUrls.created.push(url);return url;};URL.revokeObjectURL=url=>{window.__pdfUrls.revoked.push(url);return revoke(url);};});
  await ctx.route('https://*.supabase.co/**',async route=>{
   if(route.request().url().includes('/auth/'))return route.fulfill({json:{access_token:'TEST',refresh_token:'TEST',expires_in:3600}});
   const p=route.request().postDataJSON();let data;
   if(p.action==='company-context')data={company,employees:[employee],models:[]};
   else if(p.action==='session')data={profile:{role:'manager'},memberships:[{company_id:companyId,scope_mode:'company'}],company};
   else if(p.action==='list'){lists++;if(initial){const held=initial;initial=null;held.seen();await held.wait;}data={rows:[row]};}
   else if(p.action==='management-list')data={rows:[],files:[],scopes:null,moduleVersion:48};
   else if(p.action==='pdf'){if(delayedPDF){const held=delayedPDF;delayedPDF=null;held.seen();await held.wait;}return route.fulfill({contentType:'application/pdf',body:Buffer.from(pdfBytes)});}
   else if(p.action==='events'){events++;data={rows:[]};}
   else throw Error('Unexpected request '+p.action);
   return route.fulfill({json:data});
  });
  const page=await ctx.newPage(),errors=[];let popups=0;page.on('pageerror',error=>errors.push(error.message));page.on('popup',()=>popups++);
  const settled=()=>page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
  const aliveURLs=()=>page.evaluate(()=>__pdfUrls.created.filter(url=>!__pdfUrls.revoked.includes(url)).length);
  const login=async()=>{await page.fill('#login-form [name=email]','qa@example.invalid');await page.fill('#login-form [name=password]','TEST-ONLY');await page.click('#login-form button');};
  const hasRecords=()=>page.locator('[data-pdf]').first().waitFor();
  await page.goto('http://127.0.0.1:'+server.address().port+'/management.html?company=ppl');await page.waitForFunction(()=>document.querySelector('#company-name').textContent.includes('EMPRESA FICTÍCIA'));
  const heldInitial=initial;await login();await heldInitial.started;
  await page.click('[data-module=nrs]');await page.getByRole('heading',{name:'Controle de NRs',exact:true}).waitFor();
  let response=page.waitForResponse(r=>r.request().postDataJSON()?.action==='list');heldInitial.release();await (await response).finished();await settled();
  assert(await page.getByRole('heading',{name:'Controle de NRs',exact:true}).isVisible(),'late inspection list must not replace another management module');assert.equal(await page.locator('[data-pdf]').count(),0);
  await page.click('[data-module=records]');await hasRecords();
  const heldPDF=gate();delayedPDF=heldPDF;response=page.waitForResponse(r=>r.request().postDataJSON()?.action==='pdf');await page.locator('[data-pdf]').first().click();await heldPDF.started;await page.locator('.records-dialog [data-close]').click();
  await page.click('[data-module=nrs]');await page.getByRole('heading',{name:'Controle de NRs',exact:true}).waitFor();heldPDF.release();await (await response).finished();await settled();
  assert.equal(await page.locator('.records-dialog').count(),0,'late PDF must not resurrect closed viewer');assert.equal(await aliveURLs(),0,'late PDF must not create a leaked object URL');assert(await page.getByRole('heading',{name:'Controle de NRs',exact:true}).isVisible());
  await page.click('[data-module=records]');await hasRecords();await page.locator('[data-pdf]').first().click();await page.waitForFunction(()=>document.querySelector('iframe.records-pdf-preview')?.src.startsWith('blob:'));assert.equal(await aliveURLs(),1);
  // Session expiry uses this same logout control, including while a modal has focus.
  await page.evaluate(()=>document.querySelector('#logout').click());await page.locator('#login-box').waitFor({state:'visible'});await page.waitForFunction(()=>__pdfUrls.created.every(url=>__pdfUrls.revoked.includes(url)));assert.equal(await page.locator('.records-dialog').count(),0);assert.equal(await page.locator('#management-content').textContent(),'');
  await login();await hasRecords();const before=lists;await page.click('#refresh');await hasRecords();assert(lists>before,'refresh must reload authenticated records');
  await page.locator('[data-pdf]').first().click();await page.waitForFunction(()=>document.querySelector('iframe.records-pdf-preview')?.src.startsWith('blob:'));await page.screenshot({path:path.join(out,'management-records49-viewer.png')});await page.locator('.records-dialog [data-close]').click();await page.waitForFunction(()=>__pdfUrls.created.every(url=>__pdfUrls.revoked.includes(url)));assert.equal(events,0,'PDF consultations must never invoke status/event operations');assert.equal(popups,0,'consultation must not automatically open a new browser tab');assert.deepEqual(errors,[]);
  console.log('PASS management49 integration: delayed list cannot overwrite another module; delayed PDF stays closed; logout cleans viewer/URLs; relogin and refresh work; PDF never opens status workflow or popup.');
 }finally{await browser.close();server.close();}
})().catch(error=>{console.error(error);server.close();process.exitCode=1});
