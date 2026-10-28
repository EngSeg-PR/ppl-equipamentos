# Servidor do acesso pessoal do app — v55

Base integral: servidor54 já existente. Atualização incremental, sem novos cadastros ou alteração da gestão/privacidade. Consulte `../../operations/ACESSO-PESSOAL-APP-v55.md`.

1. Aplicar `ATIVAR-v55.sql` sobre o banco que já possui51 e54. Acrescenta uma função privada, não modifica evidências nem a autenticação54.
2. Atualizar a função existente **ppl-api-** com todo o conteúdo de `ppl-api-dashboard.ts`, preservando variáveis seguras e configuração.
3. Publicar o aplicativo/cache55 depois de confirmar o servidor. Não publicar apenas o app antes da ativação dos endpoints pessoais.
4. Conferir HTTPS e interface real. Não gerar avaliações fictícias em produção.

O app reutiliza a sessão de executante54. Seu token vai em `X-PPL-Executor`; nenhuma credencial integra o conteúdo da avaliação. A matrícula é um segredo fraco/conhecido e continua com essa limitação.

Presença de fontes ou testes aprovados não significa implantação. A confirmação final de ativação ainda é necessária.
