(()=>{
const button=document.querySelector('#owner-refresh'),status=document.querySelector('#owner-update-state');let registration;
if(!button||!status)return;
async function check(){if(!navigator.onLine||!('serviceWorker'in navigator))return;try{registration=await navigator.serviceWorker.register('sw.js',{updateViaCache:'none'});await registration.update();}catch{status.textContent='Não foi possível conferir atualizações agora. Tente novamente conectado.';}}
if('serviceWorker'in navigator)navigator.serviceWorker.addEventListener('controllerchange',()=>{status.textContent='Atualização disponível. Salve o que estiver preenchendo e clique em Atualizar tela.';});
button.onclick=async()=>{if(!navigator.onLine){status.textContent='Conecte-se à internet para atualizar a tela.';return;}button.disabled=true;status.textContent='Conferindo a versão mais recente…';try{await check();const worker=registration?.installing;if(worker)await new Promise(resolve=>{const timer=setTimeout(resolve,12000);worker.addEventListener('statechange',()=>{if(['activated','redundant'].includes(worker.state)){clearTimeout(timer);resolve();}});});location.reload();}finally{button.disabled=false;}};
window.addEventListener('online',check);document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')check();});check();
})();
