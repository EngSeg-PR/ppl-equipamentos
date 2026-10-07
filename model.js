const MODEL = Object.freeze({id:'ppl-cinturao-talabarte',version:'0.5-piloto',equipmentMode:'component',title:'VERIFICAÇÃO INICIAL PERIÓDICA DE CINTO DE SEGURANÇA PARAQUEDISTA TIPO Y E TALABARTE',types:['Inspeção periódica (inicial)','Inspeção rotineira (pré-uso, conforme necessidade)','Inspeção periódica (até 12 meses da data inicial)'],items:[
{id:'compatibilidade',category:'COMPATIBILIDADE',target:'Conjunto',text:'O talabarte, trava quedas retrátil trava quedas deslizante e o cinturão de segurança são compatíveis entre si? Deve ser da mesmo fabricante.'},
{id:'fitas',category:'FITAS E COSTURAS',target:'Cinturão e talabarte',text:'As fitas do cinturão e talabarte encontram-se em perfeito estado de conservação isentos de: (borra de solda, desgastes prematuros, cortes, rompimento de costuras, fios rompidos, etc.)?'},
{id:'metalicos',category:'COMPONENTES METÁLICOS',target:'Cinturão e talabarte',text:'As fivelas estão livres trincas, fissuras, amassamentos ou corrosão?'},
{id:'indicador',category:'INDICADOR DE IMPACTO',target:'Cinturão',text:'O indicador de impacto do cinturão apresenta-se sem rompimento?'},
{id:'absorvedor',category:'ABSORVEDOR DE IMPACTO',target:'Talabarte',text:'O absorvedor de impacto do talabarte apresenta-se sem rompimento?'},
{id:'etiquetas',category:'ETIQUETAS',target:'Cinturão e talabarte',text:'As etiquetas estão presentes, íntegras e legíveis no cinturão e talabarte contendo: Número de CA, Referência, Número de Lote, etiqueta do INMETRO?'},
{id:'individual',category:'USO INDIVIDUAL',target:'Cinturão e talabarte',text:'O cinturão de segurança e talabarte são de uso individual e exclusivo do empregado não permitido seu compartilhamento?'},
{id:'soldagem',category:'MODELO',target:'Cinturão e talabarte',text:'O cinturão e talabarte utilizado em atividades de soldagem ou similares são do tipo para aramida?'},
{id:'eletrica',category:'MODELO',target:'Cinturão e talabarte',text:'O cinturão e talabarte utilizados em atividades elétricas possuem suas partes metálicas com proteção dielétrica?'}
]});
const ANSWERS=['Conforme','Não Conforme','Não Aplicável'];
if(typeof module!=='undefined')module.exports={MODEL,ANSWERS};


const MODEL_VERSIONS={ '0.1-transcricao-pendente':['PERIÓDICA','ROTINEIRA','PERIÓDICA (<12 VEZES DA DATA INICIAL)'], '0.2-piloto':['Inspeção periódica (inicial)','Inspeção rotineira (todos os dias, pré-uso)','Inspeção periódica (até 12 meses da data inicial)'], '0.3-piloto':MODEL.types,'0.4-piloto':MODEL.types,'0.5-piloto':MODEL.types };
