# Preservação e migração PRS. REIS

## Caminho recomendado

Na primeira migração, mude apenas a hospedagem do site e mantenha o mesmo projeto Supabase. Assim os registros centrais, arquivos e usuários permanecem no mesmo serviço. Configure o novo domínio nos redirecionamentos de autenticação e confira os caminhos relativos, o escopo do service worker e o HTTPS antes da troca.

Dados offline pertencem ao endereço e navegador usados. Antes de abandonar o endereço antigo, abra cada aparelho, envie as pendências ou exporte **Backup com inspeções e PDFs** para cada empresa. Restaure no novo endereço e confirme os PDFs e os recibos centrais. Não limpe dados do Safari nem feche sessões privadas com pendências não exportadas.

## Cópia administrativa completa

`preserve_system.py` prepara um pacote fora do repositório com dumps do banco, dados de autenticação, metadados do Storage, bytes dos arquivos dos buckets, função implantada, código e histórico Git. Exige CLI Supabase autenticada e vinculada ao projeto correto, ferramentas necessárias ao dump, Git e Python. Não foi executado contra o projeto central nesta entrega.

O administrador configura `PRS_SUPABASE_URL` e `PRS_SUPABASE_SERVICE_KEY` somente no ambiente local seguro. Nunca envie a chave administrativa na conversa nem coloque credenciais ou pacotes de dados no GitHub. Execute o script a partir do repositório original com `--output` apontando para uma pasta nova fora dele. Use `--verify` para conferir um pacote existente. A presença de `INCOMPLETE.txt` significa que o pacote não deve ser usado para migrar.

Faça a exportação em uma janela sem alterações: dumps e downloads são operações separadas, não um retrato atômico. Proteja e criptografe o pacote, mantenha uma segunda cópia fora do computador e estabeleça uma rotina de backup. Inventarie separadamente segredos da função, configurações de autenticação, provedores de e-mail, DNS, domínio e integrações; eles não são todos exportados pelo script.

## Teste de restauração obrigatório antes da troca

1. Use um ambiente separado, nunca o projeto em produção para ensaios destrutivos.
2. Confira o manifesto e os hashes; restaure o banco seguindo o procedimento oficial do Supabase, incluindo usuários e permissões. Recrie buckets e envie os bytes aos caminhos originais registrados no manifesto. O script prepara exportação, não executa restauração automática.
3. Implante a função, configure seus segredos e a nova hospedagem. Confira contas, empresas, colaboradores, modelos e escopos de gestores.
4. Compare contagens por empresa, revise documentos e PDFs amostrados e teste arquivos de várias datas. Teste isolamento entre empresas e permissões de proprietário/gestor/executante.
5. Faça uma inspeção offline, exporte o PDF, reconecte, confirme recebimento no painel e consulte o mesmo PDF em outro aparelho.
6. Só depois da aprovação mantenha o endereço antigo disponível durante a transição e comunique o novo link. Defina um prazo de reversão.

Não se pode prometer ausência de perda antes de conferir um backup e testar sua restauração. Um pacote íntegro demonstra que seus bytes não mudaram; não comprova, sozinho, completude nem autenticidade.

## Próximas prioridades

- MFA para proprietário e administradores; credenciais individuais para gestores e menor privilégio.
- Repositório privado e proteção de publicação, conforme permissões da conta; código servido ao navegador continuará inspecionável.
- Reduzir exposição de cadastros na entrada pública, preservando o preenchimento sem conta mediante um mecanismo de acesso de campo a definir.
- Monitorar falhas de envio, capacidade de armazenamento, backups e recuperação; separar homologação de produção.
- Definir retenção documental, revisão técnica, tratamento de dados pessoais e regras de evidência com o responsável da empresa.

Referências: https://supabase.com/docs/guides/platform/backups ; https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore ; https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits
