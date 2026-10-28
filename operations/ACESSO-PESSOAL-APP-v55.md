# Acesso pessoal no app PRS. REIS — versão55 — 28/10/2026

## Escopo definido pelo proprietário

O app pertence à PRS. REIS. PPL Manutenção é uma das empresas cadastradas, sem exclusividade ou alteração da identidade do app. Seleção de empresa → lista de colaboradores ativos daquela empresa → matrícula como senha. Colaborador consulta apenas seu próprio histórico no app; gestão consulta pelo sistema existente. Nenhum campo cadastral recomendado no planejamento foi acrescentado. Gestão, acompanhamento e documentos de privacidade foram preservados conforme a versão54 já publicada.

Esta é a primeira etapa da reformulação. O protocolo numérico `sequencia-v1` e seus resultados foram mantidos nesta entrega; novo teste de sonolência/fadiga, classificações e critérios clínicos não foram implantados.

## Integração com a versão já publicada

Durante o trabalho foi encontrada a atualização54 na main, commit9f6e37f, com login de executantes e dashboard Sistema Apto. Ela foi incorporada antes de concluir a implementação. A versão55 reutiliza `executor-directory`, `executor-login`, `executor-session`/`executor-logout`, sessões opacas de12h, revogação e limites já existentes. Não cria outra credencial, conta Supabase ou campo de empregado.

A função completa é `supabase/acesso-v55/ppl-api-dashboard.ts`, baseada integralmente em `supabase/executantes-v54/ppl-api-dashboard.ts`. Mantém funções de executante, dashboard e acompanhamento54 e acrescenta três ações do app. Não substituir o servidor pela fonte antiga51.

`ATIVAR-v55.sql` acrescenta somente uma função privada de recebimento, `ppl_attention_employee_submit_v55`, executável pelo serviço. Não altera tabelas, cadastros, políticas RLS, regras de gestão ou avaliações antigas. O servidor valida a sessão opaca, a empresa e o empregado em cada operação. A função privada confere novamente que o autor é o empregado da avaliação e calcula as métricas com a validação do protocolo existente.

## Contrato do app

- `companies`: mantém o catálogo existente; app apresenta empresas prontas.
- `executor-directory {companyId}`: nomes e IDs dos colaboradores ativos. Matrícula não é exibida na lista de entrada.
- `executor-login {companyId,employeeId,password}`: matrícula exata, preservando zeros iniciais e regras da versão54.
- `attention-employee-context {companyId}`: cabeçalho `X-PPL-Executor`; somente a própria identidade e a empresa da sessão.
- `attention-employee-submit {companyId,assessment}`: mesma sessão, rejeita outro empregado e outra empresa; UUID estável e reenvio sem duplicação.
- `attention-employee-history {companyId,offset?}`: registros somente daquele empregado/empresa, inclusive avaliações anteriores criadas pela gestão; páginas de20 registros.

A gestão continua usando seus endpoints e autenticação Supabase anteriores. A sessão de colaborador não abre endpoints de gestão. Consulta central não substitui pendências ou cópias locais já existentes. Troca de usuário não apaga o histórico cifrado da conta anterior. Resposta atrasada de outra sessão não é aplicada à sessão nova.

## Verificações executadas

- Análise Flutter sem problemas;36 testes completos aprovados após integrar a autenticação54. Testes específicos adicionais de sessão vencida e resposta central de outra identidade aprovados na rodada direcionada de8 testes.
- `tests/access55-server.cjs`:47 verificações em PostgreSQL descartável e handler completo, duas empresas, credenciais, acesso pessoal, revogação/expiração, limitação, gestor e acompanhamento preservados. Migrações repetidas.
- `PRS_ACCESS55=1 node tests/attention51-server.cjs`:42 verificações de regressão do histórico/gestão, RLS, métricas e idempotência contra o servidor55.
- `tests/access55-e2e.cjs`: app compilado, login pessoal, histórico anterior criado pela gestão, teste36, perda simulada do recibo, reenvio sem duplicação, consulta em outro aparelho, troca de empresa/pessoa e histórico da gestão preservado. Nenhuma chamada real a produção; chamadas ao endereço configurado são interceptadas antes da rede.
- `tests/release55-offline.cjs`: cache54→56 real, um worker, sem recarga repetida, abertura offline e armazenamento local de teste preservado.
- `tests/attention51-cache.cjs`:200 recursos existentes, sem duplicação, rota offline correta e POSTs fora do cache.
- Layout novo testado em320/390/1440, incluindo fonte ampliada; demais layouts de histórico e detalhes mantêm os testes anteriores. Capturas de entrada conferidas em1440/390.

Dados fictícios somente em testes locais. Não foram criados colaboradores ou avaliações fictícias em produção.

## Estado e ativação

Ativação confirmada pelo proprietário em28/10/2026. Função privada aplicada e verificada: serviço pode executar; anon/authenticated não podem. A função existente ppl-api- foi atualizada com a fonte completa55, conferida contra a base54 remota antes da substituição. A API respondeu55; diretório retorna somente id/name e consultas de contexto/histórico sem sessão foram recusadas com401. Nenhuma avaliação de produção foi criada.

Frontend/cache56 publicado na rota existente e conferido por HTTPS: bootstrap, manifesto, cache, menus e painel de gestão preservados retornaram200. SHA256 do main.dart.js coincide com o build: e8f41413afdbd286172729fae263d9be1ce12670a0c718374d289cbda670d093. A conferência visual da entrada real completa a entrega, sem gerar avaliações ou limpar o armazenamento.

## Limitações preservadas

Matrícula é um controle básico, não autenticação forte ou prova de identidade. Sessões e cotas são as já existentes54 (12h;8 tentativas por empregado e120 por empresa em15min). Primeiro login exige conexão; acesso já preparado depende de sessão válida. Revogação remota só é conhecida quando conectado; a cópia local mantém as limitações de proteção do navegador já documentadas. APK, Safari e dois aparelhos reais continuam sujeitos a homologação.


## Atualização do navegador — cache56

A verificação no navegador com cache antigo motivou revalidação explícita do service worker com updateViaCache:none e registration.update(). O aviso aguarda a ativação; não força recarregamento durante avaliações. Testes attention-update56.cjs e worker real54→56 passaram, com armazenamento preservado. O aplicativo e a API permanecem na entrega55; o cache estático é56.

## Conferência final em produção — 28/10/2026

Entrada real aberta e conferida no endereço existente: identidade PRS. REIS, seleção de empresa e lista de colaborador apareceram corretamente. A empresa PPL Manutenção foi usada apenas para conferir o carregamento do diretório; nenhum colaborador foi autenticado e nenhuma avaliação foi criada em produção. App deixado aberto no navegador integrado. Captura: outputs/verificacao/app-acesso-pessoal-publicado-v55.png. API55, cache56 e hash do aplicativo conferidos por HTTPS; a política e o termo54, os cadastros e a gestão permaneceram preservados.
