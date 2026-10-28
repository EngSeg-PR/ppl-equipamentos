const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(path.resolve(__dirname,'../attention-offline.js'),'utf8');
const flush=async()=>{for(let i=0;i<5;i++)await new Promise(setImmediate);};
function run(registration){
 const notes=[],timers=[];let options,updates=0;
 const note={style:{},textContent:'',setAttribute(){},remove(){this.removed=true;}};
 const wrapped={...registration,update:async()=>{updates++;if(registration.update)await registration.update(wrapped);}};
 vm.runInNewContext(source,{navigator:{serviceWorker:{register:async(url,value)=>{assert.equal(url,'../sw.js');options=value;return wrapped;},ready:Promise.resolve()}},document:{createElement:()=>note,body:{append:n=>notes.push(n)}},location:{reload(){throw Error('Recarregamento automático proibido.');}},setTimeout:callback=>timers.push(callback),Error,Promise,Object});
 return {note,wrapped,timers,get updates(){return updates;},get options(){return options;}};
}
(async()=>{
 let listener;
 const pending={state:'installing',addEventListener:(name,callback)=>listener=callback};
 const first=run({active:{},update:async reg=>{reg.installing=pending;}});await flush();
 assert.equal(first.options.updateViaCache,'none');assert.equal(first.updates,1);assert(first.note.textContent.startsWith('Preparando'));
 pending.state='activated';listener();await flush();assert(first.note.textContent.startsWith('Recursos preparados'));assert.equal(first.timers.length,1);first.timers[0]();assert(first.note.removed);
 const offline=run({active:{},update:async()=>{throw Error('Sem rede de teste');}});await flush();assert(offline.note.textContent.startsWith('Recursos preparados'));
 const failure=run({update:async()=>{throw Error('Falha inicial de teste');}});await flush();assert(failure.note.textContent.startsWith('A preparação offline não foi concluída'));
 let activation;const existing={state:'installing',addEventListener:(name,cb)=>activation=cb};
 const installing=run({installing:existing});await flush();assert.equal(installing.updates,0);existing.state='activated';activation();await flush();assert(installing.note.textContent.startsWith('Recursos preparados'));
 console.log('PASS atualização56: revalidação explícita, espera da ativação, offline existente preservado, falha inicial honesta e nenhum recarregamento automático.');
})().catch(e=>{console.error(e);process.exitCode=1;});
