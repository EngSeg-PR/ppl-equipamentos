const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require('playwright');
const root=path.resolve(__dirname,'..'),web=path.join(root,'attention-app/app/build/web'),out=path.resolve(root,'../../work/qa-brand52');
const types={'.html':'text/html;charset=utf-8','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.svg':'image/svg+xml','.ttf':'font/ttf','.otf':'font/otf'};
(async()=>{fs.mkdirSync(out,{recursive:true});let browser;
const server=http.createServer((req,res)=>{const url=new URL(req.url,'http://127.0.0.1:8766');const file=path.resolve(web,'.'+(url.pathname==='/'?'/index.html':url.pathname));if(path.relative(web,file).startsWith('..'))return res.writeHead(403).end();try{res.setHeader('content-type',types[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));}catch{res.writeHead(404).end();}});
try{await new Promise(r=>server.listen(8766,'127.0.0.1',r));browser=await chromium.launch({headless:true,executablePath:process.env.PRS_CHROME_PATH});
const context=await browser.newContext({serviceWorkers:'block'});const external=[];
await context.route('**/*',route=>{if(new URL(route.request().url()).origin==='http://127.0.0.1:8766')return route.continue();external.push(route.request().url());return route.abort();});
const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
for(const [width,height] of [[1440,900],[390,844],[320,568],[768,1024],[844,390]]){
await page.setViewportSize({width,height});await page.goto('http://127.0.0.1:8766/');
const placeholder=page.locator('flt-semantics-placeholder');await placeholder.waitFor({state:'attached',timeout:60000});await placeholder.evaluate(el=>el.click());
await page.getByText('Acesse sua conta',{exact:true}).waitFor();await page.waitForLoadState('networkidle');await page.waitForTimeout(600);await page.getByRole('textbox',{name:'E-mail da gestão'}).waitFor();
await page.screenshot({path:path.join(out,`login-${width}.png`)});
await page.getByRole('button',{name:'Entrar',exact:true}).scrollIntoViewIfNeeded();await page.screenshot({path:path.join(out,`acesso-${width}.png`)});
const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);assert.equal(overflow,false,'Overflow horizontal '+width);
}
assert.deepEqual(errors,[]);assert.deepEqual(external,[]);console.log('PASS marca52: entrada real 320/390/768/844/1440, formulário acessível, sem erros ou rede externa.');
fs.writeFileSync(path.join(out,'resultado.json'),JSON.stringify({passed:true,widths:[320,390,768,844,1440],browserErrors:errors,externalRequests:external},null,2));
}finally{if(browser)await browser.close();await new Promise(r=>server.close(r));}})().catch(e=>{console.error(e);process.exitCode=1;});
