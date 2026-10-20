-- PRS. REIS v46: nova versão da inspeção própria PPL.
-- Mantém os snapshots v1 e as inspeções/PDFs existentes, inclusive para envio de pendências antigas.
-- Apenas retira a versão anterior da seleção de NOVAS inspeções.
BEGIN;
DO $migration$
DECLARE
  company_uuid uuid;
  new_snapshot jsonb := $model${"id":"ppl-ssma-inspecao-rotina","version":"2","title":"AÇÕES DE SSMA — INSPEÇÃO PPL","equipmentName":"Inspeção de rotina SSMA","equipmentMode":"generic","identificationLabel":"Local da inspeção","reportTemplate":"ppl-ssma-v1","identifiers":[{"name":"time","label":"Hora","type":"time","required":true},{"name":"department","label":"Gerência","type":"text","required":true},{"name":"contractManager","label":"Gestor de contrato","type":"text","required":false},{"name":"clientManager","label":"Gestor do cliente","type":"text","required":false},{"name":"safetyEngineer","label":"Engenheiro de Segurança","type":"text","required":false},{"name":"safetyTechnician","label":"Técnico de Segurança","type":"text","required":false},{"name":"description","label":"Descrição da atividade / inspeção","type":"textarea","required":true},{"name":"nonconformities","label":"Não conformidades / condição de risco","type":"textarea","required":true},{"name":"immediateActions","label":"Ações imediatas","type":"textarea","required":true},{"name":"recommendations","label":"Recomendações / ações corretivas","type":"textarea","required":true},{"name":"measures","label":"Providências tomadas pela área responsável","type":"textarea","required":false},{"name":"actionResponsible","label":"Responsável pelas ações","type":"text","required":true},{"name":"actionDeadline","label":"Prazo das ações","type":"deadline","required":false},{"name":"annexes","label":"Anexos / citar quais","type":"textarea","required":false},{"name":"releaseManager","label":"Nome / matrícula do gestor que registrou a liberação (se houver)","type":"text","required":false},{"name":"releaseDepartment","label":"Gerência da liberação (se houver)","type":"text","required":false},{"name":"releaseDate","label":"Data da liberação (se houver)","type":"date","required":false},{"name":"recordType","label":"Registro","type":"select","required":true,"options":["Inspeção de rotina","Notificação","Interdição"]},{"name":"reference","label":"Referente a","type":"select","required":true,"options":["Área / instalações","Equipamento","Atividade"]},{"name":"priority","label":"Prioridade","type":"select","required":true,"options":["Muito alta","Alta","Moderada"]},{"name":"rac","label":"RAC aplicável","type":"multi","required":true,"options":["RAC 01","RAC 02","RAC 03","RAC 04","RAC 05","RAC 06","RAC 07","RAC 08","RAC 09","RAC 10","RAC 11","Não aplica"]}],"requiresWorkerPhoto":true,"types":["Inspeção de rotina SSMA"],"items":[{"id":"ppl-ssma-resultado","category":"Resultado da inspeção","text":"Classifique a condição observada nesta inspeção. Descreva as não conformidades e as ações nos campos do relatório.","sourceNumber":"1"}],"source":{"form":"Modelo de inspeção PPL","sheet":"Inspeção SSMA","guidance":["O responsável registra as condições observadas e as ações. A classificação não gera liberação automática de atividade."]}}$model$::jsonb;
BEGIN
  SELECT id INTO company_uuid FROM public.ppl_companies WHERE slug='ppl';
  IF company_uuid IS NULL THEN
    RAISE EXCEPTION 'Empresa PPL não encontrada; nenhuma alteração foi aplicada.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.ppl_company_models
    WHERE company_id=company_uuid AND model_id='ppl-ssma-inspecao-rotina' AND version='2'
      AND snapshot IS DISTINCT FROM new_snapshot
  ) THEN
    RAISE EXCEPTION 'Já existe outro snapshot para a inspeção PPL versão 2; preserve-o e revise a migração.';
  END IF;
  INSERT INTO public.ppl_company_models(company_id,model_id,version,kind,snapshot,active)
  VALUES (company_uuid,'ppl-ssma-inspecao-rotina','2','inspection',new_snapshot,true)
  ON CONFLICT (company_id,model_id,version) DO NOTHING;
  UPDATE public.ppl_company_models SET active=false
  WHERE company_id=company_uuid AND model_id='ppl-ssma-inspecao-rotina' AND version='1' AND active=true;
END;
$migration$;
COMMIT;
