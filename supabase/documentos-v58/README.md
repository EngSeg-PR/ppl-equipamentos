# Ordens de serviço — API58

Fonte integral baseada em `../visual-v57/ppl-api-dashboard.ts`, preservando o Sistema Apto e seus contratos atuais. Nome da função existente: **ppl-api-**. Nenhuma migração SQL, conta, variável secreta ou mudança de permissões é necessária nesta atualização.

## Modelo novo

`certificates-4-v3`, versão3, renderização58, acrescenta a escolha de assinatura:

- **Em papel**: permite registrar a ordem sem assinatura desenhada. O campo `workerSignature` deve ser vazio. Uma imagem enviada nesse modo é rejeitada, para não apagar silenciosamente uma assinatura.
- **No sistema**: exige a assinatura desenhada do colaborador, com a validação já usada pelos documentos.

O servidor continua preenchendo nome, função e matrícula pelo cadastro protegido da empresa. A descrição da atividade permanece obrigatória. A nova modalidade não comprova recebimento ou assinatura física: o documento emitido sem imagem aguarda essa coleta.

Os modelos antigos `certificates-4` e `certificates-4-v2` continuam no catálogo para consulta e reprodução histórica. O v2 fica retirado da emissão nova; assinaturas exigidas nesses registros continuam obrigatórias em uma edição explícita. Não transformar um registro antigo em modelo3: emitir uma cópia própria a partir do snapshot, mantendo o registro e o PDF anterior.

O `management-list` informa `moduleVersion:58`, permitindo à interface verificar a disponibilidade antes de salvar o novo modelo. O cabeçalho geral passa a `X-PPL-API-Version:58`; as versões específicas de outras ações, incluindo Apto57, são preservadas.

## Publicação

Atualizar a função existente usando **todo** o arquivo `ppl-api-dashboard.ts`. Não executar schemas ou migrações antigas e não colar somente um fragmento. Publicar a interface58 compatível com o modelo novo e conferir a versão por HTTPS. Uma interface antiga pode precisar de recarga para deixar de tentar emitir a versão2 retirada; os formulários e PDFs já registrados não são apagados.

## Verificação local

`node tests/os58-server.cjs` usa o handler completo58 e serviços locais simulados, sem rede de produção. Verifica os dois modos de assinatura, rejeições, compatibilidade dos registros antigos, dados canônicos do colaborador, conflitos de versão, autorização por empresa/unidade/equipe e anexos privados com hash.

O teste também confere que o catálogo embutido é idêntico ao JSON da interface e que todo o código57 fora das alterações de OS/catalogação/versão permanece igual. Não há alegação de teste de banco ou sessão real em produção nesta etapa.
