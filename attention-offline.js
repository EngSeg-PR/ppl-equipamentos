/* Static application files only. Assessment data stays in the app's protected repository. */
(() => {
  if (!('serviceWorker' in navigator)) return;
  const note = document.createElement('div');
  note.setAttribute('role', 'status');
  note.textContent = 'Preparando os recursos para uso sem conexão…';
  Object.assign(note.style, {position:'fixed',left:'12px',right:'12px',bottom:'10px',zIndex:'9999',padding:'10px 14px',borderRadius:'10px',background:'#142d45',color:'#fff',font:'13px system-ui,sans-serif',pointerEvents:'none'});
  document.body.append(note);
  navigator.serviceWorker.register('../sw.js').then(registration => {
    const pending = registration.installing || registration.waiting;
    if (!pending) return navigator.serviceWorker.ready;
    return new Promise((resolve, reject) => {
      const check = () => {
        if (pending.state === 'activated') resolve();
        if (pending.state === 'redundant') reject(Error('Recursos indisponíveis.'));
      };
      pending.addEventListener('statechange', check);
      check();
    });
  }).then(() => {
    note.textContent = 'Recursos preparados para abrir sem conexão neste navegador.';
    setTimeout(() => note.remove(), 7000);
  }).catch(() => {
    note.textContent = 'A preparação offline não foi concluída. Mantenha o aplicativo aberto e conectado.';
  });
})();
