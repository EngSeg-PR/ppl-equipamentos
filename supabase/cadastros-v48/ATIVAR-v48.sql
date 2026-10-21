BEGIN;
-- Additive migration: no inspections, PDFs, users or models are removed.
CREATE TABLE IF NOT EXISTS public.ppl_jobs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 company_id uuid NOT NULL REFERENCES public.ppl_companies(id),
 title text NOT NULL CHECK(length(title) BETWEEN 1 AND 160),
 title_key text GENERATED ALWAYS AS (lower(regexp_replace(btrim(title),'[[:space:]]+',' ','g'))) STORED,
 description text NOT NULL DEFAULT '' CHECK(length(description)<=10000),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(company_id,title_key), UNIQUE(company_id,id)
);
ALTER TABLE public.ppl_employees ADD COLUMN IF NOT EXISTS job_id uuid;
ALTER TABLE public.ppl_employees ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
DO $migration$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.ppl_employees'::regclass AND conname='ppl_employee_company_job_fk') THEN
  ALTER TABLE public.ppl_employees ADD CONSTRAINT ppl_employee_company_job_fk FOREIGN KEY(company_id,job_id) REFERENCES public.ppl_jobs(company_id,id);
 END IF;
END;
$migration$;
-- Existing employee descriptions remain intact. Latest nonempty description seeds each function.
INSERT INTO public.ppl_jobs(company_id,title,description)
 SELECT DISTINCT ON(company_id,lower(regexp_replace(btrim(job_title),'[[:space:]]+',' ','g')))
 company_id,regexp_replace(btrim(job_title),'[[:space:]]+',' ','g'),coalesce(job_description,'')
 FROM public.ppl_employees WHERE btrim(job_title)<>''
 ORDER BY company_id,lower(regexp_replace(btrim(job_title),'[[:space:]]+',' ','g')),
 (coalesce(btrim(job_description),'')<>'') DESC,created_at DESC,id
 ON CONFLICT(company_id,title_key) DO NOTHING;
UPDATE public.ppl_employees e SET job_id=j.id FROM public.ppl_jobs j
 WHERE e.company_id=j.company_id AND j.title_key=lower(regexp_replace(btrim(e.job_title),'[[:space:]]+',' ','g')) AND e.job_id IS NULL;

CREATE TABLE IF NOT EXISTS public.ppl_employee_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 company_id uuid NOT NULL REFERENCES public.ppl_companies(id),
 employee_id uuid NOT NULL REFERENCES public.ppl_employees(id),
 name text NOT NULL, employee_number text NOT NULL, job_title text NOT NULL,
 job_description text NOT NULL DEFAULT '', changed_at timestamptz NOT NULL DEFAULT now(), changed_by uuid
);
CREATE INDEX IF NOT EXISTS ppl_employee_history_lookup ON public.ppl_employee_history(company_id,employee_id);
CREATE OR REPLACE FUNCTION public.ppl_employee_history_v48() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $history$
BEGIN
 IF NEW.company_id IS DISTINCT FROM OLD.company_id OR NEW.id IS DISTINCT FROM OLD.id THEN
  RAISE EXCEPTION 'employee_identity_immutable';
 END IF;
 IF ROW(OLD.name,OLD.employee_number,OLD.job_title,OLD.job_description) IS DISTINCT FROM ROW(NEW.name,NEW.employee_number,NEW.job_title,NEW.job_description) THEN
  INSERT INTO public.ppl_employee_history(company_id,employee_id,name,employee_number,job_title,job_description,changed_by)
   VALUES(OLD.company_id,OLD.id,OLD.name,OLD.employee_number,OLD.job_title,coalesce(OLD.job_description,''),nullif(current_setting('prs.employee_actor',true),'')::uuid);
 END IF;
 NEW.updated_at:=clock_timestamp();
 RETURN NEW;
END;
$history$;
CREATE OR REPLACE TRIGGER ppl_employee_history_v48 BEFORE UPDATE ON public.ppl_employees FOR EACH ROW EXECUTE FUNCTION public.ppl_employee_history_v48();
CREATE OR REPLACE FUNCTION public.ppl_preserve_employee_history_v48() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $preserve$
BEGIN RAISE EXCEPTION 'employee_history_immutable'; END;
$preserve$;
CREATE OR REPLACE TRIGGER ppl_preserve_employee_history_v48 BEFORE UPDATE OR DELETE ON public.ppl_employee_history FOR EACH ROW EXECUTE FUNCTION public.ppl_preserve_employee_history_v48();

CREATE OR REPLACE FUNCTION public.ppl_employee_save_v48(
 p_company_id uuid,p_employee_id uuid,p_name text,p_employee_number text,p_job_title text,p_job_description text,p_cpf text,
 p_job_id uuid,p_update_job boolean,p_expected_updated_at timestamptz,p_actor uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $save$
DECLARE person public.ppl_employees; job public.ppl_jobs; normalized_title text;
BEGIN
 IF coalesce(length(btrim(p_name)),0) NOT BETWEEN 1 AND 160 OR coalesce(length(btrim(p_employee_number)),0) NOT BETWEEN 1 AND 80
 OR coalesce(length(btrim(p_job_title)),0) NOT BETWEEN 1 AND 160 OR length(coalesce(p_job_description,''))>10000
 OR (coalesce(p_cpf,'')<>'' AND p_cpf !~ '^[0-9]{11}$') THEN RAISE EXCEPTION 'employee_invalid'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ppl_access WHERE user_id=p_actor AND active AND role='owner') THEN RAISE EXCEPTION 'employee_owner_required'; END IF;
 IF p_employee_id IS NOT NULL THEN
  SELECT * INTO person FROM public.ppl_employees WHERE id=p_employee_id AND company_id=p_company_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'employee_not_found'; END IF;
  IF p_expected_updated_at IS NULL OR person.updated_at IS DISTINCT FROM p_expected_updated_at THEN RAISE EXCEPTION 'employee_conflict'; END IF;
 END IF;
 normalized_title:=regexp_replace(btrim(p_job_title),'[[:space:]]+',' ','g');
 IF p_job_id IS NOT NULL THEN
  SELECT * INTO job FROM public.ppl_jobs WHERE id=p_job_id AND company_id=p_company_id FOR UPDATE;
  IF NOT FOUND OR job.title_key<>lower(normalized_title) THEN RAISE EXCEPTION 'employee_job_invalid'; END IF;
 ELSE
  INSERT INTO public.ppl_jobs(company_id,title,description) VALUES(p_company_id,normalized_title,btrim(coalesce(p_job_description,'')))
   ON CONFLICT(company_id,title_key) DO NOTHING;
  SELECT * INTO job FROM public.ppl_jobs WHERE company_id=p_company_id AND title_key=lower(normalized_title) FOR UPDATE;
 END IF;
 IF p_update_job THEN
  UPDATE public.ppl_jobs SET description=btrim(coalesce(p_job_description,'')),updated_at=clock_timestamp() WHERE id=job.id;
 END IF;
 PERFORM set_config('prs.employee_actor',p_actor::text,true);
 IF p_employee_id IS NULL THEN
  INSERT INTO public.ppl_employees(company_id,name,employee_number,job_title,job_description,cpf,job_id)
   VALUES(p_company_id,btrim(p_name),btrim(p_employee_number),normalized_title,btrim(coalesce(p_job_description,'')),coalesce(p_cpf,''),job.id) RETURNING * INTO person;
 ELSE
  UPDATE public.ppl_employees SET name=btrim(p_name),employee_number=btrim(p_employee_number),job_title=normalized_title,
   job_description=btrim(coalesce(p_job_description,'')),cpf=coalesce(p_cpf,''),job_id=job.id
   WHERE id=p_employee_id AND company_id=p_company_id RETURNING * INTO person;
 END IF;
 RETURN to_jsonb(person);
END;
$save$;
-- Match a whole registered identity, never a mixture of fields from different revisions.
CREATE OR REPLACE FUNCTION public.ppl_employee_snapshot_matches_v48(c uuid,e uuid,n text,m text,j text DEFAULT NULL)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $match$
 SELECT EXISTS(SELECT 1 FROM public.ppl_employees WHERE company_id=c AND id=e AND name=n AND (m IS NULL OR employee_number=m) AND (j IS NULL OR job_title=j))
 OR EXISTS(SELECT 1 FROM public.ppl_employee_history WHERE company_id=c AND employee_id=e AND name=n AND (m IS NULL OR employee_number=m) AND (j IS NULL OR job_title=j));
$match$;
ALTER TABLE public.ppl_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ppl_employee_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ppl_jobs,public.ppl_employee_history FROM public,anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.ppl_jobs TO service_role;
GRANT SELECT,INSERT ON public.ppl_employee_history TO service_role;
REVOKE ALL ON FUNCTION public.ppl_employee_history_v48(),public.ppl_preserve_employee_history_v48(),public.ppl_employee_save_v48(uuid,uuid,text,text,text,text,text,uuid,boolean,timestamptz,uuid),public.ppl_employee_snapshot_matches_v48(uuid,uuid,text,text,text) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ppl_employee_save_v48(uuid,uuid,text,text,text,text,text,uuid,boolean,timestamptz,uuid),public.ppl_employee_snapshot_matches_v48(uuid,uuid,text,text,text) TO service_role;
COMMIT;
