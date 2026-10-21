# Cadastro de funcionários — versão 48

Pré-requisito: versão 47 já ativada. Aplicar `ATIVAR-v48.sql` no projeto existente e atualizar **a função existente `ppl-api-`** com o arquivo completo `ppl-api-dashboard.ts`. Não criar outra função nem trocar suas configurações de autenticação.

A migração adiciona catálogo de funções por empresa, vínculo opcional da função no funcionário, controle de alteração e histórico privado das identidades anteriores. As funções existentes são aproveitadas; as descrições individuais permanecem como estavam. Não exclui usuários, registros, alertas, modelos ou arquivos.

Somente o proprietário pode cadastrar/editar. A gravação do funcionário e da função ocorre em uma única transação. Matrícula continua única por empresa; atualização com uma versão desatualizada do cadastro retorna conflito. A descrição padrão só é alterada com a opção explícita da tela; outros funcionários não são alterados em conjunto.

Os documentos existentes mantêm seus dados e arquivos. Uma inspeção offline com a identidade anteriormente cadastrada continua podendo sincronizar: o servidor verifica um conjunto completo da identidade atual ou histórica dentro da mesma empresa. O histórico não contém CPF e não é disponibilizado no contexto público.

Verificação: cabeçalho `X-PPL-API-Version: 48`; consulta autenticada `employees` retorna `moduleVersion:48`, `rows` e `jobs`. O contexto público continua sem CPF, catálogo privado ou histórico.

Testes locais: `tests/employees48-server.cjs` (PGlite, função real de servidor e SQL), `tests/employees48-ui.cjs` (navegador com API simulada), regressão `tests/platform47-server.cjs` apontada para a função48 e testes de empresa/proprietário.
