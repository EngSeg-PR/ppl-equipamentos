const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {createHarness,assessment,ids}=require('./attention51-server.cjs');
const {chromium}=require(process.env.PRS_PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(__dirname,'..'),out=path.resolve(process.env.PRS_QA_OUTPUT||path.join(root,'../../work/qa-attention51'));
const html=`<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/portal.css"><link rel="stylesheet" href="/platform.css"><link rel="stylesheet" href="/professional47.css"><link rel="stylesheet" href="/attention-history.css"></head><body><main class="platform-main"><h1>Histórico · testes locais fictícios</h1><div id="host"></div></main><script src="/attention-history.js"></script></body></html>`;
async function main(){
  fs.mkdirSync(out,{recursive:true});const h=await createHarness();let browser,server;
  try{
    const a=assessment(),b=assessment({status:'incompleta',touches:[],durationMs:0,finishedAt:'2026-10-24T12:00:00Z'});
    for(const item of [a,b]){const r=await h.call('attention-submit',{assessment:item});assert.equal(r.status,200,await r.text());}
    server=http.createServer(async(req,res)=>{
      const url=new URL(req.url,'http://127.0.0.1');
      if(url.pathname==='/test.html'){res.setHeader('content-type','text/html;charset=utf-8');res.end(html);return;}
      if(url.pathname==='/api'){
        const chunks=[];for await(const chunk of req)chunks.push(chunk);
        const response=await h.handler(new Request('https://test.invalid',{method:'POST',headers:{'content-type':'application/json','authorization':'Bearer OWNER'},body:Buffer.concat(chunks)}));
        res.writeHead(response.status,{'content-type':'application/json'});res.end(await response.text());return;
      }
      const names=['portal.css','platform.css','professional47.css','attention-history.css','attention-history.js'];
      if(!names.includes(url.pathname.slice(1))){res.writeHead(404).end();return;}
      res.setHeader('content-type',url.pathname.endsWith('.js')?'text/javascript':'text/css');res.end(fs.readFileSync(path.join(root,url.pathname)));
    });
    await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
    browser=await chromium.launch({headless:true,...(process.env.PRS_CHROME_PATH?{executablePath:process.env.PRS_CHROME_PATH}:{})});
    const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.goto('http://127.0.0.1:'+server.address().port+'/test.html');
    await page.evaluate(async ids=>{
      window.requests=[];window.delay=false;window.release=null;window.current=true;
      window.PR={escape:value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])),call:async(action,data,priv)=>{
        if(!priv)throw Error('Autenticação obrigatória');requests.push({action,data,priv});
        if(window.delay)await new Promise(resolve=>window.release=resolve);
        const res=await fetch('/api',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({action,...data})});const result=await res.json();if(!res.ok)throw Error(result.error);return result;
      }};
      window.panel=PRAttentionHistory.create({host:document.querySelector('#host'),company:{id:ids.company,name:'EMPRESA DE TESTE'},employees:[{id:ids.employee,name:'COLABORADOR DE TESTE',employee_number:'QA-1'}],isCurrent:()=>window.current});await panel.open();
    },ids);
    assert.equal(await page.locator('[data-attention-id]').count(),2);
    await page.getByRole('button',{name:'Consultar avaliação'}).first().click();
    await page.locator('.attention-dialog [data-attention-retry]').waitFor({state:'hidden'});await page.getByText('Métricas registradas',{exact:true}).waitFor();
    await page.screenshot({path:path.join(out,'historico-desktop.png')});
    await page.getByRole('button',{name:'Fechar',exact:true}).click();
    await page.selectOption('[name=status]','completa');await page.getByRole('button',{name:'Aplicar filtros'}).click();
    await page.waitForFunction(()=>document.querySelectorAll('[data-attention-id]').length===1);
    await page.getByRole('button',{name:'Consultar avaliação'}).click();await page.getByText('Métricas registradas',{exact:true}).waitFor();
    await page.locator('.attention-touches summary').click();assert.equal(await page.locator('.attention-touches tbody tr').count(),5);assert((await page.locator('.attention-touches tbody').textContent()).includes('Acerto'));
    await page.setViewportSize({width:390,height:844});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
    await page.screenshot({path:path.join(out,'historico-mobile.png')});await page.getByRole('button',{name:'Fechar',exact:true}).click();
    await page.evaluate(()=>{window.delay=true;document.querySelector('[data-attention-apply]').click();});await page.waitForFunction(()=>!!window.release);
    await page.evaluate(()=>{panel.destroy();window.current=false;document.querySelector('#host').innerHTML='<p id="next">Outra área</p>';window.release();});
    await page.waitForTimeout(100);assert(await page.locator('#next').isVisible());assert.equal(await page.locator('dialog').count(),0);assert.deepEqual(errors,[]);
    const sw=fs.readFileSync(path.join(root,'sw.js'),'utf8');assert(sw.includes("ppl-local-v51"));assert(sw.includes('attention-history.js'));assert(sw.includes('attention-history.css'));
    for(const name of ['owner.html','management.html']){const text=fs.readFileSync(path.join(root,name),'utf8');assert(text.includes('attention-history.js?v=51'));assert(text.includes('attention-history.css?v=51'));assert(text.includes('attention-history'));}
    console.log('PASS attention51 UI: SQL real via API, lista/filtros/detalhe/toques, navegação tardia, menus e 1440/390 px.');
  }finally{if(browser)await browser.close();if(server)await new Promise(resolve=>server.close(resolve));await h.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
