# Arquivos e exclusão de modelos — versão 34

Exclusivamente no acesso do proprietário: importar PDF (texto ou digitalizado com OCR), Excel .xlsx/.xls, Word .docx e fotos PNG/JPEG/WebP. Leitura local, texto editável, montagem de itens e revisão obrigatória antes do cadastro. Metadados de origem incluem nome, tipo e SHA-256. Limites: 15 MB, 80 páginas ou abas, 1 milhão de caracteres. O arquivo é lido localmente; não é arquivado integralmente no servidor.

A importação auxilia a transcrição de perguntas. Ela não mapeia automaticamente o desenho de qualquer documento: a reprodução fiel de novos formulários físicos exige preparação específica do layout, como os28 modelos Vale originais já implantados. Modelos Vale anteriores mantidos.

Cada modelo disponível tem “Excluir modelo” somente no painel do proprietário. A confirmação retira o modelo dos novos preenchimentos da empresa selecionada, usando active=false e preservando seu snapshot. Inspeções, PDFs, alertas e logins existentes não são apagados. Modelos embutidos recebem uma sobreposição restrita à empresa, sem afetar outras empresas. Pendências anteriores continuam reconhecidas no envio.

Ativação: atualizar a função existente ppl-api- com supabase/ppl-api-dashboard.ts. Nenhum SQL novo. Após confirmação e verificação do servidor, publicar a versão34 do site. Não publicar primeiro o frontend, pois a exclusão depende da nova função.

Testes: PDF de duas páginas, arquivo Excel Vale real, DOCX e OCR real de PDF digitalizado; cadastro revisado e botão de exclusão em viewport móvel; logout remove os controles; API rejeita gestor/anônimo, impede exclusão em empresa errada, não duplica modelos e preserva inspeção existente. Sem criação ou exclusão de dados reais. Bibliotecas locais: PDF.js5.6.205, SheetJS CE0.20.3, Mammoth1.12.0, OCR Tesseract já existente.

Estado: implementação preparada em branch feat/arquivos-modelos-v34; aguardando atualização da função. A versão33 permanece publicada.
