# Histórico de avaliações de atenção — v51

Integração solicitada por Paulo Ricardo: preservar cada avaliação no aplicativo e disponibilizar a mesma avaliação na plataforma PRS. REIS/SSMA existente.

## Arquivos para ativação

1. `ATIVAR-v51.sql`: migração incremental sobre o banco PRS. REIS existente. Cria somente os objetos do histórico de atenção e o vínculo composto com o colaborador. Não apaga ou reescreve inspeções, PDFs, usuários ou cadastros.
2. `ppl-api-dashboard.ts`: fonte completa da função **ppl-api-**, baseada na versão48 com as novas ações autenticadas. Atualizar a função existente, preservando sua configuração e suas variáveis seguras; não criar outra função ou outro projeto.
3. Interface: `attention-history.js/.css`, `management-page.js`, `management.html`, `owner.js`, `owner.html`, `staff-dossier.js`, `sw.js` e o marcador do cache em `app.js`.

A ativação exige migração e função antes da nova interface. O SQL independente recebido no anexo, em `triagem-atencao/supabase/`, é uma base anterior de outro desenho de implantação; **não deve ser aplicado ao banco PRS. REIS existente** para esta integração. Usar esta migração v51.

## Acesso e histórico

- Proprietário: **Avaliações de atenção**, usando a empresa selecionada.
- Gestão: **Avaliações de atenção** e atalho pelo dossiê do colaborador.
- Filtros: colaborador, intervalo de datas e completa/incompleta. Datas da plataforma são apresentadas no fuso America/Fortaleza.
- O detalhe exibe identificação histórica, local da avaliação, horários, versão, métricas e toques. Uma mudança posterior no cadastro não reescreve a avaliação.
- As consultas usam autenticação e RLS por empresa/unidade/equipe. Não há consulta ou gravação pública de resultados.
- O aplicativo conserva cópia local antes de mostrar o resultado e mantém envio pendente até confirmação. A mesma avaliação usa o mesmo UUID; repetição idêntica devolve `duplicada`, conflito devolve409 e preserva o original.
- O servidor revalida os eventos e calcula suas próprias métricas. Não recebe um semáforo ou uma liberação clínica produzida pelo app.

O cadastro atual não vincula cada funcionário a unidade/equipe. O local declarado na avaliação é validado contra o escopo do operador; não é apresentado como lotação oficial do funcionário.

## Contrato

Todas as ações abaixo exigem `Authorization: Bearer <sessão Supabase do gestor/proprietário>`:

- `attention-context {companyId?}`: empresas autorizadas, empresa selecionada, colaborador sem CPF, escopos e protocolo.
- `attention-submit {companyId, assessment}`: `{id, employeeId, unit, team, moment, startedAt, finishedAt, status, durationMs, grid, touches, protocolVersion, appVersion}`. Toques: `{seq,tMs,touched,expected,correct}`. Protocolo: `sequencia-v1`.
- `attention-history-list {companyId, employeeId?, dateFrom?, dateTo?, status?, offset?, limit?}`: `{rows,nextOffset,moduleVersion:51}`.
- `attention-history-detail {companyId,id}`: `{assessment,moduleVersion:51}`.

## Verificações locais

`tests/attention51-server.cjs` executa a migração duas vezes e o handler real em PostgreSQL portátil descartável, com Auth simulado. São42 verificações, incluindo RLS, revogação, métricas, conflitos, imutabilidade e snapshots.

`tests/attention51-ui.cjs` consulta a API real desse ambiente de teste pelo navegador, conferindo filtros, detalhes, toques, respostas tardias e telas1440/390px.

`tests/attention51-e2e.cjs` verifica o aplicativo compilado contra o mesmo handler e SQL locais. As chamadas ao endereço do projeto são interceptadas no navegador antes de qualquer envio de rede. A autenticação é fictícia e não usa credenciais reais.

Os testes usam Node.js, cliente `pg`, PostgreSQL portátil17 e Playwright. Caminhos de dependências e navegador podem ser indicados por `PRS_PG_MODULE`, `PRS_PG_ROOT`, `PRS_PLAYWRIGHT_MODULE` e `PRS_CHROME_PATH`. Os dados descartáveis ficam em `work/`; os servidores são desligados ao terminar.

Isso não homologa o fluxo completo com uma conta real, o APK ou o tablet físico. Após autorização do proprietário em25/10/2026, a migração foi ativada e a função existente passou a responder API51. A consulta de produção confirmou zero avaliações, RLS ativo e função de gravação pronta. Uma chamada sem login confirmou401 na API51. Nenhuma avaliação fictícia foi criada em produção.

O app web é preparado por `tools/preparar-triagem-web.cjs` a partir do build Flutter canônico. A publicação usa `triagem/` no mesmo site, com o acesso em `https://engseg-pr.github.io/ppl-equipamentos/triagem/`. Os recursos estáticos são preparados para abertura offline; dados e chamadas de gravação não são armazenados no cache do site. O histórico protegido usa seu próprio repositório.
