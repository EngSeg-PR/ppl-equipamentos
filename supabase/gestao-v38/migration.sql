BEGIN;
-- Apenas novas estruturas. Não altera inspeções, alertas, modelos ou logins.
CREATE TABLE IF NOT EXISTS public.ppl_management_entries (
 id uuid PRIMARY KEY,
 company_id uuid NOT NULL REFERENCES public.ppl_companies(id),
 kind text NOT NULL CHECK(kind IN ('training','legal-action','legal-document','nr')),
 unit text NOT NULL DEFAULT '', team text NOT NULL DEFAULT '',
 payload jsonb NOT NULL CHECK(jsonb_typeof(payload)='object'),
 version integer NOT NULL DEFAULT 1,
 created_by uuid NOT NULL REFERENCES auth.users(id),
 updated_by uuid NOT NULL REFERENCES auth.users(id),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ppl_management_company_kind ON public.ppl_management_entries(company_id,kind,updated_at);
ALTER TABLE public.ppl_management_entries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ppl_management_entries FROM anon,authenticated;
GRANT SELECT ON public.ppl_management_entries TO authenticated;
GRANT ALL ON public.ppl_management_entries TO service_role;
DROP POLICY IF EXISTS management_read_scope ON public.ppl_management_entries;
CREATE POLICY management_read_scope ON public.ppl_management_entries FOR SELECT TO authenticated
 USING(public.ppl_can_read_company(company_id,unit,team));
CREATE TABLE IF NOT EXISTS public.ppl_management_files (
 id uuid PRIMARY KEY, entry_id uuid NOT NULL REFERENCES public.ppl_management_entries(id),
 company_id uuid NOT NULL REFERENCES public.ppl_companies(id),
 path text NOT NULL UNIQUE, name text NOT NULL, mime text NOT NULL,
 size integer NOT NULL CHECK(size>0 AND size<=8388608),
 created_by uuid NOT NULL REFERENCES auth.users(id), created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.ppl_management_files ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ppl_management_files FROM anon,authenticated;
GRANT SELECT ON public.ppl_management_files TO authenticated;
GRANT ALL ON public.ppl_management_files TO service_role;
DROP POLICY IF EXISTS management_files_read ON public.ppl_management_files;
CREATE POLICY management_files_read ON public.ppl_management_files FOR SELECT TO authenticated
 USING(EXISTS(SELECT 1 FROM public.ppl_management_entries e WHERE e.id=ppl_management_files.entry_id AND e.company_id=ppl_management_files.company_id));
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 VALUES('prs-management','prs-management',false,8388608,ARRAY['application/pdf','image/png','image/jpeg','image/webp','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/msword'])
 ON CONFLICT(id) DO NOTHING;
COMMIT;
