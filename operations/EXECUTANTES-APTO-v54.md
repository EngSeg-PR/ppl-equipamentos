# Executantes e Sistema Apto — versão 54

Base: commit `cd7ccbe`, que já contém o app de atenção, sua identidade visual53 e a API51. As fontes Flutter e os critérios de resultado existentes foram preservados.

## Comportamento

- Executante escolhe o próprio nome cadastrado e informa sua matrícula. O servidor valida a empresa e o cadastro ativo; a identidade preenche a autoria dos novos checklists e inspeções. Gestores e proprietário mantêm suas contas existentes.
- Sessão de campo com12h. Primeiro acesso exige conexão; uma sessão já autorizada permite preenchimento offline durante sua validade. Expiração ou revogação bloqueia novas alterações, preservando rascunhos, registros e PDFs para consulta e recuperação.
- Token somente no cabeçalho da requisição. Não integra o conteúdo, hash ou PDF da inspeção. A matrícula é um controle básico, pois também aparece no cadastro e nos documentos; esta entrega não constitui autenticação forte ou prova de identidade.
- Responsáveis técnicos adicionais dos modelos Vale são independentes da autoria. O snapshot anterior permanece selecionado e não é apagado por ausência no diretório. Outros nomes podem ser escolhidos no diretório reduzido; a matrícula do responsável adicional é informada manualmente e validada pelo servidor no envio. A matrícula do próprio executante é automática.
- O contexto público deixa de retornar matrículas e descrições. A gestão busca o contexto autorizado após entrar e não o grava no cache público. Uma negativa401/403 não se transforma em autorização offline. O executante ainda pode consultar os registros locais preservados.
- A gestão possui a aba **Sistema Apto**, com filtros por empresa, colaborador, matrícula exata, datas, conclusão e acompanhamento. Indicadores e gráficos usam todos os registros filtrados, independentemente da página exibida.
- Acompanhamento aberto/em andamento/concluído possui histórico separado e controle de revisão concorrente. As avaliações originais continuam imutáveis. Conclusão e acompanhamento não definem aptidão médica ou autorização para conduzir.
- O app Apto continua sendo preparado pela conta da gestão, conforme a versão51. Não foi transformado em um aplicativo de login por matrícula nem recebeu critérios clínicos novos.

## Ativação e transição

Aplicar `supabase/executantes-v54/ATIVAR-v54.sql`, atualização incremental e atômica dos dois módulos, sobre o banco existente com migração51. Atualizar a função **ppl-api-** com todo o conteúdo de `supabase/executantes-v54/ppl-api-dashboard.ts`; publicar os arquivos da interface54. Não executar o schema independente do anexo do app.

O proprietário ativa a obrigatoriedade por empresa em **Empresas cadastradas → Ativar login dos colaboradores**. O padrão inicial da migração éfalse: permite atualizar o servidor/interface antes de exigir a nova credencial nos envios antigos. Após ativação, pendências antigas precisam do acesso do próprio autor e preservam o snapshot/PDF original. Registros de outros autores não são reatribuídos.

Não limpar o armazenamento dos aparelhos. Uma alteração de endereço de hospedagem não transfere automaticamente suas filas offline.

## Verificação

Testes locais com dados sintéticos e banco PostgreSQL descartável:

- `tests/executor54-server.cjs`:82 verificações, migração final repetida, login/contexto, autorização por empresa/autor, token/expiração/revogação, limites de tentativas, legados48, idempotência, CORS/RLS e compatibilidade com a API51.
- `tests/apto54-server.cjs`:106 verificações, filtros, totais além dos50 primeiros registros, isolamento, concorrência e histórico preservado.
- `tests/apto54-ui.cjs`:21 verificações, gráficos, paginação, filtros, gravação e conflito de acompanhamento, navegação e telas1440/390/320.
- `tests/executor54-ui.cjs`: login válido/inválido, autoria fixa, prévia sem rascunho, finalização/retorno, PDF real baixado offline, correções, expiração, revogação e consulta local após403.
- `tests/executor54-auxiliary.cjs`: preservação dos responsáveis adicionais Vale e troca explícita sem reutilizar matrícula anterior.
- `tests/executor54-client.cjs`: token somente em cabeçalho, contexto privado em memória e negativa sem fallback de autorização.
- `tests/release54-offline.cjs`: atualização53→54 com worker real, um único worker, sem ciclo de recarga, app Apto offline e armazenamento preservado.

Política e termo atualizados factualmente para1.1, em27/10/2026, sem novos aceites obrigatórios. PDFs renderizados e inspecionados: política6p e termo1p.

Resultados locais não substituem a homologação em iPhone/Safari, Android e dois aparelhos reais. Limites: matrícula conhecida, cópias locais acessíveis no mesmo navegador, revogação remota só conhecida quando conectado, cota120 tentativas por empresa/15min incluindo acessos corretos. Uma empresa com efetivo grande exige revisão dessa cota antes de expansão. O backup de código desta entrega não contém banco/Auth/Storage nem pendências de outros aparelhos.

O estado de ativação real e os hashes da cópia final são registrados fora do código, na pasta privada `work/PRS-REIS-ATUALIZACAO-v54-2026-10-27`. A existência deste arquivo não comprova publicação.
