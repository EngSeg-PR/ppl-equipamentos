# Privacidade e preparação comercial - 22/10/2026

Frontend/cache50; API48 mantida. Não há migração de banco nesta entrega.

`privacidade.html` e `termo-ciencia.html` são documentos estáticos, com PDF para download em `assets/legal/`. Fontes canônicas editáveis e versionadas em `legal/*.json`. O CSS é restrito às páginas legais e aos links do rodapé. Os links do aplicativo abrem em outra aba para não interromper o preenchimento.

Não foi acrescentado cadastro, login, checkbox obrigatório ou aceite ao executante. O termo é modelo para leitura e eventual assinatura externa; a visita não gera recibo de ciência, consentimento nem assinatura no servidor. A eventual coleta digital versionada é uma etapa própria, ainda não implementada.

Identificação pública autorizada: responsável provisório Paulo Ricardo Santos Reis, pessoa física; sede Rua das Patativas, nº 23, Monte Castelo, São Luís/MA, CEP 65031-790; contato prs.reis098@gmail.com. Pessoa jurídica ainda não formalizada; não inventar CNPJ. A intenção de abrir MEI não comprova elegibilidade: consultoria de engenharia não é atividade de MEI. Rever formalização com contador considerando consultoria, licença e demais serviços reais.

O aviso foi confrontado com o código atual, incluindo dados coletados, CPF privado, foto e assinatura sem reconhecimento biométrico, fornecedores, persistência offline e acesso administrativo. Região principal Supabase conferida pela tela de configurações: São Paulo, sa-east-1. Não afirmar processamento exclusivamente nacional nem conformidade integral automática.

## Limitações que continuam abertas

- `company-context` anônimo fornece nome, matrícula, função e descrição do cargo. A política revela a limitação; isso não substitui corrigir o acesso. Priorizar link/QR de campo revogável e com escopo, mantendo executante sem conta e sem expor CPF.
- Não há comprovação de restauração central completa nem cópia automática de todo Storage. Backup de código não cobre banco, arquivos ou pendências de aparelhos.
- Não há controle comercial completo de licença/vigência no servidor. A política não implementa cobrança ou ativação.
- GitHub Pages restringe hospedagem de SaaS comercial. Planejar a mudança da interface para serviço compatível, mantendo inicialmente o mesmo Supabase e conciliando pendências no domínio antigo.
- Formalizar contratos, papéis de tratamento, retenção por documento, direitos de uso dos modelos, procedimento de incidentes e saída/exportação antes da expansão comercial. Revisão jurídica/contábil necessária para contratar; esta entrega não declara regularização da empresa.

O plano comercial detalhado é arquivo privado fora do repositório. Não publicar estratégia, preços internos ou exportações de clientes junto ao código.

## Verificação

`tests/privacy50.cjs`: leitura móvel/desktop, download dos bytes exatos dos PDFs, ausência de campos/aceite novos, links em outra aba, precache completo, leitura e PDFs offline. Usa respostas simuladas e não grava em produção. PDFs devem ser renderizados e conferidos antes da entrega. Homologação real em Safari permanece parte dos testes de campo do produto.
