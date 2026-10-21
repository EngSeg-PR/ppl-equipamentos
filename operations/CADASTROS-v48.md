# Funcionários e funções reutilizáveis — 21/10/2026

No acesso do proprietário, selecionar **Funcionários e funções** e a empresa desejada. Preencher o nome e a matrícula, selecionar uma função cadastrada ou **Nova função / preencher manualmente**. A função selecionada preenche sua descrição; os botões **Editar função** e **Editar descrição** liberam os campos automáticos.

Ao salvar uma nova função, ela fica disponível nos cadastros seguintes da mesma empresa. A opção **Usar esta descrição nos próximos cadastros desta função** altera somente o padrão para uso futuro. Os dados dos demais funcionários e os documentos emitidos permanecem preservados.

Cada funcionário cadastrado tem **Editar**, com nome, matrícula, CPF, função e descrição do cargo. O ID do colaborador permanece estável, inclusive nos vínculos do dossiê. CPF é opcional, validado e restrito ao cadastro/autorização documental já existente; não é publicado no contexto do executante.

O servidor bloqueia matrícula duplicada, funcionário/função de outra empresa e edição de um cadastro alterado em outra tela. A transação reverte também uma nova função caso a gravação do funcionário falhe. O histórico imutável de identidades mantém a compatibilidade com inspeções antigas pendentes sem reescrever seus conteúdos nem PDFs.

Arquivos: `owner-employees.js/css`, integração `owner.js/html`, cache48 e migração/função completa em `supabase/cadastros-v48/`. O histórico administrativo não é um sistema de assinatura digital; preserva os valores anteriores reconhecidos pelo cadastro.

Validação local: servidor/SQL real com dados fictícios isolados, registros offline com identidade anterior, retentativa sem duplicar, acesso de proprietário/gestor/anônimo, isolamento, CPF privado, conflitos e rollback; interface 390 px e desktop, preenchimento, edição integral, mudança de empresa, seleção de nova função, erro de gravação e versão incompatível. Nenhum funcionário ou documento fictício é cadastrado em produção.

Homologação: proprietário testar um cadastro real autorizado na tela publicada e confirmar a próxima emissão de certificado/OS. Conferir também a atualização dos cadastros em aparelhos previamente offline após reconexão. Backup de código não substitui backup do banco/Storage.
