# Executantes e Sistema Apto — servidor54

Base integral: `supabase/triagem-v51/ppl-api-dashboard.ts`. A função continua com o nome **ppl-api-**, no projeto existente. Esta pasta prepara a atualização; sua presença no repositório não comprova ativação remota.

## Ordem de ativação

1. Preservar a versão remota e manter o backup de banco/arquivos sob controle do proprietário.
2. Aplicar **`ATIVAR-v54.sql`** no banco que já possui a migração51. Ele reúne `ATIVAR-EXECUTANTES-v54.sql` e `attention-followup.sql` em uma transação. A atualização é incremental e repetível; não remove avaliações, inspeções, documentos, modelos ou usuários.
3. Atualizar a função existente com **todo** o conteúdo de `ppl-api-dashboard.ts`. Não substituir pela versão48/51 nem apenas pelo fragmento de acompanhamento. As variáveis secretas existentes permanecem no serviço.
4. Publicar o frontend compatível54, testar login, saída, identidade automática e PDFs/pendências em ambiente de homologação. O contexto público54 deixa de devolver matrículas e descrições; a gestão deve refazer seu contexto depois do login.
5. Somente então o proprietário ativa a exigência por empresa com `executor-config {companyId, required:true}`. O padrão da migração é **false** para evitar uma transição brusca sobre aparelhos antigos. A interface nova pede login para novos registros; a flag controla a obrigatoriedade no recebimento central.

## Contrato executante

Todas as ações usam POST JSON no endpoint já existente. Credencial de sessão vai exclusivamente no cabeçalho **X-PPL-Executor**, nunca no registro, PDF, URL ou hash de evidência.

- `executor-directory {slug|companyId}`: `company`, `employees` somente `id/name`, `executorAccessRequired`, `moduleVersion:54`.
- `executor-login {slug|companyId, employeeId, password}`: matrícula atual exata como senha. Resposta contém `executorToken`, `expiresAt` UTC, empresa e somente o perfil desse colaborador (`id/name/employee_number/job_title/job_description`), sem CPF.
- `executor-session {slug|companyId}` com cabeçalho: perfil atual e expiração, sem emissão de outro token.
- `executor-logout {slug|companyId}`: revoga a sessão. Não remove registros nem pendências locais.
- `company-context`: público sem funcionários; com sessão de executante, somente o próprio perfil; com JWT de gestor/proprietário autorizado à empresa, cadastro profissional para os módulos existentes, sem CPF.
- `executor-config {companyId, required:boolean}`: exclusivo do proprietário autenticado, com histórico da alteração.

Sessões são opacas, aleatórias, com validade de12h e somente hash SHA256 persistido. Alterar matrícula ou situação ativa revoga sessões existentes no banco. Há cota persistente de8 tentativas por colaborador e120 por empresa, em15min. A matrícula permanece um segredo fraco/conhecido, inclusive presente em documentos profissionais; isso não é autenticação forte, assinatura certificada ou prova definitiva de identidade.

As cotas atuais contam também entradas bem-sucedidas. Uma troca de turno com mais de120 entradas em15min pode atingir a cota da empresa. Antes de uso comercial em efetivo maior, homologar o volume real e separar tentativas malsucedidas da proteção global de tráfego, sem remover o controle de abuso. Aumentar o limite indiscriminadamente não resolve a fragilidade de uma matrícula conhecida.

## Evidência e transição

Com exigência ativa, o servidor confere empresa, ID do colaborador e identidade atual ou histórica completa48. Uma alteração cadastral não força a reescrita do PDF original. Inspeção antiga sem `staff.id` pode sincronizar autenticada pelo autor correspondente ao snapshot registrado; o conteúdo não recebe campos de autenticação e seu digest é preservado. Inspeções de outro autor exigem entrada pelo autor original. Expiração/revogação nunca autoriza apagar a fila local.

O contexto da gestão valida empresa concedida. A associação de empregados a unidade/equipe não existe no cadastro atual; a lista cadastral da gestão mantém o alcance por empresa já adotado na51, enquanto consultas de inspeções e avaliações continuam protegidas pelo escopo de cada registro no servidor.

## Sistema Apto

O contrato51 do app Flutter e seus resultados `completa/incompleta` foram preservados. A função54 acrescenta dashboard agregado e acompanhamento administrativo separado, com histórico auditável e concorrência por revisão. Não cria critérios de aptidão nem transforma métricas em autorização para dirigir. A preparação do app Apto continua usando a conta de gestão existente; o login por matrícula é do executante de checklists/inspeções.

## Verificação local

`tests/executor54-server.cjs` executa PostgreSQL descartável e o handler completo: migração repetida, exposição de cadastros, login/limites, troca de empresa/autor, revogação, expiração, histórico48, submissão sem duplicação, RLS, CORS e compatibilidade51. Os resultados descrevem testes locais; nenhum teste escreve avaliações fictícias em produção.

Em27/10/2026:80 verificações aprovadas no handler completo54 e PostgreSQL17 real, incluindo consulta e acompanhamento APTO54. Relatório local `work/attention51-1793153382630/executor54-summary.json` (fora do Git). Teste específico do dashboard/acompanhamento fica em `tests/apto54-server.cjs`.
