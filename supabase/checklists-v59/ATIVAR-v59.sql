-- PRS. REIS v59: revisão imutável dos checklists internos PPL.
-- Não modifica inspeções, PDFs, usuários, modelos Vale ou suas permissões.
BEGIN;

CREATE TABLE IF NOT EXISTS public.ppl_checklist_revisions (
  id uuid PRIMARY KEY,
  sequence bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  company_id uuid NOT NULL REFERENCES public.ppl_companies(id),
  revision text NOT NULL CHECK (length(revision) BETWEEN 1 AND 100),
  source_filename text NOT NULL CHECK (length(source_filename) BETWEEN 1 AND 240),
  source_hash text NOT NULL CHECK (source_hash ~ '^[a-f0-9]{64}$'),
  source_mime text NOT NULL CHECK (source_mime IN ('application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')),
  source_path text NOT NULL,
  source_size integer NOT NULL CHECK (source_size BETWEEN 1 AND 14680064),
  request_hash text NOT NULL CHECK (request_hash ~ '^[a-f0-9]{64}$'),
  model_count integer NOT NULL CHECK (model_count BETWEEN 1 AND 46),
  models jsonb NOT NULL CHECK (jsonb_typeof(models)='array'),
  published_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (company_id,source_hash),
  UNIQUE (company_id,revision)
);
ALTER TABLE public.ppl_checklist_revisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ppl_checklist_revisions FROM public,anon,authenticated;
GRANT ALL ON public.ppl_checklist_revisions TO service_role;
REVOKE ALL ON SEQUENCE public.ppl_checklist_revisions_sequence_seq FROM public,anon,authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.ppl_checklist_revisions_sequence_seq TO service_role;

CREATE OR REPLACE FUNCTION public.ppl_publish_checklist_revision_v59(
  p_revision jsonb,
  p_models jsonb,
  p_expected_revision uuid,
  p_expected_custom jsonb,
  p_actor uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE
  v_company uuid := (p_revision->>'company_id')::uuid;
  v_id uuid := (p_revision->>'id')::uuid;
  v_slug text;
  v_latest uuid;
  v_existing public.ppl_checklist_revisions%ROWTYPE;
  v_current jsonb;
  v_model jsonb;
  v_count integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.ppl_access a WHERE a.user_id=p_actor AND a.role='owner' AND a.active) THEN
    RAISE EXCEPTION 'revision_owner_required' USING ERRCODE='42501';
  END IF;
  SELECT c.slug INTO v_slug FROM public.ppl_companies c WHERE c.id=v_company FOR UPDATE;
  IF v_slug IS DISTINCT FROM 'ppl' THEN
    RAISE EXCEPTION 'revision_ppl_required' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_existing FROM public.ppl_checklist_revisions r
   WHERE r.company_id=v_company AND r.source_hash=p_revision->>'source_hash';
  IF FOUND THEN
    IF v_existing.request_hash IS DISTINCT FROM p_revision->>'request_hash' THEN
      RAISE EXCEPTION 'revision_file_conflict' USING ERRCODE='40001';
    END IF;
    RETURN jsonb_build_object('id',v_existing.id,'revision',v_existing.revision,'modelCount',v_existing.model_count,'idempotent',true);
  END IF;
  SELECT r.id INTO v_latest FROM public.ppl_checklist_revisions r
   WHERE r.company_id=v_company ORDER BY r.sequence DESC LIMIT 1;
  IF v_latest IS DISTINCT FROM p_expected_revision THEN
    RAISE EXCEPTION 'revision_conflict' USING ERRCODE='40001';
  END IF;
  IF EXISTS (SELECT 1 FROM public.ppl_checklist_revisions r WHERE r.company_id=v_company AND r.revision=p_revision->>'revision') THEN
    RAISE EXCEPTION 'revision_label_conflict' USING ERRCODE='40001';
  END IF;
  IF jsonb_typeof(p_models) IS DISTINCT FROM 'array' OR jsonb_array_length(p_models) NOT BETWEEN 1 AND 46 THEN
    RAISE EXCEPTION 'revision_models_invalid';
  END IF;
  v_count:=jsonb_array_length(p_models);
  IF v_count<>(SELECT count(DISTINCT x->'snapshot'->>'id') FROM jsonb_array_elements(p_models) x) THEN
    RAISE EXCEPTION 'revision_models_invalid';
  END IF;
  FOR v_model IN SELECT value FROM jsonb_array_elements(p_models) LOOP
    IF v_model->>'kind' IS DISTINCT FROM 'checklist'
       OR (v_model->'snapshot'->>'id') NOT LIKE 'ppl-%'
       OR v_model->'snapshot'->>'version' IS DISTINCT FROM '59-'||v_id::text
       OR v_model->'snapshot'->'reportLayout'->>'type' IS DISTINCT FROM 'ppl-equipment-table'
       OR v_model->'snapshot'->'reportLayout'->>'issuer' IS DISTINCT FROM 'PPL'
       OR jsonb_typeof(v_model->'snapshot'->'items') IS DISTINCT FROM 'array'
       OR jsonb_array_length(v_model->'snapshot'->'items') NOT BETWEEN 1 AND 250 THEN
      RAISE EXCEPTION 'revision_models_invalid';
    END IF;
  END LOOP;
  PERFORM 1 FROM public.ppl_company_models m WHERE m.company_id=v_company
   AND m.model_id IN (SELECT x->'snapshot'->>'id' FROM jsonb_array_elements(p_models) x)
   FOR UPDATE;
  SELECT coalesce(jsonb_agg(jsonb_build_object('model_id',m.model_id,'version',m.version,'active',m.active)
                          ORDER BY m.model_id COLLATE "C",m.version COLLATE "C"),'[]'::jsonb)
    INTO v_current FROM public.ppl_company_models m
   WHERE m.company_id=v_company
     AND m.model_id IN (SELECT x->'snapshot'->>'id' FROM jsonb_array_elements(p_models) x);
  IF v_current IS DISTINCT FROM p_expected_custom THEN
    RAISE EXCEPTION 'revision_models_conflict' USING ERRCODE='40001';
  END IF;
  INSERT INTO public.ppl_checklist_revisions
    (id,company_id,revision,source_filename,source_hash,source_mime,source_path,source_size,request_hash,model_count,models,published_by)
  VALUES
    (v_id,v_company,p_revision->>'revision',p_revision->>'source_filename',p_revision->>'source_hash',
     p_revision->>'source_mime',p_revision->>'source_path',(p_revision->>'source_size')::integer,
     p_revision->>'request_hash',v_count,p_models,p_actor);
  UPDATE public.ppl_company_models m SET active=false WHERE m.company_id=v_company
   AND m.model_id IN (SELECT x->'snapshot'->>'id' FROM jsonb_array_elements(p_models) x);
  INSERT INTO public.ppl_company_models(company_id,model_id,version,kind,snapshot,active)
  SELECT v_company,x->'snapshot'->>'id',x->'snapshot'->>'version','checklist',x->'snapshot',(x->>'active')::boolean
  FROM jsonb_array_elements(p_models) x;
  RETURN jsonb_build_object('id',v_id,'revision',p_revision->>'revision','modelCount',v_count,'idempotent',false);
END;
$function$;
REVOKE ALL ON FUNCTION public.ppl_publish_checklist_revision_v59(jsonb,jsonb,uuid,jsonb,uuid) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ppl_publish_checklist_revision_v59(jsonb,jsonb,uuid,jsonb,uuid) TO service_role;

-- Serialize explicit owner removal with a simultaneous revision publication.
CREATE OR REPLACE FUNCTION public.ppl_hide_checklist_model_v59(
  p_company uuid,p_snapshot jsonb,p_actor uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE
  v_slug text;
  v_model text := p_snapshot->>'id';
  v_version text := p_snapshot->>'version';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.ppl_access a WHERE a.user_id=p_actor AND a.role='owner' AND a.active) THEN
    RAISE EXCEPTION 'revision_owner_required' USING ERRCODE='42501';
  END IF;
  SELECT c.slug INTO v_slug FROM public.ppl_companies c WHERE c.id=p_company FOR UPDATE;
  IF v_slug IS DISTINCT FROM 'ppl' THEN
    RAISE EXCEPTION 'revision_ppl_required' USING ERRCODE='42501';
  END IF;
  IF v_model IS NULL OR v_model NOT LIKE 'ppl-%' OR v_version IS NULL
     OR p_snapshot->'reportLayout'->>'type' IS DISTINCT FROM 'ppl-equipment-table'
     OR p_snapshot->'reportLayout'->>'issuer' IS DISTINCT FROM 'PPL' THEN
    RAISE EXCEPTION 'revision_models_invalid';
  END IF;
  IF EXISTS (SELECT 1 FROM public.ppl_company_models m WHERE m.company_id=p_company AND m.model_id=v_model AND m.active AND m.version<>v_version) THEN
    RAISE EXCEPTION 'revision_models_conflict' USING ERRCODE='40001';
  END IF;
  UPDATE public.ppl_company_models m SET active=false WHERE m.company_id=p_company AND m.model_id=v_model;
  INSERT INTO public.ppl_company_models(company_id,model_id,version,kind,snapshot,active)
    VALUES(p_company,v_model,v_version,'checklist',p_snapshot,false)
    ON CONFLICT(company_id,model_id,version) DO UPDATE SET active=false;
  RETURN jsonb_build_object('ok',true);
END;
$function$;
REVOKE ALL ON FUNCTION public.ppl_hide_checklist_model_v59(uuid,jsonb,uuid) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ppl_hide_checklist_model_v59(uuid,jsonb,uuid) TO service_role;
COMMIT;
