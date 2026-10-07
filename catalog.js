const EQUIPMENT_CATALOG=[
{id:'arcofil',name:'Arcofil'},
{id:'cinto-y',name:'Cinto de segurança tipo Y com talabarte',modelId:'ppl-cinturao-talabarte'},
{id:'compressor',name:'Compressor'},
{id:'oxicorte',name:'Conjunto oxicorte'},
{id:'ferramentas-manuais',name:'Ferramentas manuais'},
{id:'gerador',name:'Gerador'},
{id:'guindauto',name:'Guindauto (caminhão Munk)'},
{id:'lixadeira',name:'Lixadeira'},
{id:'lixadeira-pneumatica',name:'Lixadeira pneumática'},
{id:'maquina-jato',name:'Máquina de jato'},
{id:'maquina-solda',name:'Máquina de solda'},
{id:'vasos-pressao',name:'Vasos de pressão'}
].sort((a,b)=>a.name.localeCompare(b.name,'pt-BR'));
let selectedEquipment='';
function renderEquipmentHome(){const w=$('#workspace');w.innerHTML=`<div class="panel equipment-home"><div class="eyebrow">01 · SELEÇÃO DO EQUIPAMENTO</div><h2>Qual equipamento você vai verificar?</h2><p>Selecione o tipo de equipamento para iniciar o checklist correspondente.</p><label class="equipment-label" for="equipment-select">Tipo de equipamento<select id="equipment-select"><option value="">Selecione um equipamento</option>${EQUIPMENT_CATALOG.map(e=>`<option value="${esc(e.id)}" ${e.id===selectedEquipment?'selected':''}>${esc(e.name)}</option>`).join('')}</select></label><div id="equipment-status" class="equipment-status" role="status"></div><button id="new" class="primary equipment-start" disabled>+ Nova inspeção</button><div class="welcome-steps"><div><b>01 · ESCOLHER</b><span>Selecione o equipamento que será utilizado.</span></div><div><b>02 · VERIFICAR</b><span>Preencha seu checklist específico e anexe evidências.</span></div><div><b>03 · PRESERVAR</b><span>Assine e registre a inspeção com ID e PDF.</span></div></div></div>`;$('#overview').hidden=true;$('#equipment-select').onchange=e=>{selectedEquipment=e.target.value;updateEquipmentChoice();};updateEquipmentChoice();}
function updateEquipmentChoice(){const e=EQUIPMENT_CATALOG.find(e=>e.id===selectedEquipment),ready=e?.modelId===MODEL.id;$('#new').disabled=!ready;$('#equipment-status').classList.toggle('equipment-pending',!!e&&!ready);$('#equipment-status').textContent=!e?'Escolha um equipamento para continuar.':ready?'Checklist disponível para o piloto: cinto tipo Y com talabarte.':'Checklist específico ainda não cadastrado. Este equipamento será incluído na próxima etapa.';}
function chooseEquipmentHome(){if(busy)return;current=null;render();message('');$('#workspace').scrollIntoView({behavior:'smooth',block:'start'});}
