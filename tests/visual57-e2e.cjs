/* Compilação real, API real e PostgreSQL local. Sem tráfego para produção. */
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require('playwright');
const {createHarness,assessment,ids}=require('./attention51-server.cjs');
const {harnessOptions}=require('./visual57-server.cjs');
const root=path.resolve(__dirname,'..'),web=path.join(root,'attention-app/app/build/web'),out=path.resolve(root,'../../work/qa-visual57');
const endpoint=fs.readFileSync(path.join(root,'cloud-config.js'),'utf8').match(/url:'([^']+)'/)[1];
const types={'.html':'text/html;charset=utf-8','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.svg':'image/svg+xml','.ttf':'font/ttf','.otf':'font/otf'};
async function main(){const h=await createHarness(harnessOptions);let server,browser;fs.mkdirSync(out,{recursive:true});
 try{
  const otherEmployee='88888888-8888-4888-8888-888888888888';
  await h.db.query("INSERT INTO ppl_employees(id,company_id,name,employee_number,job_title) VALUES($1,$2,'PESSOA OUTRA EMPRESA TESTE','0002','CONDUTOR')",[otherEmployee,ids.other]);
  const old=await h.call('attention-submit',{assessment:assessment()});assert.equal(old.status,200);
  server=http.createServer((req,res)=>{const url=new URL(req.url,'http://127.0.0.1:8765');const file=path.resolve(web,'.'+(url.pathname==='/'?'/index.html':url.pathname));if(path.relative(web,file).startsWith('..'))return res.writeHead(403).end();try{res.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));}catch{res.writeHead(404).end();}});
  await new Promise(r=>server.listen(8765,'127.0.0.1',r));browser=await chromium.launch({headless:true,executablePath:process.env.PRS_CHROME_PATH,args:process.env.PRS_QA_SOFTWARE?['--disable-gpu']:[]});
  const contexts=[],external=[],errors=[];let lostReceipt=true,submissions=0;
  async function context(){const c=await browser.newContext({viewport:{width:1440,height:1000},serviceWorkers:'block'});contexts.push(c);
   await c.addInitScript(()=>{const data=navigator.userAgentData;if(data?.getHighEntropyValues){const original=data.getHighEntropyValues.bind(data);Object.defineProperty(Object.getPrototypeOf(data),'getHighEntropyValues',{configurable:true,value:async hints=>hints.length===1&&hints[0]==='model'?{model:'MODELO SOMENTE NO TESTE'}:original(hints)});}});
   await c.route('**/*',async route=>{const req=route.request(),url=new URL(req.url());if(url.origin==='http://127.0.0.1:8765')return route.continue();
    if(!req.url().startsWith(endpoint+'/')){external.push(req.url());return route.abort();}
    const headers={'access-control-allow-origin':'http://127.0.0.1:8765','access-control-allow-headers':'authorization,apikey,content-type,x-ppl-executor','access-control-allow-methods':'POST,OPTIONS','content-type':'application/json'};
    if(req.method()==='OPTIONS')return route.fulfill({status:204,headers});assert.equal(url.pathname,'/functions/v1/ppl-api-');
    const body=req.postDataJSON(),response=await h.handler(new Request(req.url(),{method:'POST',headers:{...req.headers(),origin:'http://127.0.0.1:8765'},body:JSON.stringify(body)}));
    if(body.action==='attention-employee-submit'){submissions++;if(lostReceipt){lostReceipt=false;assert.equal(response.status,200,await response.text());return route.fulfill({status:503,headers,body:JSON.stringify({error:'Recibo perdido somente neste teste local.'})});}}
    return route.fulfill({status:response.status,headers,body:await response.text()});
   });return c;
  }
  async function enable(page){await page.goto('http://127.0.0.1:8765');const p=page.locator('flt-semantics-placeholder');await p.waitFor({state:'attached',timeout:60000});await p.evaluate(el=>el.click());await page.getByText('Acesso do colaborador',{exact:true}).waitFor();}
  async function login(page,company='EMPRESA DE TESTE',person='COLABORADOR DE TESTE',password='QA-1'){
   await page.getByText('Empresa',{exact:true}).click();await page.getByRole('menuitem',{name:company,exact:true}).click();
   await page.getByText('Colaborador',{exact:true}).click();await page.getByRole('menuitem',{name:person,exact:true}).click();
   const field=page.getByRole('textbox',{name:'Matrícula (senha)',exact:true});await field.click();await field.pressSequentially(password,{delay:30});await page.getByRole('button',{name:'Entrar',exact:true}).click();await page.getByText('Nova avaliação',{exact:true}).waitFor();
  }
  const c=await context(),app=await c.newPage();app.on('pageerror',e=>errors.push(e.message));await enable(app);await app.waitForLoadState('networkidle');await app.waitForTimeout(600);
  await app.screenshot({path:path.join(out,'entrada-1440.png')});await app.setViewportSize({width:390,height:844});await app.screenshot({path:path.join(out,'entrada-390.png')});await app.setViewportSize({width:1440,height:1000});
  await login(app);
  await app.getByRole('button',{name:/Meu histórico \(/}).click();await app.getByText('Meu histórico',{exact:true}).waitFor();await app.getByText(/COLABORADOR DE TESTE\s+Matrícula: QA-1/).waitFor();
  assert.equal((await h.db.query('SELECT count(*)::int n FROM ppl_attention_assessments')).rows[0].n,1);
  await app.getByRole('button',{name:'Voltar ao início',exact:true}).click();
  assert.equal(await app.getByText('Colaborador cadastrado',{exact:true}).count(),0);
  for(const [label,value] of [['Unidade da avaliação','PORTO'],['Equipe da avaliação','MECÂNICA']]){const field=app.getByRole('textbox',{name:label});await field.click();await field.pressSequentially(value,{delay:25});}
  async function responderAte(texto,limite){
   const deadline=Date.now()+limite;let tocou=false;
   while(Date.now()<deadline){
    if(await app.getByText(texto,{exact:true}).count())return;
    const go=app.getByRole('button',{name:'Círculo parado',exact:true});
    if(await go.count()){
     if(!tocou){await app.waitForTimeout(180);if(await go.count()){await go.click();tocou=true;}}
    }else tocou=false;
    await app.waitForTimeout(60);
   }
   throw Error('Prazo do teste visual: '+texto);
  }
  await app.getByRole('button',{name:'Praticar antes da avaliação'}).click();
  await app.getByText('Veja como fazer',{exact:true}).waitFor();
  await app.screenshot({path:path.join(out,'demonstracao-1440.png')});
  await responderAte('Treino concluído',22000);
  await app.setViewportSize({width:390,height:844});
  await app.getByRole('button',{name:'Iniciar avaliação',exact:true}).click();
  await app.getByText('Avaliação visual em andamento',{exact:true}).waitFor();
  await app.screenshot({path:path.join(out,'teste-390.png')});
  await responderAte('Avaliação completa',100000);
  await app.getByText('Classificação experimental',{exact:true}).waitFor();
  await app.getByText('Parâmetros em validação. Não é diagnóstico nem liberação para o trabalho.',{exact:true}).waitFor();
  await app.screenshot({path:path.join(out,'resultado-390.png')});
  await app.getByRole('button',{name:'Consultar histórico',exact:true}).click();const receipt=app.waitForResponse(r=>r.request().method()==='POST'&&r.request().postDataJSON()?.action==='attention-employee-submit'&&r.status()===200);await app.getByRole('button',{name:'Atualizar histórico e enviar pendentes',exact:true}).click();await receipt;
  await app.getByText(/Sincronizado com PRS\. REIS/).or(app.getByLabel(/Sincronizado com PRS\. REIS/)).first().waitFor();
  assert.equal((await h.db.query('SELECT count(*)::int n FROM ppl_attention_assessments')).rows[0].n,2);assert(submissions>=2);const novo=(await h.db.query("SELECT * FROM ppl_attention_assessments WHERE protocol_version='visual-v1'")).rows[0];assert.equal(novo.metrics.previstos,30);assert.equal(novo.metrics.respostas_validas,24);assert.equal(novo.metrics.classification.state,'base_em_formacao');assert(novo.duration_ms<90000);assert(novo.payload.trials.every(t=>Number.isInteger(t.shownUs)));assert(novo.payload.responses.every(t=>Number.isInteger(t.tUs)));assert.equal(novo.payload.technical.deviceModel,'MODELO SOMENTE NO TESTE');await app.screenshot({path:path.join(out,'historico-pessoal-teste.png')});
  // Mesmo tablet, outra empresa/pessoa: nenhuma avaliação da primeira pessoa.
  await app.getByRole('button',{name:'Sair da conta sem apagar o histórico',exact:true}).click();await login(app,'OUTRA EMPRESA DE TESTE','PESSOA OUTRA EMPRESA TESTE','0002');await app.getByRole('button',{name:/Meu histórico \(/}).click();await app.getByText('Nenhuma avaliação disponível no seu histórico.',{exact:true}).waitFor();assert.equal(await app.getByText(/COLABORADOR DE TESTE\s+Matrícula:/).count(),0);
  await c.close(); // Libera o renderizador antes de simular outro aparelho.
  // Outro aparelho, armazenamento inicialmente vazio: recupera ambas as avaliações próprias.
  const another=await context(),fresh=await another.newPage();fresh.on('pageerror',e=>errors.push(e.message));await enable(fresh);await login(fresh);await fresh.getByRole('button',{name:/Meu histórico \(/}).click();await fresh.getByText('Meu histórico',{exact:true}).waitFor();await fresh.getByText(/Ver detalhes/).nth(1).waitFor();
  const management=await h.call('attention-history-list',{},'OWNER');assert.equal((await management.json()).rows.length,2);
  assert.deepEqual(errors,[]);assert.deepEqual(external,[]);
  fs.writeFileSync(path.join(out,'resultado.json'),JSON.stringify({passed:true,companies:2,centralRecords:2,submissions,priorManagementRecordVisibleToEmployee:true,newDeviceRestored:true,otherEmployeeIsolated:true,managementHistoryPreserved:true,deviceModelCaptured:true,highResolutionEvents:true,productionRequests:0},null,2));
  console.log('PASS E2E visual57: duas empresas, matrícula, histórico anterior, teste visual30, recibo perdido/reenvio, outro aparelho, troca de pessoa e gestão preservada. Produção: zero envios.');
 }catch(error){if(browser)for(const [i,page] of browser.contexts().flatMap(c=>c.pages()).entries()){await page.screenshot({path:path.join(out,'falha-'+i+'.png')}).catch(()=>{});fs.writeFileSync(path.join(out,'falha-'+i+'.html'),await page.content().catch(()=>'Renderizador de teste indisponível'));}throw error;}finally{if(browser)await browser.close();if(server)await new Promise(r=>server.close(r));await h.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
