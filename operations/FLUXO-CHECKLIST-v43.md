# Fluxo de checklist — versão 43

Esta atualização altera somente o aplicativo. A função Supabase permanece na versão 42; não há SQL nem atualização manual do servidor para esta entrega.

## Comportamento
- Abrir um modelo é uma prévia: não cria registro em IndexedDB, cópia de recuperação ou contador de rascunhos.
- O rascunho começa na primeira alteração de preenchimento e continua recuperável. Cancelar a escolha de fotos ou limpar uma assinatura vazia não grava rascunho.
- Salvar exige as validações existentes. Depois da confirmação local (ou confirmação central no fallback existente), o registro fica encerrado e a tela retorna à seleção de equipamento/modelo.
- O PDF é preparado sem manter o formulário aberto; a confirmação mostra acesso ao registro e ao arquivo. Geração de PDF ou rede indisponível não transformam o registro concluído em rascunho.
- Salvar sem internet mantém o registro e o PDF no aparelho. A aba Pendentes mantém o envio e a consulta; o recebimento central continua sendo confirmado separadamente.
- Gravações automáticas atrasadas não podem reabrir o formulário encerrado nem substituir a mensagem de conclusão. A lista ignora resultados de consultas anteriores quando já há uma consulta mais recente.
- Ao retornar à seleção, o alvo de retomada é limpo. Ao recarregar, somente rascunhos reais são retomados; registro concluído antigo não força reabertura da edição.
- Download usa o arquivo PDF gerado em memória; o endereço local estável continua disponível para abertura. Isso evita o cancelamento de download offline observado no teste do navegador.

Os rascunhos e registros anteriores não foram apagados. Esta alteração não reclassifica automaticamente um rascunho antigo como concluído: a validação e o salvamento são necessários.

## Regressão automatizada

Arquivo: tests/checklist-lifecycle.cjs. Requer Node, Playwright e Chromium/Chrome. Pode-se indicar o módulo Playwright por PRS_PLAYWRIGHT_MODULE e o executável por PRS_CHROME_PATH. Executar a partir de qualquer diretório com `node tests/checklist-lifecycle.cjs` apontando para o arquivo correto.

Usa servidor local, navegador isolado, modelo Arcofil existente e respostas simuladas para as chamadas Supabase. Não grava registros em produção. Imagens de teste são sintéticas. Capturas ficam em uma pasta temporária própria.

Cenários: conectado; offline; falha de rede; falha de geração PDF com recuperação; falha de armazenamento offline com nova tentativa. Verifica abertura sem rascunho, formulário vazio inválido, cancelamento de foto, assinatura vazia, rascunho real e retomada, preenchimento/assinatura/foto, gravação automática concorrente, encerramento, PDF local, download de bytes PDF offline, retorno à seleção, retomada de registro antigo concluído, pendências e reconexão com uma identidade central única.

A validação física no Safari/iPhone continua sendo homologação distinta. O navegador e o sistema operacional controlam a pasta e o compartilhamento do arquivo; a aplicação não força uma pasta arbitrária do aparelho.
