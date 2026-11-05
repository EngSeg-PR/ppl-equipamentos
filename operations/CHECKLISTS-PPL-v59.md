# Checklists internos PPL e revisões — v59

Entrega de 05/11/2026, baseada na OS58 (a745631). O arquivo Vale Anexo02 enviado primeiro foi cancelado pelo proprietário; não foi usado nesta implementação.

## Modelo e operação

Fonte correta: `REV. CHECK LIST DIÁRIO DE MÁQUINAS E EQUIPAMENTOS PPL - FMO-SMS-01-05R03 - DADOS (00000002) (1) (2) (1).xls`, SHA-256 `0a684b258200a295543c111b1a937ce8c2ca14a7a3a2f8978f4631bd20c317ca`. A revisão efetiva das células é 05. O arquivo possui 45 folhas técnicas, 496 perguntas e o verso. As duas folhas de ferramentas manuais com nomes que diferem por espaço são distintas; números repetidos da máquina de jato são preservados.

Os 46 modelos internos passam à estrutura diária PPL e à revisão 05, conservando todas as 505 perguntas e regras atuais. O modelo adicional de cinturão/talabarte conserva suas nove perguntas e sua origem própria, sem atribuir falsa origem à planilha. Modelos Vale, inspeção SSMA, OS58 e Sistema Apto57 permanecem intactos.

O formulário usa marca PPL, tabela de itens, código de ação, dias 1–31 e legenda C/NC/N/A. No celular, a apresentação inicial destaca o dia escolhido, com opção de abrir o mês completo. Cada PDF representa uma inspeção; datas vazias não são ausência de cumprimento nem consolidação mensal. Unidade/equipe, identidade automática, justificativa N/A, foto e assinatura do responsável continuam funcionando.

Fotos gerais do equipamento: opcionais, até 12, capturadas pela câmera. Fotos por item mantêm limite de três. PDF contém anexos de identificação, observações e fotografias, até quatro fotos por página. Texto longo recebe continuação integral. O fluxo grava localmente antes de preparar PDF/envio; conclusão volta à seleção de novo checklist.

## Revisão pelo proprietário

Proprietário → Checklists → Revisões dos checklists PPL. Selecionar Excel XLS/XLSX até 14 MB, conferir a prévia, informar a revisão e acionar Publicar nova revisão PPL. A importação mantém os nomes exatos das folhas e recusa folhas técnicas desconhecidas ou lote inválido. Não interpreta macros.

Todos os modelos internos recebem a revisão atual no mesmo lote; folhas omitidas conservam as perguntas anteriores. Modelos excluídos pelo proprietário continuam ocultos. Somente a revisão atual aparece nos novos preenchimentos; versões obsoletas ficam fora da seleção. Snapshots, PDFs e pendências anteriores são preservados para evidência e recuperação. Não há exclusão de inspeções nesta entrega.

A publicação exige proprietário, empresa PPL, revisão e versões esperadas; concorrência produz conflito em vez de sobrescrever. O Excel original fica privado com hash. Falha da gravação do lote desfaz todas as ativações; eventual arquivo já enviado continua privado e pode ser reutilizado na tentativa seguinte.

## Validação executada

- API completa59: 273 verificações isoladas, incluindo histórico, assinatura/foto, 12 fotos gerais, códigos de ação, autorização, hash, retentativa e revisão ativa única.
- PostgreSQL local: 35 verificações; migração duas vezes, grants restritos, concorrência, exclusão concorrente, rollback do lote e evidência histórica preservada.
- Parser: 23 verificações com o Excel real (45/496).
- Proprietário: 20 verificações em Chrome local, 1440/390 px, incluindo erro/retry e bloqueio em servidor antigo.
- Executante: 24 verificações, identidade, cancelamento de câmera sem rascunho, listas, notas, data, foto geral, finalização, PDF offline e recarregamento.
- Renderer: todos os 46 modelos/505 perguntas, dias 1/31, data inválida, fotos JPEG, metadados extensos; PDFs/PNGs inspecionados visualmente.
- Cache: 206 recursos existentes, sem duplicação; atualização58→59 abre Apto offline, preserva armazenamento e mantém único service worker.

Os dados destes testes são fictícios e locais. O ensaio no iPhone/Safari real permanece homologação do proprietário. Fotografias de código não incluem banco, Auth, Storage ou pendências de outros aparelhos.

## Ativação

1. Executar uma vez o arquivo integral `supabase/checklists-v59/ATIVAR-v59.sql` no projeto existente. Não reaplicar migrações antigas.
2. Atualizar a função existente `ppl-api-` com o arquivo integral `supabase/checklists-v59/ppl-api-dashboard.ts`.
3. Publicar a interface/cache59 e verificar HTTPS, cabeçalho59, autorização e catálogo atual.

O estado efetivo da publicação é registrado ao final da ativação; um commit não comprova implantação.
