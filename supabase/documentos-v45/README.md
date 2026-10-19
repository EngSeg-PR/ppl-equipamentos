# Documentos e treinamentos — versão 45

Função completa de substituição de `ppl-api-`, compatível com o banco v42. Não exige SQL novo. Implantada em 19/10/2026; endpoint confirmou `X-PPL-API-Version: 45`.

Para reaplicar: abrir a função existente no Supabase, aba Code, substituir todo `index.ts` pelo conteúdo de `ppl-api-dashboard.ts` e publicar. Preservar configurações de autenticação e segredos existentes. Nunca criar uma função com nome diferente nem publicar chave administrativa.

Valida catálogo/carga/conteúdo no servidor, colaboradores da empresa, assinaturas vinculadas aos participantes e versão dos certificados. Mantém autorização, isolamento, histórico e anexos privados. A interface exige versão 45 para gravar os novos campos.

Catálogos contêm apenas modelos e conteúdo técnico; planilhas privadas e dados antigos de participantes não fazem parte desta atualização.
