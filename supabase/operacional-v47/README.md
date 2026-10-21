# Operacional v47

Executar `ATIVAR-v47.sql` completo no projeto existente, depois substituir todo `index.ts` da função **ppl-api-** pelo conteúdo de `ppl-api-dashboard.ts`. Preservar segredos e autenticação. Confirmar o cabeçalho `X-PPL-API-Version: 47`, inspeção própria PPL v3 ativa e arquivo privado `prs-pgr`.

Migração aditiva: CPF de colaborador, perfil completo da empresa, gerência/engenheiro, versões e arquivos do PGR, inspeção v3. Não exclui registros, usuários, alertas ou PDFs. O cadastro da empresa é transacional. As tabelas PGR são privadas e acessíveis somente pela função após validação de proprietário. Versões são acrescentadas com controle de concorrência; não existe rota para sobrescrever versões antigas.

CPF fica fora do contexto público. Certificados consultam o cadastro com sessão válida e escopo autorizado. A emissão usa CPF do cadastro quando informado, sem aceitar substituição pelo cliente. Nome, matrícula e função também são conferidos no servidor.

Os padrões operacionais da empresa não fazem parte da identidade imutável registrada na inspeção; o aplicativo copia somente os campos originais da marca. Essa separação preserva o reconhecimento de registros e pendências anteriores.

Na inspeção v3, unidade não é exibida. O proprietário pode definir o encaminhamento interno no cadastro. Sem unidade interna, o acesso fica com proprietário e gestores autorizados para a empresa inteira; a atualização não amplia o alcance de gestores restritos a unidade/equipe.

O PGR é um espaço de preparação técnica com onze seções, histórico e anexos originais. Não emite documento final no formato original sem o modelo-base e seu mapeamento. Referências do monitoramento em `operations/MONITORAMENTO-PSICOSSOCIAL.md`.
