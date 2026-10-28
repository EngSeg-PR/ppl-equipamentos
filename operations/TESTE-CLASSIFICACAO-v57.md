# Avaliação visual e classificação experimental — v57

Implementação de 28/10/2026. Ativação e verificação pública devem ser registradas separadamente. A classificação é um indicador estatístico preventivo, sujeito à validação pela equipe de saúde/estatística; não é diagnóstico, aptidão ou probabilidade de acidente. Não há liberação, bloqueio, punição ou encaminhamento automático.

**Ativação em 28/10/2026:** o proprietário autorizou especificamente o novo teste e a classificação. Migração aplicada e função completa57 implantada, com versão HTTPS57 confirmada e consultas privadas sem sessão negadas. Publicação das telas e verificação final registradas na retomada da entrega. A autorização específica sucedeu a recusa automática inicial, sem contornar a revisão de aprovação.

## Escopo e ressalvas do proprietário

- PRS. REIS é a identidade do app; PPL é uma das empresas usuárias.
- Permanecem empresa → colaborador → matrícula, cadastros existentes, gestão e privacidade atuais.
- Colaborador consulta somente a própria avaliação; gestão consulta o escopo autorizado no sistema.
- Avaliações anteriores foram identificadas pelo proprietário como testes de usabilidade. Não entram na referência do novo protocolo. Esta entrega não executa exclusão central ou limpeza do armazenamento dos aparelhos.
- Não foram criados resultados, empregados ou referências fictícias em produção.
- Queixas de saúde, dados psicossociais e sensores permanecem desativados, respeitando a ressalva de privacidade/cadastro. Não há associação automática a queixas que não são coletadas.

## Protocolo `visual-v1`

Leitura livre das instruções antes de iniciar. Após tocar em praticar: demonstração animada de 6 s, treino sem pontuação com uma apresentação parada e uma em movimento, confirmação de entendimento e avaliação. O participante pode repetir o treino.

São 30 apresentações (24 paradas, 6 em movimento), embaralhadas com aleatoriedade segura. Um círculo neutro de 72 px aparece em três posições horizontais possíveis; a resposta pode ser dada em qualquer ponto da área grande, por toque, clique ou barra de espaço/Enter. Repetição automática de tecla é ignorada. Cor, letra, número e forma não determinam a resposta. A oscilação suave de 1 Hz é parte essencial da regra, sem flashes: parado → responder; em movimento → aguardar. Dificuldade com a instrução ou com o movimento requer orientação.

Intervalo antes de cada apresentação: 800–1600 ms aleatórios; janela de resposta: 1000 ms; pausa: 200 ms. O orçamento nominal de demonstração + treino + teste é inferior a 96 s. A execução formal tem limite de 90 s e o fluxo ativo desde praticar tem limite de 114 s, incluindo demonstração, treino e espera na confirmação. Se a preparação expirar, recomeça pelas instruções. Se uma avaliação já iniciada expirar ou perder foco, registra o trecho incompleto. A suspensão do navegador pode atrasar callbacks; ao detectar o excesso não são fabricadas apresentações nem sessões completas.

Quantidade, proporção, intervalos e limiares de coleta ficam fixos nesta versão para manter a comparabilidade. Uma mudança desses parâmetros exige outra versão do protocolo e reavaliação das bases; não se permite configurar combinações que ultrapassem o orçamento de tempo.

## Evidência e cálculo

Gravação cifrada local antes de iniciar, na apresentação/fechamento e a cada entrada. Identificador estável, fila de envio e recibo sem duplicação. A retomada de uma aplicação interrompida preserva o trecho; nova aplicação é outro registro. Treino não é submetido como avaliação.

O plano exato fica no registro (`schedule`: tipo, espera e posição). `trials` registra sequência, apresentação e fechamento; `responses` registra ordem, instante e origem da entrada. O início é capturado após o quadro de apresentação, e a resposta no callback de início do ponteiro/tecla. `shownUs`/`tUs` guardam o relógio monotônico em microssegundos, conforme a resolução efetivamente oferecida pelo navegador/dispositivo; campos em milissegundos permitem inspeção. Estes callbacks não medem emissão física dos pixels ou contato físico: não há compensação presumida de latência.

Ambiente: execução web/nativa, tamanho da área, densidade e estimativa da frequência dos quadros observados quando há amostras suficientes. Não é certificação da taxa física da tela. Na web, solicita somente o modelo por User-Agent Client Hints, quando oferecido pelo navegador, com espera limitada a250 ms antes do cronômetro. Não coleta o User-Agent completo, número de série ou identificador do aparelho. O modelo fica explicitamente indisponível quando não é fornecido; não se infere um modelo a partir da resolução. Uso simultâneo de múltiplos pontos de toque é sinalizado.

O servidor valida tipos, limites, ordem, coerência temporal, identidade, empresa e escopo; recalcula as métricas, sem aceitar pontuação enviada pelo cliente. Preserva a decisão e a revisão dos parâmetros no registro original.

- Primeira resposta de cada círculo parado: abaixo de 100 ms → antecipação; de 100 ms até antes de 1000 ms → reação válida. Uma resposta antecipada não é substituída por um segundo toque para melhorar o resultado.
- Omissão: apresentação parada encerrada sem resposta. Um estímulo aberto na interrupção não é contado como omissão.
- Comissão: ao menos uma resposta na apresentação em movimento. Entradas adicionais ficam registradas separadamente.
- Antecipações: entradas fora de uma apresentação + primeiras respostas paradas abaixo de 100 ms. Não se atribui intenção.
- Lapso: reação válida estritamente acima de 500 ms; omissões são informadas separadamente.
- Média, mediana, DP populacional dos tempos válidos, percentis 10/90 por interpolação `(n−1)*p` e média dos `ceil(n*0,10)` mais rápidos/lentos (mínimo de um quando houver dados). Decil médio e percentil não são a mesma medida.
- Quatro blocos por posição `floor(indice*4/30)`; média das reações válidas em cada bloco. Declínio = média do último menos a do primeiro, nulo se um deles não tiver respostas válidas. Valor positivo indica lentificação observada nessa aplicação.
- Maior atraso de apresentação/fechamento medido em relação ao agendamento. Acima do limite técnico configurado (250 ms inicialmente), a análise recebe qualidade técnica insuficiente e não alimenta a referência.

## Classificação e bases

Cinco rótulos pedidos: Normal, Limítrofe, Alterado, Significativamente Alterado e Comportamento Inseguro. O último significa avaliação não interpretável por quebra da aplicação; a tela explica o motivo e orienta diálogo, sem pressupor culpa. Critérios técnicos iniciais: avaliação incompleta, nenhuma resposta válida, múltiplos pontos simultâneos ou quantidade de entradas fora da regra acima do parâmetro (48 inicialmente). Atraso técnico tem estado próprio, sem atribuição comportamental.

Base em formação, referência insuficiente e aguardando análise central são estados adicionais de disponibilidade/qualidade, não um sexto grau de desempenho. Ausência de base, parâmetro ausente ou dispersão nula com piora não geram Normal automaticamente.

Referências somente de testes completos elegíveis `visual-v1`, da mesma empresa, anteriores/disponíveis ao calcular, excluindo o ID corrente. Primeiros 6 testes elegíveis de cada pessoa são habituação. Base individual: últimos 30 elegíveis após habituação, mínimo de 30. Base populacional: até 5000 elegíveis recentes de outras pessoas, mínimo de 30 testes e 5 outras pessoas; mesma função/cargo por padrão, ou toda a empresa conforme configuração. A população é ponderada por avaliação, não balanceada por pessoa. Não há turno cadastrado adicional nem segmentação por atributos inexistentes.

Para cada parâmetro: `z=(valor_atual−média_referência)/DP_populacional_referência`. Parâmetros: mediana, média dos 10% mais lentos, DP dos tempos, lapsos, omissões, antecipações, comissões e declínio. Somente a direção de piora positiva eleva o nível. Nível final = maior z entre os parâmetros e as duas bases. Inicialmente: z ≤1 Normal; >1 até2 Limítrofe; >2 até3 Alterado; >3 Significativamente Alterado. Comparações usam valores sem arredondar; a explicação apresenta médias, DP e z arredondados.

DP zero com valor igual/melhor contribui zero; DP zero com piora torna a referência insuficiente. As duas bases e a amostra não nula de cada parâmetro precisam atingir os mínimos. O teste atual não participa de sua própria referência. As avaliações numéricas anteriores não são convertidas.

Recorrência preventiva configurável: inicialmente 3 resultados fora de Normal em janela de 5 classificações da mesma pessoa, protocolo e revisão de regra. Pode orientar diálogo adicional; não eleva automaticamente o nível calculado e não produz decisão de aptidão.

Os percentuais 68,2/27,2/4,2/0,4 não são quotas. Faixas bilaterais de uma curva normal não equivalem à frequência de alertas de uma regra unilateral que escolhe o pior de vários parâmetros correlacionados. É necessário validar distribuição, falsos alertas, compreensão, aprendizagem, diferenças de aparelho e utilidade preditiva no público real.

No modo offline, o resultado mostra medidas locais e aguarda o cálculo central. Ao confirmar o envio, recebe classificação, orientação, critérios e contagens agregadas das referências. Não envia dados de colegas ao aparelho.

## Administração, migração e limites

O proprietário/administrador existente ajusta faixas z, habituação, janela/mínimos de referência, função/empresa, regras técnicas de qualidade e recorrência em **Sistema Apto → Configuração da classificação experimental**. Gestores e colaboradores não alteram parâmetros. Alterações são versionadas, protegidas contra sobrescrita concorrente e não reescrevem avaliações anteriores. A condição experimental não pode ser removida pela tela.

Aplicar `supabase/visual-v57/CLASSIFICACAO-v57.sql`, depois `ATIVAR-v57.sql`, e a função completa `ppl-api-dashboard.ts` sobre `ppl-api-`. A fonte completa deriva da v55 e conserva executantes54, acompanhamento e demais módulos. Não há mudança de RLS ou permissão de leitura das avaliações. Somente o servidor executa o validador. Cache do site: 57; app: 0.3.0. Publicação depende de testes e prova HTTPS/UI registrados na retomada.

Referências consultadas: [distribuição normal — NIST](https://www.itl.nist.gov/div898/handbook/eda/section3/eda3661.htm) e [movimento essencial e preferências de animação — W3C](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html). Estas referências não validam o protocolo original. Homologação em aparelhos reais, Safari e avaliação de acessibilidade/compreensão permanecem necessárias.

## Verificação da entrega

Núcleo Dart:68 testes; suíte Flutter:45 testes; verificação final de acesso/histórico:15 testes e análise estática sem problemas. Banco/servidor visual:65 verificações; classificação:73 verificações. Regressões de acesso55:47, executantes54:82, acompanhamento54:106 e protocolo numérico51:42 passaram na função completa57.

A compilação web final passou pelo fluxo real em navegador e PostgreSQL local:30 apresentações, tempos de alta resolução, modelo de aparelho simulado, recibo perdido/reenvio sem duplicação, histórico anterior, recuperação em outro aparelho, troca de empresa/pessoa e gestão. A simulação de Client Hints foi corrigida no teste após verificar que o navegador retorna objetos distintos a cada acesso. Nenhuma alteração de produção foi feita para acomodar essa simulação.

Gestão: configuração versionada, detalhes/resultados/eventos em1440/390px e texto200%, sem sobreposição. Cache estático:200 recursos existentes. Atualização real do worker54→57, abertura offline, ausência de ciclo de recarga e armazenamento preservado passaram. Todos os dados sintéticos ficaram no ambiente isolado.

Em produção foram conferidas somente consultas de leitura: versão57, diretório restrito a nome/ID e negação401 para histórico/configuração sem sessão. A publicação do app é verificada por hash do JavaScript público e pela entrada real. Homologação humana do teste em dispositivos de campo permanece pendente.
