# Identidade visual do aplicativo — v52 — 25/10/2026

A interface de avaliações de atenção usa as duas artes PRS. REIS fornecidas pelo proprietário. Os PNGs originais ficam em `attention-app/app/assets/`, sem recriação ou distorção. `lib/brand.dart` centraliza logo, cabeçalho, cores e apresentação de datas.

## Alterações

- Entrada em duas colunas em telas amplas e rolagem vertical em telas compactas; formulário mantém os rótulos e a navegação pelo teclado.
- Marca no cabeçalho de todas as telas e no favicon/manifesto web. Ícone Android preparado com a arte original em recurso adaptativo; não houve compilação de APK nesta entrega.
- Nome e descrição do app corrigidos: removidas referências antigas a demonstração e dados temporários.
- Contexto da empresa acomoda nomes longos com rolagem limitada; histórico usa cartões de altura variável, datas brasileiras e detalhes com fechamento acessível.
- Grade conserva sequência, toques e tempo; cabeçalho flexível, números ampliáveis e indicação de foco no teclado.
- Cache estático atualizado para53, API e protocolo permanecem51/sequencia-v1. Nenhuma migração ou alteração de dados do servidor.

## Verificação

Análise Flutter sem problemas. Trinta testes aprovados, incluindo dez cenários de layout (320×568,390×844,768×1024,1440×900 e844×390, fonte normal/dobrada), teclado aberto, nomes extensos, grade, histórico e janela de detalhes. Dados de teste exclusivamente em memória.

Navegador: capturas conferidas nas cinco dimensões após carregar as imagens. Teste ponta a ponta local confirmou avaliação de36 alvos, armazenamento cifrado, recibo perdido/reenvio sem duplicação e mesma avaliação no painel após recarregar. Todas as chamadas externas foram interceptadas; nenhum registro fictício em produção.

Empacotamento: `node tools/preparar-triagem-web.cjs`. Cache: `node tests/attention51-cache.cjs` (198 recursos existentes e sem duplicação, abertura offline na rota correta e POSTs fora do cache). Regressão visual: `tests/brand52-ui.cjs`; fluxo completo: `tests/attention51-e2e.cjs`.

Publicação na rota existente: https://engseg-pr.github.io/ppl-equipamentos/triagem/. Conferir HTTPS, hash do JavaScript e tela real depois de enviar. Cache53 não altera as filas e o repositório protegido de avaliações. Homologação de APK, Safari e aparelhos reais continua pendente.

## Correção de inicialização

A conferência com cache existente revelou que o bootstrap padrão do Flutter tentava registrar um segundo service worker obsoleto, cujo encerramento recarregava a página. O bootstrap explícito usa somente o service worker da plataforma. O cache53 distribui esta correção e preserva as avaliações, as sessões e os PDFs locais.
`tests/brand53-offline.cjs` passou com service worker real: atualização52→53, apenas um worker da plataforma, sem recarregamento repetido, abertura offline e armazenamento local de teste preservado.
