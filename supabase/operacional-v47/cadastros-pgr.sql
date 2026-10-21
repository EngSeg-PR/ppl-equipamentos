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
COMMIT;
