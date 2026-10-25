/* Browser requests to the existing endpoint are intercepted before network egress.
 * The real v51 handler runs against a disposable local PostgreSQL, with fake Auth. */
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require(process.env.PRS_PLAYWRIGHT_MODULE||'playwright');
const {createHarness,ids}=require('./attention51-server.cjs');
const root=path.resolve(__dirname,'..'),web=path.resolve(root,'../triagem-atencao/app/build/web'),out=path.resolve(root,'../../work/qa-attention51-e2e');
const endpoint=fs.readFileSync(path.join(root,'cloud-config.js'),'utf8').match(/url:'([^']+)'/)[1];
const types={'.html':'text/html;charset=utf-8','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.css':'text/css','.ttf':'font/ttf','.otf':'font/otf'};
async function main(){
  const h=await createHarness();let server,browser,context;fs.mkdirSync(out,{recursive:true});
  try{
    server=http.createServer((req,res)=>{
      const url=new URL(req.url,'http://127.0.0.1:8765');
      if(url.pathname==='/history-qa.html'){res.setHeader('content-type','text/html;charset=utf-8');return res.end('<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/qa/portal.css"><link rel="stylesheet" href="/qa/platform.css"><link rel="stylesheet" href="/qa/professional47.css"><link rel="stylesheet" href="/qa/attention-history.css"></head><body><main class="platform-main"><h1>Teste local · avaliação fictícia enviada pelo app</h1><div id="host"></div></main><script src="/qa/attention-history.js"></script></body></html>');}
      const qa=url.pathname.startsWith('/qa/'),base=qa?root:web;
      const file=path.resolve(base,'.'+(qa?url.pathname.slice(3):url.pathname==='/'?'/index.html':url.pathname));
      const relative=path.relative(base,file);
      if(relative.startsWith('..')||path.isAbsolute(relative)){res.writeHead(403).end();return;}
      try{res.setHeader('content-type',types[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));}catch{res.writeHead(404).end();}
    });
    await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(8765,'127.0.0.1',resolve);});
    browser=await chromium.launch({headless:true,...(process.env.PRS_CHROME_PATH?{executablePath:process.env.PRS_CHROME_PATH}:{})});
    context=await browser.newContext({viewport:{width:1100,height:1100},serviceWorkers:'block'});
    let loseReceipt=true,submissions=0;const external=[],traffic=[];
    await context.route('**/*',async route=>{
      const req=route.request(),url=new URL(req.url());
      if(url.origin==='http://127.0.0.1:8765'){await route.continue();return;}
      if(!req.url().startsWith(endpoint+'/')){external.push(req.url());await route.abort();return;}
      const cors={'access-control-allow-origin':'http://127.0.0.1:8765','access-control-allow-headers':'authorization,apikey,content-type','access-control-allow-methods':'POST,OPTIONS','content-type':'application/json'};
      if(req.method()==='OPTIONS'){await route.fulfill({status:204,headers:cors});return;}
      if(url.pathname==='/auth/v1/token'){
        traffic.push('AUTH '+url.search);
        const data=req.postDataJSON();
        assert(data.email==='operador@teste.invalid'||data.refresh_token==='REFRESH-QA','Only explicit synthetic Auth fixtures allowed');
        await route.fulfill({status:200,headers:cors,body:JSON.stringify({access_token:'OWNER',refresh_token:'REFRESH-QA',expires_in:3600,user:{id:ids.owner}})});return;
      }
      assert.equal(url.pathname,'/functions/v1/ppl-api-');
      const body=req.postDataJSON();
      traffic.push(body.action);
      const response=await h.handler(new Request(req.url(),{method:'POST',headers:{...req.headers(),'origin':'http://127.0.0.1:8765'},body:JSON.stringify(body)}));
      if(body.action==='attention-submit'){submissions++;if(loseReceipt){loseReceipt=false;assert.equal(response.status,200,await response.text());await route.fulfill({status:503,headers:cors,body:JSON.stringify({error:'Falha simulada após o recebimento; retente o mesmo ID.'})});return;}}
      await route.fulfill({status:response.status,headers:cors,body:await response.text()});
    });
    const app=await context.newPage(),errors=[];app.on('pageerror',e=>errors.push(e.message));
    async function enable(page){const placeholder=page.locator('flt-semantics-placeholder');await placeholder.waitFor({state:'attached',timeout:60000});await placeholder.evaluate(el=>el.click());}
    await app.goto('http://127.0.0.1:8765');await enable(app);
    await app.getByRole('textbox',{name:'E-mail da gestão'}).click();
    await app.getByRole('textbox',{name:'E-mail da gestão'}).pressSequentially('operador@teste.invalid',{delay:25});
    await app.getByRole('textbox',{name:'Senha',exact:true}).click();
    await app.getByRole('textbox',{name:'Senha',exact:true}).pressSequentially('TESTE_LOCAL_2026',{delay:35});
    await app.waitForTimeout(250);
    await app.getByRole('button',{name:'Entrar',exact:true}).click();await app.getByText('Nova avaliação',{exact:true}).waitFor();
    await fs.promises.writeFile(path.join(out,'semantics.txt'),await app.locator('flt-semantics').allTextContents().then(rows=>rows.join('\n')));
    await app.getByText('Colaborador cadastrado',{exact:true}).click();await app.getByRole('menuitem',{name:'COLABORADOR DE TESTE · QA-1',exact:true}).click();
    await app.getByRole('textbox',{name:'Unidade da avaliação'}).click();await app.getByRole('textbox',{name:'Unidade da avaliação'}).pressSequentially('PORTO',{delay:25});await app.getByRole('textbox',{name:'Equipe da avaliação'}).click();await app.getByRole('textbox',{name:'Equipe da avaliação'}).pressSequentially('MECÂNICA',{delay:25});
    await app.getByRole('button',{name:'Praticar antes da avaliação'}).click();
    for(let n=1;n<=9;n++)await app.getByRole('button',{name:'Número '+n,exact:true}).click();
    await app.getByRole('button',{name:'Iniciar avaliação',exact:true}).click();
    for(let n=1;n<=36;n++)await app.getByRole('button',{name:'Número '+n,exact:true}).click();
    await app.getByText('Avaliação completa',{exact:true}).waitFor();
    await app.getByRole('button',{name:'Consultar histórico',exact:true}).click();
    await app.getByRole('button',{name:'Sincronizar pendentes',exact:true}).click();
    await app.getByText(/Sincronizado com PRS\. REIS/).or(app.getByLabel(/Sincronizado com PRS\. REIS/)).first().waitFor();
    const rows=(await h.db.query('SELECT id,metrics FROM ppl_attention_assessments')).rows;assert.equal(rows.length,1);assert.equal(rows[0].metrics.acertos,36);assert.equal(rows[0].metrics.erros,0);assert(submissions>=2,'Lost receipt must retry with same id');
    const id=rows[0].id;
    const storage=await app.evaluate(()=>Object.entries(localStorage).filter(([k])=>k.includes('/record/')));assert.equal(storage.length,1);assert(!storage[0][1].includes('COLABORADOR DE TESTE'));
    await app.reload();await enable(app);await app.getByRole('button',{name:/Histórico neste aparelho \(1\)/}).click();await app.getByText(/Sincronizado com PRS\. REIS/).or(app.getByLabel(/Sincronizado com PRS\. REIS/)).first().waitFor();
    await app.screenshot({path:path.join(out,'app-historico-restaurado.png')});
    const panel=await context.newPage();await panel.goto('http://127.0.0.1:8765/history-qa.html');
    await panel.evaluate(async({ids,endpoint})=>{
      window.PR={escape:v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])),call:async(action,data,priv)=>{if(!priv)throw Error('auth required');const r=await fetch(endpoint+'/functions/v1/ppl-api-',{method:'POST',headers:{'content-type':'application/json','authorization':'Bearer OWNER'},body:JSON.stringify({action,...data})});const d=await r.json();if(!r.ok)throw Error(d.error);return d;}};
      window.historyPanel=PRAttentionHistory.create({host:document.querySelector('#host'),company:{id:ids.company,name:'EMPRESA DE TESTE'},employees:[{id:ids.employee,name:'COLABORADOR DE TESTE',employee_number:'QA-1'}]});await historyPanel.open();
    },{ids,endpoint});
    assert.equal(await panel.locator('[data-attention-id]').count(),1);assert.equal(await panel.locator('[data-attention-id]').getAttribute('data-attention-id'),id);
    await panel.getByRole('button',{name:'Consultar avaliação'}).click();await panel.getByText('Métricas registradas',{exact:true}).waitFor();await panel.screenshot({path:path.join(out,'plataforma-mesma-avaliacao.png')});
    assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify({passed:true,id,submissions,centralRows:1,targets:36,reloadRestored:true,cipheredLocalRecord:true,productionNetworkRequests:0,blockedExternal:external},null,2));
    console.log('PASS E2E: app36 -> armazenamento cifrado -> recibo perdido/retry -> API SQL real -> mesmo UUID no painel e após recarregar. Nenhum envio de produção.');
  }catch(e){if(context){for(const [i,page]of context.pages().entries()){await page.screenshot({path:path.join(out,`failure-${i}.png`)}).catch(()=>{});await fs.promises.writeFile(path.join(out,`failure-${i}.html`),await page.content()).catch(()=>{});}}throw e;}
  finally{if(browser)await browser.close();if(server)await new Promise(resolve=>server.close(resolve));await h.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
