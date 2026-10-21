BEGIN;

ALTER TABLE public.ppl_employees ADD COLUMN IF NOT EXISTS cpf text NOT NULL DEFAULT '';
ALTER TABLE public.ppl_companies ADD COLUMN IF NOT EXISTS department text NOT NULL DEFAULT '';
ALTER TABLE public.ppl_companies ADD COLUMN IF NOT EXISTS safety_engineer text NOT NULL DEFAULT '';
ALTER TABLE public.ppl_companies ADD COLUMN IF NOT EXISTS profile jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE OR REPLACE FUNCTION public.ppl_register_company_v47(p_name text,p_slug text,p_logo text,p_cnpj text,p_cnae text,p_contract_manager text,p_department text,p_safety_engineer text,p_profile jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $company_v47$
DECLARE c public.ppl_companies; created jsonb;
BEGIN
 created:=public.ppl_register_company(p_name,p_slug,p_logo,p_cnpj,p_cnae,p_contract_manager);
 UPDATE public.ppl_companies SET department=p_department,safety_engineer=p_safety_engineer,profile=p_profile WHERE id=(created->>'id')::uuid RETURNING * INTO c;
 RETURN to_jsonb(c);
END;
$company_v47$;
REVOKE ALL ON FUNCTION public.ppl_register_company_v47(text,text,text,text,text,text,text,text,jsonb) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ppl_register_company_v47(text,text,text,text,text,text,text,text,jsonb) TO service_role;

CREATE TABLE IF NOT EXISTS public.ppl_pgr_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), company_id uuid NOT NULL REFERENCES public.ppl_companies(id),
 version integer NOT NULL CHECK(version>0), payload jsonb NOT NULL,
 created_by uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(company_id,version)
);
CREATE TABLE IF NOT EXISTS public.ppl_pgr_files (
 id uuid PRIMARY KEY, company_id uuid NOT NULL REFERENCES public.ppl_companies(id),
 kind text NOT NULL CHECK(kind IN ('base','evidence')), path text NOT NULL UNIQUE,
 name text NOT NULL, mime text NOT NULL, size integer NOT NULL CHECK(size>0 AND size<=8388608),
 sha256 text NOT NULL, created_by uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.ppl_pgr_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ppl_pgr_files ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ppl_pgr_versions,public.ppl_pgr_files FROM public,anon,authenticated;
GRANT ALL ON public.ppl_pgr_versions,public.ppl_pgr_files TO service_role;
INSERT INTO storage.buckets(id,name,public,file_size_limit) VALUES('prs-pgr','prs-pgr',false,8388608) ON CONFLICT(id) DO NOTHING;


-- PRS. REIS v47: nova versão da inspeção própria PPL.
-- Mantém os snapshots v1 e as inspeções/PDFs existentes, inclusive para envio de pendências antigas.
-- Apenas retira a versão anterior da seleção de NOVAS inspeções.

DO $migration$
DECLARE
  company_uuid uuid;
  new_snapshot jsonb := $model${"id":"ppl-ssma-inspecao-rotina","version":"3","title":"AÇÕES DE SSMA — INSPEÇÃO PPL","equipmentName":"Inspeção de rotina SSMA","equipmentMode":"generic","identificationLabel":"Local da inspeção","reportTemplate":"ppl-ssma-v1","identifiers":[{"name":"time","label":"Hora","type":"time","required":true},{"name":"department","label":"Gerência","type":"text","required":true},{"name":"contractManager","label":"Gestor de contrato","type":"text","required":false},{"name":"clientManager","label":"Gestor do cliente","type":"text","required":false},{"name":"safetyEngineer","label":"Engenheiro de Segurança","type":"text","required":false},{"name":"safetyTechnician","label":"Técnico de Segurança","type":"text","required":false},{"name":"description","label":"Descrição da atividade / inspeção","type":"textarea","required":true},{"name":"nonconformities","label":"Não conformidades / condição de risco","type":"textarea","required":true},{"name":"immediateActions","label":"Ações imediatas","type":"textarea","required":true},{"name":"recordType","label":"Registro","type":"select","required":true,"options":["Inspeção de rotina","Notificação","Interdição"]},{"name":"reference","label":"Referente a","type":"select","required":true,"options":["Área / instalações","Equipamento","Atividade"]},{"name":"priority","label":"Prioridade","type":"select","required":true,"options":["Muito alta","Alta","Moderada"]},{"name":"rac","label":"RAC aplicável","type":"multi","required":true,"options":["RAC 01","RAC 02","RAC 03","RAC 04","RAC 05","RAC 06","RAC 07","RAC 08","RAC 09","RAC 10","RAC 11","Não aplica"]}],"requiresWorkerPhoto":true,"types":["Inspeção de rotina SSMA"],"items":[{"id":"ppl-ssma-resultado","category":"Resultado da inspeção","text":"Classifique a condição observada nesta inspeção. Descreva as não conformidades e as ações nos campos do relatório.","sourceNumber":"1"}],"source":{"form":"Modelo de inspeção PPL","sheet":"Inspeção SSMA","guidance":["O responsável registra as condições observadas e as ações. A classificação não gera liberação automática de atividade."]},"hideUnit":true}$model$::jsonb;
BEGIN
  SELECT id INTO company_uuid FROM public.ppl_companies WHERE slug='ppl';
  IF company_uuid IS NULL THEN
    RAISE EXCEPTION 'Empresa PPL não encontrada; nenhuma alteração foi aplicada.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.ppl_company_models
    WHERE company_id=company_uuid AND model_id='ppl-ssma-inspecao-rotina' AND version='3'
      AND snapshot IS DISTINCT FROM new_snapshot
  ) THEN
    RAISE EXCEPTION 'Já existe outro snapshot para a inspeção PPL versão 3; preserve-o e revise a migração.';
  END IF;
  INSERT INTO public.ppl_company_models(company_id,model_id,version,kind,snapshot,active)
  VALUES (company_uuid,'ppl-ssma-inspecao-rotina','3','inspection',new_snapshot,true)
  ON CONFLICT (company_id,model_id,version) DO NOTHING;
  UPDATE public.ppl_company_models SET active=false
  WHERE company_id=company_uuid AND model_id='ppl-ssma-inspecao-rotina' AND version IN ('1','2') AND active=true;
END;
$migration$;


COMMIT;
SELECT model_id,version,active FROM public.ppl_company_models WHERE model_id='ppl-ssma-inspecao-rotina' ORDER BY version;
SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('ppl_pgr_versions','ppl_pgr_files');