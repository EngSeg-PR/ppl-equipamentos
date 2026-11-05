# Ativação PPL59

Executar `ATIVAR-v59.sql` e atualizar a função existente **ppl-api-** usando todo o conteúdo de `ppl-api-dashboard.ts`. A fonte completa deriva da API58 e preserva OS58, Sistema Apto57, acessos e modelos Vale. Não copiar somente o fragmento.

`build-source.cjs` recompõe a fonte a partir de OS58, catálogo `ppl-checklist-models-v59.json` e `revision.fragment.ts`. Manter os três consistentes. Nenhuma variável secreta nova é necessária.

A tabela de revisões e suas funções são privadas, acessíveis somente pelo serviço existente. A API exige proprietário/PPL para publicar e preserva as autorizações de leitura. Há controle de versão, lote transacional e serialização da exclusão de modelo com publicação concorrente. A exclusão retira da seleção e mantém evidências anteriores.

Validação: `tests/ppl59-server.cjs` (273 verificações isoladas), `tests/ppl59-sql.cjs` (35 no PostgreSQL temporário local, sem produção). Histórico e cenários de falha foram preservados nos testes. Ver os detalhes em `operations/CHECKLISTS-PPL-v59.md`.
