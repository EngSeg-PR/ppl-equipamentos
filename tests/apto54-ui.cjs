/* Local browser + PostgreSQL, using synthetic records only. */
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {createHarness54,assessment,ids}=require('./apto54-server.cjs');
const {chromium}=require(process.env.PRS_PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(__dirname,'..'),out=path.resolve(process.env.PRS_QA_OUTPUT||path.join(root,'../../work/qa-apto54'));
const html=`<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/portal.css"><link rel="stylesheet" href="/platform.css"><link rel="stylesheet" href="/professional47.css"><link rel="stylesheet" href="/attention-history.css"></head><body><main class="platform-main"><div class="platform-note">Homologação local · dados fictícios</div><div id="host"></div></main><script src="/attention-history.js"></script></body></html>`;
async function main(){
 fs.mkdirSync(out,{recursive:true});const h=await createHarness54();let browser,server,checks=0;
 const check=(actual,expected)=>{assert.deepEqual(actual,expected);checks++;};
 try{
  await h.db.query('UPDATE ppl_employees SET name=$1,job_title=$2 WHERE id=$3',['COLABORADOR DE TESTE COM NOME MUITO LONGO PARA VALIDAR O PAINEL RESPONSIVO','CONDUTOR OPERACIONAL DE VEÍCULOS E EQUIPAMENTOS',ids.employee]);
  for(let i=0;i<55;i++){const item=i===0?assessment({status:'incompleta',touches:[],durationMs:0,finishedAt:'2026-10-24T12:00:00Z'}):assessment();const response=await h.call('attention-submit',{assessment:item});assert.equal(response.status,200,await response.text());}
  server=http.createServer(async(req,res)=>{
   const url=new URL(req.url,'http://127.0.0.1');
   if(url.pathname==='/test.html'){res.setHeader('content-type','text/html;charset=utf-8');res.end(html);return;}
   if(url.pathname==='/api'){const chunks=[];for await(const chunk of req)chunks.push(chunk);const {action,...data}=JSON.parse(Buffer.concat(chunks).toString());const response=await h.call54(action,data);res.writeHead(response.status,{'content-type':'application/json'});res.end(await response.text());return;}
   const name=url.pathname.slice(1),names=['portal.css','platform.css','professional47.css','attention-history.css','attention-history.js'];
   if(!names.includes(name)){res.writeHead(404).end();return;}
   res.setHeader('content-type',name.endsWith('.js')?'text/javascript':'text/css');res.end(fs.readFileSync(path.join(root,name)));
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  browser=await chromium.launch({headless:true,...(process.env.PRS_CHROME_PATH?{executablePath:process.env.PRS_CHROME_PATH}:{})});
  const page=await browser.newPage({viewport:{width:1440,height:1100}}),errors=[];page.on('pageerror',error=>errors.push(error.message));
  await page.goto('http://127.0.0.1:'+server.address().port+'/test.html');
  await page.evaluate(async ids=>{
   window.requests=[];window.delay=false;window.release=null;window.current=true;
   window.PR={escape:value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])),call:async(action,data,priv)=>{
    if(!priv)throw Error('Autenticação obrigatória');requests.push({action,data,priv});
    if(window.delay&&action==='attention-dashboard-list')await new Promise(resolve=>window.release=resolve);
    const response=await fetch('/api',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({action,...data})});const result=await response.json();if(!response.ok)throw Error(result.error);return result;
   }};
   window.panel=PRAttentionHistory.create({host:document.querySelector('#host'),company:{id:ids.company,name:'EMPRESA DE TESTE'},employees:[{id:ids.employee,name:'COLABORADOR DE TESTE COM NOME MUITO LONGO PARA VALIDAR O PAINEL RESPONSIVO',employee_number:'QA-1'}],isCurrent:()=>window.current});await panel.open();
  },ids);
  check(await page.locator('[data-attention-id]').count(),50);
  check(await page.locator('[data-attention-count]').textContent(),'50 de 55 avaliação(ões) carregada(s).');
  check(await page.locator('.attention-kpis article').first().locator('strong').textContent(),'55');
  check(await page.locator('.attention-pie[role=img]').count(),2);
  assert((await page.locator('[data-attention-dashboard]').textContent()).includes('não definem aptidão'));checks++;
  await page.screenshot({path:path.join(out,'sistema-apto-desktop.png')});
  await page.getByRole('button',{name:'Carregar mais avaliações'}).click();await page.waitForFunction(()=>document.querySelectorAll('[data-attention-id]').length===55);check(await page.locator('[data-attention-more]').isHidden(),true);
  await page.getByRole('button',{name:'Consultar avaliação'}).first().click();await page.getByRole('button',{name:'Salvar acompanhamento',exact:true}).waitFor();
  check(await page.locator('dialog').count(),1);
  await page.getByLabel('Descrição da atualização').fill('Orientação operacional registrada no teste local.');
  await page.getByRole('button',{name:'Salvar acompanhamento',exact:true}).click();await page.getByText('Acompanhamento salvo. O resultado original foi preservado.',{exact:true}).waitFor();
  await page.waitForFunction(()=>document.querySelector('.attention-kpis article:last-child strong')?.textContent==='1');
  check(await page.locator('dialog[open]').count(),1);
  const currentRow=await page.evaluate(()=>document.querySelector('[data-attention-id]').dataset.attentionId);
  const saved=await h.call54('attention-followup-detail',{id:currentRow});const detail=await saved.json();check(detail.current.revision,1);
  await page.getByLabel('Situação do acompanhamento').selectOption('concluida');
  await page.getByLabel('Descrição da atualização').fill('Acompanhamento concluído no teste.');
  await page.getByRole('button',{name:'Salvar acompanhamento',exact:true}).click();await page.getByText('Acompanhamento salvo. O resultado original foi preservado.',{exact:true}).waitFor();
  await page.waitForFunction(()=>document.querySelector('.attention-followup-history summary')?.textContent.includes('(2)'));
  await page.screenshot({path:path.join(out,'acompanhamento-desktop.png')});
  await page.getByRole('button',{name:'Fechar',exact:true}).click();
  await page.locator('[name=followupStatus]').selectOption('concluida');await page.getByRole('button',{name:'Aplicar filtros'}).click();await page.waitForFunction(()=>document.querySelectorAll('[data-attention-id]').length===1);
  check(await page.locator('.attention-kpis article').first().locator('strong').textContent(),'1');
  await page.getByRole('button',{name:'Consultar avaliação'}).click();await page.getByRole('button',{name:'Salvar acompanhamento',exact:true}).waitFor();
  const concurrent=await h.call54('attention-followup-save',{id:currentRow,status:'em_andamento',note:'Atualização concorrente pelo gestor de teste.',expectedRevision:2});check(concurrent.status,200);
  await page.getByLabel('Descrição da atualização').fill('Minha atualização deve permanecer editável após conflito.');
  await page.getByRole('button',{name:'Salvar acompanhamento',exact:true}).click();await page.getByText('Outro gestor atualizou o acompanhamento. Reabra a avaliação antes de salvar.',{exact:true}).waitFor();
  check(await page.getByLabel('Descrição da atualização').inputValue(),'Minha atualização deve permanecer editável após conflito.');
  await page.getByRole('button',{name:'Atualizar acompanhamento',exact:true}).click();await page.waitForFunction(()=>document.querySelector('.attention-followup-history summary')?.textContent.includes('(3)'));
  await page.getByRole('button',{name:'Fechar',exact:true}).click();
  await page.getByRole('button',{name:'Limpar filtros'}).click();await page.waitForFunction(()=>document.querySelectorAll('[data-attention-id]').length===50);
  await page.getByLabel('Matrícula exata').fill('QA-INEXISTENTE');await page.getByRole('button',{name:'Aplicar filtros'}).click();await page.waitForFunction(()=>document.querySelector('.attention-kpis article strong')?.textContent==='0');
  check(await page.locator('[data-attention-id]').count(),0);check(await page.locator('.attention-pie.empty').count(),2);
  await page.getByRole('button',{name:'Limpar filtros'}).click();await page.waitForFunction(()=>document.querySelectorAll('[data-attention-id]').length===50);
  await page.getByLabel('Situação da avaliação').selectOption('incompleta');await page.getByRole('button',{name:'Aplicar filtros'}).click();await page.waitForFunction(()=>document.querySelectorAll('[data-attention-id]').length===1);
  check(await page.locator('.attention-kpis article').first().locator('strong').textContent(),'1');
  await page.setViewportSize({width:390,height:844});await page.screenshot({path:path.join(out,'sistema-apto-mobile.png')});
  await page.locator('[data-attention-dashboard]').scrollIntoViewIfNeeded();await page.screenshot({path:path.join(out,'indicadores-mobile.png')});
  check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),true);
  await page.getByRole('button',{name:'Consultar avaliação'}).click();await page.getByRole('button',{name:'Salvar acompanhamento',exact:true}).waitFor();
  check(await page.evaluate(()=>document.querySelector('dialog').scrollWidth<=document.querySelector('dialog').clientWidth+1),true);
  await page.locator('[data-attention-followup]').scrollIntoViewIfNeeded();await page.screenshot({path:path.join(out,'acompanhamento-mobile.png')});await page.getByRole('button',{name:'Fechar',exact:true}).click();
  await page.setViewportSize({width:320,height:844});check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),true);
  await page.evaluate(()=>{window.delay=true;document.querySelector('[data-attention-apply]').click();});await page.waitForFunction(()=>!!window.release);
  await page.evaluate(()=>{panel.destroy();window.current=false;document.querySelector('#host').innerHTML='<p id="next">Outra área</p>';window.release();});await page.waitForTimeout(100);
  check(await page.locator('#next').isVisible(),true);check(await page.locator('dialog').count(),0);check(errors,[]);
  fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify({passed:true,checks,realPostgreSQL:true,syntheticRecords:55,productionWrites:0,widths:[1440,390,320],features:['aggregate55-page50','charts','pagination','followup-save-audit','conflict-preserves-note','filters','empty-state','navigation-race']},null,2));
  console.log('PASS apto54 UI: '+checks+' verificações, PostgreSQL+API local, 1440/390/320px, gráficos, filtros, histórico, conflito e navegação tardia. '+out);
 }finally{if(browser)await browser.close();if(server)await new Promise(resolve=>server.close(resolve));await h.close();}
}
main().catch(error=>{console.error(error);process.exitCode=1;});
