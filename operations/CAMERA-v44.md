# Captura pela câmera — versão 44

## Aplicação
Nos checklists e inspeções do executante, as fotos de evidência e de identificação do responsável são obtidas pela câmera dentro do aplicativo. Não há seletor de arquivos/fototeca nem fallback para upload. Os controles de anexos documentais e modelos no acesso de proprietário/gestão não foram alterados; a restrição desta etapa é das fotos no preenchimento de campo.

O componente solicita somente vídeo (sem microfone), inicia preferencialmente a câmera frontal para o responsável e a traseira para evidência, permite trocar a câmera, fotografar, refazer e confirmar. A preferência frontal/traseira depende das câmeras disponibilizadas pelo aparelho. O quadro é JPEG limitado a 1400 pixels no maior lado. A data é a do dispositivo e o marcador captureMethod=camera é metadado do aplicativo, não uma assinatura de autenticidade.

A câmera é encerrada ao fotografar, cancelar, sair da página ou colocá-la em segundo plano. Pedidos de permissão concluídos depois do cancelamento também encerram o fluxo recebido. Não gravar rascunho apenas por abrir/cancelar a câmera ou por negar permissão. A imagem só entra no registro ao confirmar Usar esta foto.

Se não houver câmera, suporte ou permissão, apresentar orientação e não oferecer a galeria. Novas finalizações exigem foto do responsável capturada pela câmera; fotos de rascunhos antigos sem esse marcador precisam ser substituídas antes de finalizar. Registros anteriores concluídos, PDFs e backups permanecem preservados. Mantido limite de três fotos por item e montagem do PDF de até quatro fotos por página.

## Limites
Este é um controle do fluxo de captura no navegador, não uma prova biométrica nem um mecanismo antifraude absoluto. A API de mídia pode disponibilizar dispositivos virtuais; um aparelho ou cliente adulterado pode forjar dados. O timestamp e o marcador enviados pelo cliente não comprovam presença física, identidade ou horário do servidor. O endpoint público e as políticas centrais não foram transformados em um serviço de atestação nesta etapa. A autenticação/identificação de executantes permanece a definida no produto.

Exige contexto seguro (HTTPS, ou localhost no teste) e permissão da câmera. Continua funcionando sem rede após preparar o aplicativo offline no aparelho, sujeito à disponibilidade da câmera e permissões do navegador. Homologação física Safari/iPhone/Android é distinta dos testes de Chromium com câmera simulada.

Referências primárias: https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia e https://developer.mozilla.org/en-US/docs/Web/API/MediaStream/getTracks.

## Verificação
A regressão tests/checklist-lifecycle.cjs usa o dispositivo de vídeo sintético do Chromium, sem abrir a câmera física do usuário e sem gravar no Supabase real. Verifica cancelamento, permissão negada, ausência de input de arquivo para fotos, preferência frontal/traseira, recaptura, confirmação, parada das tracks e persistência. Mantém testes online/offline, download de bytes PDF, falha de rede, falha de PDF e falha de armazenamento, retomada de rascunho, conclusão e nova seleção.

Aplicativo v44; servidor permanece v42. Não há migração SQL ou atualização manual de função nesta entrega. Código local da câmera e estilos incluídos no cache do aplicativo.
