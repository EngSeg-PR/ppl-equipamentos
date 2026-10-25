/* Reproducible packaging of the canonical Flutter build into the existing site. */
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),source=path.resolve(root,'../triagem-atencao/app/build/web'),target=path.join(root,'triagem');
if(!fs.existsSync(path.join(source,'main.dart.js')))throw Error('Compile o app Flutter para web antes de preparar a publicação.');
fs.cpSync(source,target,{recursive:true});
const indexFile=path.join(target,'index.html');let html=fs.readFileSync(indexFile,'utf8');
if(!html.includes('<base href="/">'))throw Error('Base do build inesperada; confira a configuração de hospedagem.');
html=html.replace('<base href="/">','<base href="/ppl-equipamentos/triagem/">').replace('</body>','<script src="../attention-offline.js?v=51" defer></script></body>');fs.writeFileSync(indexFile,html);
const walk=folder=>fs.readdirSync(folder,{withFileTypes:true}).flatMap(entry=>entry.isDirectory()?walk(path.join(folder,entry.name)):[path.join(folder,entry.name)]);
const files=walk(target).map(file=>path.relative(root,file).replaceAll(path.sep,'/')).filter(file=>!file.includes('skwasm')&&!file.endsWith('.symbols')&&!file.endsWith('.map')&&!path.basename(file).startsWith('.'));
files.push('attention-offline.js');
let sw=fs.readFileSync(path.join(root,'sw.js'),'utf8');
const declaration='const ATTENTION_STATIC='+JSON.stringify(files)+';';
if(sw.includes('const ATTENTION_STATIC='))sw=sw.replace(/^const ATTENTION_STATIC=.*;$/m,declaration);
else sw=declaration+'\n'+sw;
if(!sw.includes('addAll([...ATTENTION_STATIC,'))sw=sw.replace('addAll([','addAll([...ATTENTION_STATIC,');
const hook="const base=new URL(self.registration.scope);if(url.pathname.startsWith(base.pathname+'_pdf/')";
if(!sw.includes("base.pathname+'triagem/'")){
  if(!sw.includes(hook))throw Error('Ponto de integração do cache não encontrado.');
  const branch="const base=new URL(self.registration.scope);if(url.pathname.startsWith(base.pathname+'triagem/')){e.respondWith((async()=>{const cache=await caches.open(CACHE),entry=e.request.mode==='navigate'?new URL('triagem/index.html',base).href:e.request;const hit=await cache.match(entry,{ignoreSearch:true});if(hit)return hit;try{const response=await fetch(e.request);if(response.ok)await cache.put(e.request,response.clone());return response;}catch{return new Response('Abra o aplicativo conectado uma vez para preparar o uso sem conexão.',{status:503,headers:{'Content-Type':'text/plain; charset=utf-8'}});}})());return;}if(url.pathname.startsWith(base.pathname+'_pdf/')";
  sw=sw.replace(hook,branch);
}
fs.writeFileSync(path.join(root,'sw.js'),sw);
if(!sw.includes("const ownerFiles=['attention-offline.js',")) {
  sw=sw.replace('const ownerFiles=[',"const ownerFiles=['attention-offline.js',");
  fs.writeFileSync(path.join(root,'sw.js'),sw);
}
for(const name of files){if(!fs.existsSync(path.join(root,name)))throw Error('Recurso ausente: '+name);}
const main=fs.readFileSync(path.join(target,'main.dart.js'),'utf8');
if(main.includes('COLABORADOR DE TESTE')||main.includes('operador@teste.invalid'))throw Error('O build contém dados reservados aos testes.');
console.log('Aplicativo preparado em triagem/: '+files.length+' recursos de cache. Somente código e ativos estáticos, sem registros.');
