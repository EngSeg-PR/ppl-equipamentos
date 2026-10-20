# Ajustes v46

Ativada em 20/10/2026: SQL confirmou v1 inativa/v2 ativa; API confirmou cabeçalho 46. `ATIVAR-v46.sql` acrescenta os campos cadastrais da empresa e a inspeção própria PPL versão 2 em uma transação. A versão 1 permanece preservada para histórico e envio de pendências antigas. Não exclui usuários, inspeções, alertas ou evidências.

Para reaplicar: executar o SQL completo no projeto existente e substituir todo `index.ts` da função **ppl-api-** pelo conteúdo de `ppl-api-dashboard.ts`. Preservar segredos e autenticação. Confirmar o cabeçalho `X-PPL-API-Version: 46`, inspeção v2 ativa e site v46.

Os dados CNPJ/CNAE/gestor ficam restritos ao proprietário; respostas públicas de marca não os incluem. Cadastro novo é transacional. Edição altera somente esses três campos, preservando nome/logo. CNPJ e CNAE recebem validação estrutural, sem consulta de regularidade cadastral.

O conteúdo da frequência só substitui o catálogo quando o gestor usa Editar conteúdo. Título e carga catalogados continuam validados. Certificados novos v3 têm espaços opcionais para responsável técnico, instrutor e colaborador. Modelos e PDFs históricos permanecem preservados.

Testes persistidos: `tests/management-server.cjs`, `tests/owner-company.cjs`, `tests/training-workflow.cjs`, `tests/training-pdf.cjs` e `tests/inspection-model.cjs`. Dados fictícios; nenhuma emissão de teste gravada em produção.
