# Modelos PPL e organização visual — versão 42

## Ativação no Supabase
O site e os arquivos estão preparados. A ativação central exige estas duas operações, realizadas no projeto hqyyrylamokgxbkwzbix:

1. No SQL Editor, executar o conteúdo completo de `cadastrar-inspecao.sql`. Acrescenta a descrição de cargo aos colaboradores e cadastra o modelo de inspeção SSMA exclusivamente na PPL. É uma migração incremental e pode ser executada novamente. Não exclui registros, logins, alertas ou checklists.
2. Na Edge Function existente **ppl-api-**, substituir o código pelo conteúdo completo de `ppl-api-dashboard.ts` desta pasta e publicar. Não criar outra função e não alterar as configurações de autenticação existentes.

A versão 41 de Documentos e arquivo deve estar instalada, como na etapa anterior. O painel bloqueia os novos formulários PPL enquanto a função retornar versão anterior a 42, para evitar salvar campos incompletos.

## O que foi preparado
- Inspeção SSMA PPL: descrição, condições observadas, prioridade, RAC, ações, responsáveis, prazo, assinatura, foto do colaborador e evidências. PDF próprio com identidade da empresa, sem a marca Vale e sem número do procedimento usado como referência.
- Lista de presença: modelo FMG-GP-01-05R12, participantes do cadastro, seleção individual e de todos, nome, matrícula e função. Seleção de participantes não constitui assinatura de presença; os espaços de assinatura são preservados.
- PTS: modelo FMO-SSMA-13-01R02, campos agrupados conforme suas seções, colaboradores cadastrados e assinatura desenhada nos campos disponibilizados.
- Quinze modelos de certificado e uma ordem de serviço extraídos do arquivo entregue. Nome, função e matrícula vinculados ao colaborador. Na OS, descrição do cargo vem do cadastro e pode ser revisada no formulário. CPF, quando necessário no certificado, deve ser informado no campo próprio.
- Os nomes e os registros profissionais de responsáveis impressos no arquivo original foram retirados do fundo. A emissão deve informar os responsáveis reais; a assinatura do participante não substitui as assinaturas dos instrutores/responsáveis nos espaços originais.
- PDFs ficam anexados ao registro central com o fluxo privado de Documentos e arquivo. Se a geração falhar após o cadastro, o documento pode ser recuperado em Ver / gerar PDF sem criar outro registro.
- Formulários preservam o desenho original. Conteúdo maior que os campos segue integralmente em complemento numerado, sem corte silencioso.
- Modelos Vale existentes permanecem disponíveis conforme as regras anteriores; modelos internos PPL continuam exclusivos da PPL.

## Limites desta entrega
A inspeção utiliza o fluxo offline existente do executante. PTS, certificados, OS e emissão de listas no painel de gestão exigem conexão para salvar no arquivo central. Não foi introduzido um modo offline para todo o painel de gestão.

Os modelos reproduzem conteúdo fornecido; sua emissão exige revisão técnica de cargas horárias, programas, qualificações, responsáveis e condições reais. Nenhum preenchimento gera liberação automática de atividade. Assinaturas desenhadas não são certificados digitais.

## Verificação realizada
Geração de 19 PDFs com dados fictícios e revisão de suas páginas principais; validação do preenchimento automático; formulários PTS/certificado/OS em tela de 390 px sem rolagem horizontal; portais em 390 e 1440 px; navegação móvel; testes de isolamento/autorização e preservação de formulário; migração SQL executada duas vezes em PostgreSQL local de teste; sintaxe e existência de recursos do cache offline.

A homologação real no iPhone/Safari, a sincronização entre dois aparelhos e a gravação central dos novos modelos devem ser feitas após ativar os dois arquivos. Os testes desta entrega não inseriram inspeções reais no banco de produção.
