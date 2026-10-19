# Documentos e treinamentos v45

- Frequência PPL: estrutura FMG-GP-01-05 Rev.12, campos medidos, texto com quebra/ajuste, cabeçalho repetido e paginação quando necessário. Datas exibidas dd/mm/aaaa; unidade e tipo por seleção. Procedimento/código/revisão/data são opcionais.
- Catálogo: 28 treinamentos extraídos dos modelos; 15 com carga horária identificada no certificado correspondente. Os demais exigem carga manual. Conteúdo vem da presença, ou do certificado quando a presença estava vazia; instruções de revisão não compõem o programa. Nenhuma carga normativa foi presumida. Revisão técnica pertence ao responsável.
- Outros: título, programa e carga manuais. Seleção do participante não equivale a assinatura; clicar no nome permite que o próprio participante desenhe. Assinatura de instrutor opcional. Documento planejado não equivale a evidência de realização.
- Certificados: 15 novas versões com texto organizado, CPF dinâmico, um espaço opcional de instrutor/responsável e nome do participante centralizado abaixo da linha. Campos podem permanecer sem assinatura para coleta em papel. Versões antigas continuam disponíveis para registros históricos; PDFs originais não são substituídos. A geração corrigida usa sufixo layout45.
- Matriz: registrar treinamento realizado manualmente, selecionar participantes e anexar evidência. Não produz lista de presença fictícia para um evento externo. Gravação do cadastro e upload são etapas distintas; se upload falhar, cadastro permanece e a tela informa a falta do anexo para nova tentativa.
- Dossiê: associa matrícula/cadastro pelo ID, nunca somente pelo nome. Reúne frequência, certificados, OS e documentos ligados explicitamente ao colaborador dentro do acesso autorizado. ZIP contém índice, manifesto e anexos originais com verificação SHA-256. Limite 32 MB; não constitui backup integral nem comprova evidências nunca anexadas.

## Verificação

Node 24+: `node tests/management-server.cjs`.
Com Playwright e navegador instalados: `node tests/training-pdf.cjs`, depois `node tests/training-workflow.cjs`. Variáveis opcionais: PRS_PLAYWRIGHT_MODULE, PRS_CHROME_PATH e PRS_QA_OUTPUT. Saídas fictícias vão à pasta temporária, nunca ao banco de produção.

Foram exercitados 35 PDFs, 35 participantes com paginação, nomes/cargos longos, assinaturas, emissão física sem assinatura, evidência externa, ZIP e pessoas com nomes iguais/IDs diferentes, telas de 390 e 1440 px, isolamento/autorização e ciclo do checklist online/offline. A homologação em Safari físico continua necessária.
