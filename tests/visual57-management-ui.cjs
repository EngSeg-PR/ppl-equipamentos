/* Painel real, API real, PostgreSQL descartável; nenhum dado ou tráfego de produção. */
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require('playwright'),{createHarness,ids}=require('./attention51-server.cjs'),{harnessOptions,visualAssessment}=require('./visual57-server.cjs');
const root=path.resolve(__dirname,'..'),out=path.resolve(root,'../../work/qa-visual57-management');
async function main(){const h=await createHarness(harnessOptions);let browser,server;fs.mkdirSync(out,{recursive:true});try{
 const a=visualAssessment();assert.equal((await h.call('attention-submit',{assessment:a})).status,200);
 server=http.createServer(async(req,res)=>{const url=new URL(req.url,'http://127.0.0.1');
  if(url.pathname==='/'){res.setHeader('content-type','text/html;charset=utf-8');return res.end('<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/portal.css"><link rel="stylesheet" href="/platform.css"><link rel="stylesheet" href="/attention-history.css"><main><p>Teste local · dados sintéticos</p><div id="host"></div></main><script src="/attention-history.js"></script></html>');}
  if(url.pathname==='/api'){let body='';for await(const chunk of req)body+=chunk;const {action,...data}=JSON.parse(body),r=await h.call(action,data);res.writeHead(r.status,{'content-type':'application/json'});return res.end(await r.text());}
  const name=url.pathname.slice(1);if(!['portal.css','platform.css','attention-history.css','attention-history.js'].includes(name))return res.writeHead(404).end();res.setHeader('content-type',name.endsWith('.js')?'text/javascript':'text/css');res.end(fs.readFileSync(path.join(root,name)));
 });await new Promise(r=>server.listen(0,'127.0.0.1',r));browser=await chromium.launch({headless:true,executablePath:process.env.PRS_CHROME_PATH});
 const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('http://127.0.0.1:'+server.address().port);
 await page.evaluate(async ids=>{window.PR={escape:v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])),call:async(action,data,priv)=>{if(!priv)throw Error('Autenticação obrigatória');const r=await fetch('/api',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({action,...data})});const x=await r.json();if(!r.ok)throw Error(x.error);return x;}};window.panel=PRAttentionHistory.create({host:document.querySelector('#host'),company:{id:ids.company,name:'EMPRESA DE TESTE'},canConfigure:true});await panel.open();},ids);
 await page.getByText('Configuração da classificação experimental',{exact:true}).click();await page.getByRole('button',{name:'Salvar parâmetros',exact:true}).waitFor();
 await page.getByLabel('Limite z para Normal',{exact:true}).fill('1.1');await page.getByRole('button',{name:'Salvar parâmetros',exact:true}).click();await page.getByText(/Parâmetros salvos na revisão 1/).waitFor();
 assert.equal(await page.getByLabel('Janela de recorrência (testes)',{exact:true}).inputValue(),'5');
 await page.screenshot({path:path.join(out,'parametros-1440.png')});
 await page.getByRole('button',{name:'Consultar avaliação',exact:true}).click();await page.getByText('Classificação experimental: Base em formação',{exact:true}).last().waitFor();
 await page.getByText('Apresentações registradas (30)',{exact:true}).click();await page.getByText('Respostas registradas (26)',{exact:true}).click();
 await page.screenshot({path:path.join(out,'resultado-1440.png')});
 await page.setViewportSize({width:390,height:844});await page.evaluate(()=>document.documentElement.style.fontSize='200%');
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1),false);
 const box=await page.locator('dialog').boundingBox();assert(box.x>=0&&box.x+box.width<=391);assert(box.height<=844);
 await page.getByRole('button',{name:'Fechar',exact:true}).click();
 await page.getByText('Configuração da classificação experimental',{exact:true}).click();await page.getByText('Configuração da classificação experimental',{exact:true}).click();await page.getByRole('button',{name:'Salvar parâmetros',exact:true}).waitFor();
 await page.screenshot({path:path.join(out,'parametros-390-fonte200.png')});assert.deepEqual(errors,[]);
 assert.equal((await h.db.query('SELECT revision FROM ppl_attention_rules_v57')).rows[0].revision,1);
 console.log('PASS gestão visual57: configuração administrativa, revisão, resultado/base, eventos, 1440/390, fonte200%, sem sobreposição ou dados de produção.');
 }finally{if(browser)await browser.close();if(server)await new Promise(r=>server.close(r));await h.close();}}
main().catch(e=>{console.error(e);process.exitCode=1;});
