# PR REIS — plataforma por empresa, etapa 31

Estado: implementada e testada localmente; ainda não ativada no Supabase nem publicada no endereço principal.

## Entregue nesta etapa

- Portal PR REIS → seleção de empresa → Executante ou Gestão.
- Proprietário com login exclusivo (papel owner validado no servidor).
- Cadastro de empresas/logo, funcionários/matrícula/função, modelos de checklist/inspeção e acessos de gestão por empresa/unidade/equipe.
- Painel global do proprietário e painel da empresa com filtros de mês, datas, tipo, resultado e busca; PDF e acompanhamento.
- Caixa de mensagens/solicitações/reclamações/ajustes e contador de novas mensagens.
- Executante sem conta, escolha do funcionário e preenchimento automático da função. Inspeções dependem de modelo técnico cadastrado.
- Registro congela empresa/logo/funcionário; PDF funciona sem rede. Pendentes e envio automático preservados.
- 46 modelos atuais da PPL preservados, com o catálogo e modelos pendentes existentes.

## Ativação central (na conta do proprietário)

1. No SQL Editor do projeto hqyyrylamokgxbkwzbix, executar o conteúdo de supabase/migration.sql. A operação é uma transação; se houver erro, não continuar e comunicar o texto do erro.
2. A migração arquiva somente registros PPL recebidos até 2026-10-08T17:59:24Z, confirmados pelo proprietário como testes. Não apaga logins, alertas, modelos nem PDFs. Cópias locais em outros aparelhos não são apagadas remotamente.
3. Atualizar o código da Edge Function existente ppl-api- (com hífen final), usando supabase/ppl-api-dashboard.ts. Manter as variáveis existentes, a chave secreta somente no servidor e a configuração de verificação JWT da função existente. As ações privadas validam JWT e papel explicitamente.
4. Após confirmação das duas etapas, verificar o servidor real: coleta pública; consulta negada sem login; proprietário; gestor por empresa/unidade/equipe; PDF e isolamento entre empresas. Só então publicar o site da pasta site em main.
5. Entrar em owner.html com o login proprietário existente e cadastrar os funcionários PPL com nome, matrícula e função. O formulário exige funcionário cadastrado para os novos registros.
6. Para outra empresa: cadastrar nome/logo, funcionários e modelos, conceder acessos e liberar serviços.

Não enviar senhas, service_role, chave secret ou tokens nesta conversa. A chave pública atual permite usar o aplicativo, mas não executar migrações nem atualizar a função.

## Verificação realizada

- JavaScript e bundle TypeScript passaram na verificação de sintaxe.
- API simulada: coleta sem conta, JWT/suspensão, operações exclusivas do proprietário, filtros por empresa via cliente RLS, arquivamento, identidade/funcionário do registro, envio do registro antes do PDF, repetição, conflitos e quota.
- PDF real: gerado sem nenhuma requisição de rede, com assinatura/foto e marca por empresa; registro antigo também funciona.
- Navegador Chromium isolado em dimensão de celular: fluxo de empresa, formulário, função automática, navegação de inspeções, abas do dono, cadastro simulado de funcionário e modelo com vários itens, gestor bloqueado na página do proprietário. Nenhum usuário ou registro real foi criado.
- Dependências das páginas e cache offline verificados.
- Falta homologação real Supabase (incluindo RLS) e validação física no iPhone/Safari. Testes locais não comprovam essas etapas.

## Decisões preservadas

Executante não possui conta. Gestor entra somente se autorizado. Paulo é proprietário e responsável técnico. Ausência de registro não indica falha. Não existem inspeções diárias obrigatórias por efetivo/equipamento. Respostas C/NC/NA, assinatura desenhada e foto obrigatórias. PDF não libera equipamento automaticamente. Alertas e avisos integram o sistema; exclusão de testes não os apaga. Modelo técnico da aba Inspeções ainda será fornecido/aprovado pelo responsável.
