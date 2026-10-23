# Componentes e materiais de terceiros

Inventário inicial conferido em 23/10/2026. O aviso de direitos na raiz se
restringe às contribuições originais da PRS. REIS; não substitui estes avisos
nem permite reivindicar propriedade exclusiva sobre dependências e modelos
de outras organizações.

| Componente | Arquivos principais | Licença/aviso preservado |
| --- | --- | --- |
| pdf-lib | `vendor/pdf-lib.min.js` | MIT, `vendor/LICENSE-pdf-lib.md` |
| Tesseract.js 7.0.0 | `vendor/ocr/tesseract.min.js`, `worker.min.js` | Apache-2.0, `LICENSE-tesseract.txt`; avisos de dependências nos dois arquivos `.LICENSE.txt` correspondentes |
| Tesseract core/WASM | `vendor/ocr/` | `vendor/ocr/LICENSE-core.txt`; conferir também as condições dos componentes e dados de idioma na revisão final |
| SheetJS CE 0.20.3 | `vendor/documents/xlsx.full.min.js` | Apache-2.0, `vendor/documents/LICENSE-xlsx` |
| Mammoth 1.12.0 | `vendor/documents/mammoth.browser.min.js` | BSD-2-Clause, `vendor/documents/LICENSE-mammoth` |
| PDF.js 5.6.205 | `vendor/documents/pdf.min.mjs`, `pdf.worker.min.mjs` | Apache-2.0, `vendor/documents/LICENSE-pdfjs` |

As versões dos leitores de documentos estão em `vendor/documents/VERSIONS.txt`.
Em `vendor/ocr/VERSIONS.txt` consta a origem do pacote Tesseract.js e a
verificação dos arquivos distribuídos. Os avisos de licença referidos pelos
banners do leitor e do worker foram recuperados do pacote oficial exato,
verificado por integridade e comparado byte a byte. Os binários de execução
não foram substituídos nesta etapa.

## Marcas e modelos documentais

- `assets/ppl-logo-oficial.png`, `assets/ppl-forms/`, catálogos e modelos
  identificados como PPL contêm marca, estrutura ou conteúdo relacionado à PPL.
- `assets/vale/`, modelos e referências de procedimento Vale contêm materiais
  de terceiros. A digitalização e o código de preenchimento não transferem
  automaticamente os direitos sobre o documento original.
- As marcas e os arquivos visuais PRS. REIS devem ter sua origem e direitos
  documentados na preparação do pedido de marca. Este inventário não afirma
  que o nome está disponível nem que houve registro.

O proprietário informou que o desenvolvimento da plataforma foi iniciativa
própria, sem vínculo contratual com PPL/Vale, e que a PPL foi usada como
exemplo de cadastro para demonstrar o serviço. Essa declaração não representa
endosso, contratação ou cessão de marcas/formulários por essas organizações.
Os materiais de terceiros ficam fora da reivindicação de exclusividade do
código original. A autorização para uso comercial de cada material deve ser
documentada antes de oferecê-lo a clientes.

## Limites deste inventário

Não se trata de parecer de titularidade nem de auditoria jurídica completa
das licenças transitivas. A ausência de autorização de terceiros neste
repositório não comprova que ela inexiste; significa que não foi localizada
nesta revisão. Não publicar dados ou documentos reais de clientes como
amostras ou como parte da documentação de registro.
