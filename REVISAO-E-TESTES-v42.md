# Revisão crítica e roteiro de homologação — v42

## Avaliação
A arquitetura já separa proprietário, gestores e executantes, possui identificação por empresa, armazenamento central privado, revisão de registros, anexos, histórico e fluxo offline para inspeções. Isso constitui uma base útil para a próxima fase de testes. Ainda não representa homologação para comercialização.

Na interface, a quantidade de abas misturava tarefas de campo, gestão de pessoas e controle documental. A distribuição anterior dava peso semelhante a todos os botões e ocupava muita altura no celular. Formulários extensos também podiam alargar a tela.

## Correções desta etapa
- Gestão organizada em três grupos: acompanhamento; pessoas e treinamentos; operação e conformidade.
- Menu lateral no computador e seleção de área no celular, mantendo as mesmas funções e permissões.
- Proprietário com navegação lateral e contexto da empresa separado do cadastro.
- Cabeçalho mais compacto; hierarquia consistente de títulos, textos, cartões e ações.
- Campos com largura limitada, colunas flexíveis, indicação de foco e áreas de toque adequadas.
- PTS com seções e grupos de campos; ajuste do transbordamento em telas pequenas.
- Cadastro preservado antes da geração do PDF, permitindo repetir a geração do documento salvo.
- Textos extensos preservados em complemento numerado do PDF.

A referência utilizada foi o U.S. Web Design System, especialmente organização de cartões e formulários: https://designsystem.digital.gov/components/card/ e https://designsystem.digital.gov/components/form/. Foi aplicado ao visual existente, preservando a identidade PRS. REIS e as identidades das empresas.

## Pontos que exigem validação antes de vender acessos
1. Sincronização e recuperação: realizar a inspeção em aparelho A offline; reconectar; conferir no gestor em aparelho B; verificar ID e revisão únicos e o PDF completo. Testar interrupção durante o envio e nova tentativa.
2. Persistência no celular: testar Safari normal e instalado na tela inicial. Navegação privada pode perder armazenamento e não deve ser a única cópia de evidências. Validar exportação para Arquivos pelo fluxo permitido pelo iOS.
3. Segurança: testar gestor de empresa A tentando consultar IDs da empresa B, revogar usuário ativo e confirmar perda de acesso. Os controles devem permanecer no servidor; ocultar menus não é proteção suficiente.
4. Documentos: revisar campos e assinaturas de cada modelo com o responsável técnico. Certificado não comprova por si só que houve treinamento; confirmar realização, presença, conteúdo e responsáveis antes da emissão. Conferir o fechamento da PTS sem presumir liberação.
5. Recuperação de desastre: o pacote de código não é backup do banco e do armazenamento privado. Fazer exportação administrativa protegida do banco e dos arquivos e ensaiar restauração antes da comercialização.
6. Operação: definir retenção, capacidade de armazenamento, limites de arquivos, atendimento e monitoramento de erros. Mensagens claras na interface não substituem monitoramento do serviço.
7. Acessibilidade e qualidade: revisar uso por teclado, leitores de tela, contraste, tamanhos de fonte, nomes extensos e bases maiores. Os testes responsivos desta etapa não equivalem a certificação de acessibilidade.

## Sequência de testes sugerida
- Ativar SQL e função v42.
- Cadastrar/editar descrição de cargo de um colaborador fictício.
- Fazer inspeção PPL online e offline; conferir foto, assinatura, evidências, pendência, sincronização e PDF no gestor.
- Fazer lista com 1 participante e outra com mais de 21, verificando continuação e assinaturas em branco.
- Gerar cada certificado, revisar campos e responsáveis; gerar OS e conferir descrição do cargo.
- Preencher PTS, revisar marcações, assinaturas, campos de início/encerramento e PDF.
- Repetir geração do mesmo cadastro e conferir ausência de duplicação.
- Conferir modelos Vale e PPL anteriores, permissões e arquivo documental.

## Preservação
Código e ativação estão versionados. O pacote de preservação local contém a fotografia desta entrega. As planilhas originais preenchidas e arquivos particulares usados na preparação não foram publicados no repositório. Nenhum dado central foi excluído nesta etapa.
