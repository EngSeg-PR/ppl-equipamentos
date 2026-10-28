# Versão 57 — visual-v1 e classificação experimental

Incremental sobre acesso55/executantes54. Não substitui tabelas nem dados anteriores.

1. Aplicar `CLASSIFICACAO-v57.sql` e `ATIVAR-v57.sql`, nessa ordem; ambos idempotentes.
2. Conferir função privada e privilégios: anon/authenticated sem execução; service_role executa somente os pontos de entrada autorizados. Tabela de configurações privada, sem política pública.
3. Comparar a fonte remota com a v55 antes de atualizar a função existente **ppl-api-** usando o arquivo completo `ppl-api-dashboard.ts`. Não publicar por cima de mudanças remotas inesperadas.
4. Compilar/empacotar app e publicar cache57. Conferir header API57, hash do JavaScript público, UI, login existente e acesso sem autenticação negado. Não gerar avaliações fictícias em produção.

Especificação, fórmula e limites: `operations/TESTE-CLASSIFICACAO-v57.md`. A condição experimental e os estados sem base são parte do comportamento. Configuração somente pelo administrador existente; não inclui novos cadastros, questionários de saúde ou sensores.

Testes locais: `visual57-server.cjs`, `classification57-server.cjs`, `visual57-management-ui.cjs`, `visual57-e2e.cjs` e regressões existentes com `PRS_VISUAL57=1`. Flutter e núcleo Dart têm testes de tempo, métricas, interrupção, persistência e layout. Banco dos testes é descartável e não acessa produção.
