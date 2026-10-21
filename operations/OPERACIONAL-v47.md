# Entrega operacional v47

- Cadastro de funcionário com CPF opcional e edição de CPF/descrição. Consulta autenticada e preenchimento automático no certificado, com proteção contra troca rápida de seleção e sem CPF na lista pública.
- Perfil da empresa com os campos das imagens: identificação, endereços, contatos, responsáveis, contratante, escopo, cenário de riscos e vigência. Sem transcrever dados históricos ou pessoais das imagens para código público. Padrões de gerência/gestor/engenheiro preenchem novas inspeções e permanecem editáveis. O cadastro alimenta as seções iniciais do PGR; alterações manuais não são sobrescritas silenciosamente.
- Proprietário: Elaborar PGR substitui Indicadores e registros. Onze seções, versões imutáveis, consulta de versões anteriores, arquivo-base PDF/DOCX e evidências privadas. O rascunho JSON não equivale a PGR final. Monitoramento agregado com método, referências profissionais, participação dos trabalhadores, achados e ações. Não coleta diagnóstico individual nem aplica teste psicológico próprio.
- Mensagens separadas em Abertas, Em andamento e Concluídas. O estado anterior Em atendimento é preservado no banco e apresentado como Em andamento.
- Inspeção PPL v3 sem os oito campos adicionais retirados e sem unidade visível. Unidade interna opcional mantém a fronteira de acesso existente. Equipes padronizadas em oito opções nos formulários aplicáveis.
- OS v2/layout47 com texto medido e páginas de continuação. Conteúdo original preservado, incluindo descrições extensas. Versão anterior continua reconhecida.
- Requisitos legais: cartões, gráfico de execução e calendário; verde realizado, vermelho pendente/vencido, amarelo para documentos com vencimento entre hoje e 30 dias. Sem validade não recebe situação inventada. Indicadores respeitam os filtros.
- Tipografia, hierarquia, espaçamento, contraste e tamanhos revisados no proprietário/gestão e controles do executante. Textos narrativos justificados; rótulos e números mantêm alinhamento próprio.

## Verificação

Testes locais com dados fictícios: `tests/platform47-server.cjs`, `tests/platform47-sql.cjs`, `tests/pgr-workflow.cjs`, `tests/owner47.cjs`, `tests/inspection47.cjs`, `tests/service-order-pdf.cjs`, regressões de PDFs e ciclo de checklist online/offline. Não criar emissões fictícias em produção para validar a entrega.

Variáveis dos testes de navegador: PRS_PLAYWRIGHT_MODULE, PRS_CHROME_PATH e PRS_QA_OUTPUT. SQL local opcional via PRS_PGLITE_MODULE. Conferir permissões, versão pública, Safari real e dados da empresa na homologação de campo.
