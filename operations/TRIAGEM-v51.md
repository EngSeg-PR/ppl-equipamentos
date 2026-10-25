# Avaliações de atenção — v51 — 25/10/2026

Paulo Ricardo autorizou ativar o histórico no aplicativo e na plataforma existente, sem avaliações ou colaboradores fictícios fora dos testes.

## Implementação

Novo app Flutter0.2.0 com preparação pelo supervisor, seleção do colaborador cadastrado, treino descartado, grade de36 números, tempo monotônico, métricas e histórico local protegido. O registro é confirmado localmente antes do resultado; checkpoints permitem recuperar interrupções. Falhas de gravação não liberam descarte. Envio usa UUID estável, confirmação explícita e retentativa sem duplicação. Falhas permanentes preservam o registro para revisão.

API completa baseada na48, com ações autenticadas e migração incremental em `supabase/triagem-v51`. O servidor revalida os eventos, calcula métricas, verifica empresa/escopo e preserva snapshots e resultados imutáveis. Gestão e proprietário têm consulta com filtros e detalhes; o dossiê oferece atalho.

As fontes canônicas estão em `attention-app/app` e `attention-app/packages/core`, versionadas junto da plataforma. O app web é empacotado por `tools/preparar-triagem-web.cjs`. A rota pública é `triagem/`. O cache51 prepara os recursos estáticos do app e preserva o armazenamento de inspeções e avaliações. POSTs e dados privados não entram no cache estático.

## Verificações

- Flutter: análise limpa,19 testes aprovados e compilação web JavaScript concluída.
- Banco/API:42 verificações em PostgreSQL17 portátil descartável, migração duas vezes, Auth simulado.
- Tela: lista/filtros/detalhes/toques e respostas atrasadas;1440/390px.
- Ponta a ponta: app compilado36 alvos, registro cifrado, perda simulada do recibo, duas tentativas e somente um UUID central; restauração após recarregar e mesma avaliação no painel.
- Cache:195 referências existentes, sem duplicação; abertura offline do app na rota correta e POSTs fora do cache.

Todos os dados sintéticos ficaram em testes locais. Nada foi inserido como avaliação fictícia em produção.

## Ativação

Migração confirmada no SQL Editor do projeto existente. Leitura de produção:0 avaliações, RLStrue e função pronta. Fonte remota anterior da função conferida contra a base48 antes da substituição; cópia privada preservada em `work/`. A nova função respondeu HTTP401 sem login com cabeçalho de versão51.

A interface foi publicada e conferida por HTTPS: app, scripts, cache51 e menus retornaram200, e o SHA256 de `triagem/main.dart.js` coincidiu com o build verificado. A tela de entrada real foi aberta sem inserir dados. O primeiro acesso com cache50 exigiu recarregar uma vez para assumir a nova rota. Esta entrega preserva código e não constitui novo backup completo de banco/Auth/Storage.

## Limites

Nenhum resultado define aptidão para condução. Homologação de uma avaliação real, Android/APK, dois aparelhos e Safari permanece necessária. A segurança/persistência do navegador não equivale ao Keystore Android; limpar seus dados pode remover a cópia local ainda pendente.
