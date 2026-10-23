const fs=require('fs'),path=require('path'),http=require('http'),vm=require('vm'),os=require('os'),assert=require('assert/strict');
const {chromium}=require(process.env.PRS_PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(__dirname,'..'),out=process.env.PRS_PRIVACY_QA||fs.mkdtempSync(path.join(os.tmpdir(),'prs-reis-privacy50-'));
fs.mkdirSync(out,{recursive:true});
const publicPDFs=['politica-privacidade-prs-reis-v1.pdf','termo-ciencia-prs-reis-v1.pdf'];
const v=vm.createContext({});vm.runInContext(fs.readFileSync(root+'/model.js','utf8')+'\n'+fs.readFileSync(root+'/models.js','utf8'),v);
const model=JSON.parse(vm.runInContext("JSON.stringify(MODEL_REGISTRY.find(m=>m.id==='ppl-arcofil'))",v));
const company={id:'fbc33dbf-5aa6-446c-938d-74ef927f169f',slug:'ppl',name:'PPL TESTE FICTÍCIO',logoData:'data:image/png;base64,'+fs.readFileSync(root+'/assets/ppl-logo-oficial.png').toString('base64'),status:'ready'};
const server=http.createServer((q,r)=>{try{const u=new URL(q.url,'http://localhost'),p=path.resolve(root,'.'+decodeURIComponent(u.pathname==='/'?'/index.html':u.pathname));assert(p.startsWith(root+path.sep));r.setHeader('content-type',p.endsWith('.js')||p.endsWith('.mjs')?'text/javascript':p.endsWith('.css')?'text/css':p.endsWith('.json')?'application/json':p.endsWith('.png')?'image/png':p.endsWith('.pdf')?'application/pdf':'text/html');r.end(fs.readFileSync(p));}catch{r.writeHead(404);r.end();}});
(async()=>{
 for(const name of ['index','company','executant','checklists','management','owner']){
  const text=fs.readFileSync(root+'/'+name+'.html','utf8');assert.equal((text.match(/class="legal-links"/g)||[]).length,1);
  assert(text.includes('legal.css?v=50'));assert(!text.includes('?v=49'));
 }
 const sw=fs.readFileSync(root+'/sw.js','utf8');assert(sw.includes("ppl-local-v50"));new vm.Script(sw);
 const precache=sw.match(/c\.addAll\((\[[\s\S]*?\])\.map\(path=>/)[1];
 for(const resource of vm.runInNewContext(precache))assert(fs.existsSync(path.join(root,resource.split('?')[0])),'Missing offline resource '+resource);
 await new Promise(ok=>server.listen(0,'127.0.0.1',ok));const base='http://127.0.0.1:'+server.address().port;
 const browser=await chromium.launch({headless:true,executablePath:process.env.PRS_CHROME_PATH||(process.platform==='win32'?'C:/Program Files/Google/Chrome/Application/chrome.exe':undefined)});
 try{
  const ctx=await browser.newContext({acceptDownloads:true});const actions=[];
  await ctx.route('https://*.supabase.co/**',async route=>{const data=route.request().postDataJSON();actions.push(data?.action);assert(['companies','company-context','archive-epoch'].includes(data?.action),'Unexpected action '+data?.action);await route.fulfill({json:data.action==='companies'?{rows:[company]}:data.action==='company-context'?{company,employees:[],models:[{active:true,kind:'checklist',snapshot:model}]}:{rows:[],files:[],epoch:0,moduleVersion:48}});});
  const page=await ctx.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
  for(const width of [390,1440]){
   await page.setViewportSize({width,height:960});
   for(const name of ['privacidade','termo-ciencia']){
    await page.goto(base+'/'+name+'.html');assert(await page.locator('h1').isVisible());assert.equal(await page.locator('input,select,textarea').count(),0,'No extra collection or acceptance');
    assert((await page.locator('.legal-contact').textContent()).includes('prs.reis098@gmail.com'));assert((await page.locator('.legal-contact').textContent()).includes('Rua das Patativas'));
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'Horizontal overflow '+name);
    const downloadPromise=page.waitForEvent('download');await page.getByRole('link',{name:'Baixar PDF',exact:true}).click();const download=await downloadPromise;const file=path.join(out,width+'-'+download.suggestedFilename());await download.saveAs(file);assert.deepEqual(fs.readFileSync(file),fs.readFileSync(root+'/assets/legal/'+download.suggestedFilename()));
    await page.screenshot({path:path.join(out,name+'-'+width+'.png'),fullPage:true});
   }
  }
  for(const width of [390,1440]){await page.setViewportSize({width,height:960});for(const name of ['index','company','executant','management','owner']){
   await page.goto(base+'/'+name+'.html?company=ppl');await page.locator('.legal-links').scrollIntoViewIfNeeded();assert.equal(await page.locator('.legal-links a').count(),2);
   for(const link of await page.locator('.legal-links a').all()){assert.equal(await link.getAttribute('target'),'_blank');assert((await link.getAttribute('rel')).includes('noopener'));}
   assert.equal(await page.locator('.legal-links input,.legal-links button').count(),0);
   await page.screenshot({path:path.join(out,'footer-'+name+'-'+width+'.png')});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'Footer overflow '+name);if(name==='owner')assert((await page.locator('footer').textContent()).includes('Versão 50'));
  }}
  await page.goto(base+'/executant.html?company=ppl');await page.locator('#new').waitFor();await page.evaluate(()=>navigator.serviceWorker.ready);await page.waitForFunction(()=>!!navigator.serviceWorker.controller);
  const cache=await page.evaluate(async()=>{const c=await caches.open('ppl-local-v50');return Promise.all(['privacidade.html','termo-ciencia.html','legal.css',...['politica-privacidade-prs-reis-v1.pdf','termo-ciencia-prs-reis-v1.pdf'].map(n=>'assets/legal/'+n)].map(async p=>({path:p,found:!!(await c.match(p))})));});assert(cache.every(r=>r.found));
  const popupPromise=page.waitForEvent('popup');await page.locator('.legal-links a').first().click();const popup=await popupPromise;await popup.waitForLoadState();assert((await popup.title()).includes('Política'));assert((await page.url()).includes('executant.html'));await popup.close();
  await ctx.setOffline(true);
  for(const name of ['privacidade','termo-ciencia']){await page.goto(base+'/'+name+'.html');assert(await page.locator('h1').isVisible());assert.equal(await page.locator('input,select,textarea').count(),0);}
  for(const name of publicPDFs){const result=await page.evaluate(async p=>{const r=await fetch(p);return {status:r.status,type:r.headers.get('content-type'),head:(await r.text()).slice(0,5)};},'assets/legal/'+name);assert.equal(result.status,200);assert.equal(result.head,'%PDF-');}
  assert(!actions.some(a=>['submit','event','request','login'].includes(a)));assert.deepEqual(errors,[]);
  console.log(JSON.stringify({ok:true,cache,qa:out,actions:[...new Set(actions)]}));
 }finally{await browser.close();server.close();}
})().catch(e=>{console.error(e);server.close();process.exitCode=1;});
