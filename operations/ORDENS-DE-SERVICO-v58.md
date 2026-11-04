# Ordens de serviço — v58

Entrega de 03/11/2026 baseada no commit 568ffbf (interface e API57). Mantém integralmente o Sistema Apto57, os acessos pessoais55 e os cadastros existentes. Não requer SQL nem altera permissões.

## Comportamento

- Descrição da atividade alinhada à esquerda no PDF, inclusive quando a origem contém quebras de linha. Conteúdo longo continua em páginas adicionais, sem cortes.
- Novo modelo `certificates-4-v3`: assinatura **Em papel** ou **No sistema**. Em papel deixa o campo vazio e sinaliza coleta pendente; No sistema exige desenho. Nenhuma modalidade é comprovação automática de ciência.
- **PDF para impressão** cria uma cópia separada sem a imagem da assinatura do colaborador. O snapshot registrado e os bytes dos PDFs anteriores permanecem intactos.
- Downloads: `PPL_ORDEM DE SERVICO_NOME DO COLABORADOR.pdf`; cópia física com sufixo `_IMPRESSAO`. Identidade vem do cadastro congelado no registro, não de uma edição posterior do funcionário.
- Cards compactos: empresa, documento, colaborador, data e três ações curtas. PDFs duplicados não aparecem como botões repetidos; os arquivos históricos continuam no arquivo central.
- Ao baixar uma OS antiga, prepara a cópia de layout58 sem substituir o original. Repetir a emissão da mesma variante reutiliza o arquivo já guardado.
- Falha de PDF ou upload mantém o documento salvo para nova tentativa. Sair do módulo invalida resultados tardios.

## Verificação local

- `tests/os58-server.cjs`: 55 verificações isoladas, incluindo assinatura física/digital, versões antigas, identidade canônica, conflito, escopo e hash. Confere que o código fora do catálogo/OS/versão é igual à API57.
- `tests/service-order58-pdf.cjs`: alinhamento do parágrafo reportado, PDF para impressão sem imagem, original imutável e texto extenso integral.
- `tests/os58-documents-ui.cjs`: 30 verificações com dados fictícios, telas 1440/390, nomes de arquivo, layout antigo corrigido no download, reutilização, erro/retry e saída durante geração.
- `tests/release58-offline.cjs`: atualização de cache57 para58, abertura do Apto offline, único service worker e armazenamento preservado. Não comprova OS offline: o módulo central de documentos continua exigindo conexão.
- Verificação sintática dos scripts modificados e revisão visual dos PDFs e telas locais. Nenhum teste fictício foi gravado em produção.

## Publicação e preservação

A função atual foi baixada pelo painel Supabase e comparada com a fonte local57: conteúdo equivalente, SHA-256 normalizado `c5dbd50f881949906fead294c943d11629e2ef361cf36d49ed31e4dfc7820449`. A fonte completa58 fica em `supabase/documentos-v58/ppl-api-dashboard.ts`.

A ativação e a verificação pública devem ser registradas após conclusão. Fotografias de código não contêm banco central, Auth, Storage nem pendências de aparelhos. O teste em iPhone/Safari real e a coleta física de assinatura permanecem homologações do proprietário.

## Pedido de checklist cancelado

O usuário informou que o Excel Anexo02 era o arquivo errado e cancelou a alteração dos checklists em 03/11/2026. Nenhum arquivo de modelo, pergunta, PDF, seleção ou cadastro PPL/Vale foi modificado por esse pedido. Aguardar o documento correto antes de retomar.
