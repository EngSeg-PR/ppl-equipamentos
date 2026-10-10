# Preservação e arquivo — v41

Esta atualização depende dos módulos de gestão v38 já instalados. Não exclui inspeções, usuários, modelos ou alertas.

## Ativação

1. Faça uma cópia de segurança administrativa do banco e dos arquivos do Storage. O backup do banco sozinho não contém os arquivos anexados.
2. No SQL Editor do projeto existente, execute todo o arquivo `migration.sql`, incluindo BEGIN e COMMIT. Em caso de erro, pare e preserve a mensagem; não execute trechos isolados.
3. Na Edge Function existente `ppl-api-`, substitua o código inteiro pelo conteúdo de `ppl-api-dashboard.ts` e publique. Mantenha as configurações e variáveis existentes.
4. Reabra o aplicativo conectado. No painel de gestão, abra **Documentos e arquivo**. Sem a atualização do servidor, essa área informa que precisa de ativação.
5. Teste com um documento fictício: cadastrar, anexar, baixar, consultar histórico, exportar dossiê, arquivar como proprietário e reativar. Confirme também que um gestor de outra empresa não consegue consultá-lo.

## Entrega

- Documentos por empresa: código, revisão, categoria, responsável, data e validade opcional; arquivos anexos privados.
- Histórico a partir da ativação: cadastro, alterações, anexação, arquivamento e reativação. Dados anteriores recebem uma identificação de estado inicial, sem inventar um histórico.
- Arquivar e reativar são ações do proprietário e exigem motivo; não há exclusão definitiva nessa área.
- Novos anexos recebem SHA-256 verificado na recuperação. Anexos antigos continuam disponíveis, sem alegar uma verificação retroativa.
- Dossiê JSON portátil com metadados, histórico e bytes dos anexos (limite de 32 MB por exportação). Ainda não há importação automática de dossiês.

## Limites

As proteções cobrem os cadastros e anexos dos módulos de gestão. Um administrador do banco ainda pode alterar políticas ou remover dados diretamente. Arquivamento, hash e assinatura desenhada não equivalem a armazenamento inviolável, assinatura certificada ou garantia de aceitação em auditorias.

A atualização do frontend, sozinha, não ativa o banco. Documentos são enviados com conexão; inspeções e PDFs locais mantêm o fluxo offline existente. O backup local ampliado contém os PDFs já disponíveis no aparelho e informa quais estão ausentes.
