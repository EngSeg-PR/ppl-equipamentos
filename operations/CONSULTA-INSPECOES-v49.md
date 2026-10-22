# Consulta de inspeções e colaborador — 22/10/2026

Em **Gestão → Checklists e inspeções**, cada registro com PDF recebido oferece **Visualizar PDF** e **Baixar PDF**. A consulta abre uma janela com identificação do registro, colaborador, data, revisão, prévia do documento e ações para abrir em outra aba, baixar ou salvar/compartilhar no aparelho. A situação do acompanhamento tem uma ação secundária própria; consultar um PDF não abre nem altera essa situação.

Os bytes vêm da cópia original privada no servidor. Não há regeneração a partir da listagem: essa listagem não contém as fotos/assinaturas originais. Quando o PDF ainda não foi enviado, a consulta informa a pendência e orienta sincronizar o aparelho de origem; não declara arquivo pronto nem apresenta o acompanhamento como alternativa ao documento.

O seletor **Colaborador** e o campo **Pesquisar colaborador** aceitam nome/matrícula, considerando a identidade estável e os nomes/matrículas históricos encontrados nos registros autorizados. Homônimos são distinguidos pela matrícula e ID; empresas permanecem separadas. Declarações antigas sem ID só são associadas a uma pessoa conhecida quando o par nome/matrícula identifica um único ID. Os filtros de data, mês, tipo e conformidade combinam com o colaborador.

Cada inspeção aparece uma vez, na última revisão que corresponde aos filtros. Assim, a revisão feita por uma pessoa continua encontrável se outra pessoa registrou uma correção posteriormente. O seletor de revisões da consulta permite abrir o PDF exato de cada versão disponível dentro do acesso.

A navegação usa controle de ciclo de vida para ignorar respostas atrasadas após troca de módulo, atualização ou saída da sessão. Fechar a consulta ou sair do módulo libera os endereços temporários dos PDFs. Não há persistência desses arquivos no armazenamento da gestão.

Arquivos: `records-panel.js/css`, integração `management-page.js`, `management.html` e cache49. O servidor existente permanece na versão48: as rotas privadas `list`, `pdf` e `events` já suportam o fluxo. Sem nova migração de banco ou alteração de permissões.

Validação: `tests/records49-server.cjs` exercita o código real da API48 com dados/Storage/RLS simulados: bytes de PDF, paginação, sessão, empresa/equipe, pendências, arquivo ausente e caminho legado. `tests/records49-ui.cjs` e `tests/management-records49.cjs` conferem consulta, download, filtros, revisões, falhas e navegação no navegador com dados fictícios. Não usar essas capturas como prova de uma inspeção real.

Próxima homologação: o gestor consultar uma inspeção real já sincronizada e baixar sua cópia, incluindo teste no iPhone/Safari. PDFs que ainda estiverem apenas no aparelho de origem exigem o envio das pendências desse aparelho. Código salvo não equivale a backup do banco ou do Storage.
