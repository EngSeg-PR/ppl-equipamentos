BEGIN;
-- Incremental. Não altera inspeções, modelos, logins de gestão ou avaliações APTO.
ALTER TABLE public.ppl_companies ADD COLUMN IF NOT EXISTS executor_access_required boolean NOT NULL DEFAULT false;
ALTER TABLE public.ppl_employees ADD COLUMN IF NOT EXISTS executor_auth_version bigint NOT NULL DEFAULT 1;
CREATE UNIQUE INDEX IF NOT EXISTS ppl_employees_company_identity_v54 ON public.ppl_employees(company_id,id);

CREATE TABLE IF NOT EXISTS public.ppl_executor_sessions (
 token_hash text PRIMARY KEY CHECK(token_hash ~ '^[a-f0-9]{64}$'),
 company_id uuid NOT NULL REFERENCES public.ppl_companies(id),
 employee_id uuid NOT NULL,
 auth_version bigint NOT NULL,
 issued_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 expires_at timestamptz NOT NULL,
 revoked_at timestamptz,
 FOREIGN KEY(company_id,employee_id) REFERENCES public.ppl_employees(company_id,id),
 CHECK(expires_at>issued_at)
);
CREATE INDEX IF NOT EXISTS ppl_executor_employee_sessions_v54 ON public.ppl_executor_sessions(company_id,employee_id,expires_at);
CREATE TABLE IF NOT EXISTS public.ppl_executor_attempts (
 company_id uuid NOT NULL REFERENCES public.ppl_companies(id),
 bucket text NOT NULL CHECK(bucket='company' OR bucket ~ '^[a-f0-9-]{36}$'),
 window_start timestamptz NOT NULL,
 attempts integer NOT NULL CHECK(attempts>0),
 PRIMARY KEY(company_id,bucket)
);
CREATE TABLE IF NOT EXISTS public.ppl_executor_config_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 company_id uuid NOT NULL REFERENCES public.ppl_companies(id),
 required boolean NOT NULL,
 changed_by uuid NOT NULL,
 changed_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE OR REPLACE FUNCTION public.ppl_executor_employee_changed_v54() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $revoke$
BEGIN
 IF NEW.id IS DISTINCT FROM OLD.id OR NEW.company_id IS DISTINCT FROM OLD.company_id
 THEN RAISE EXCEPTION 'executor_identity_immutable' USING ERRCODE='42501'; END IF;
 IF NEW.employee_number IS DISTINCT FROM OLD.employee_number OR NEW.active IS DISTINCT FROM OLD.active THEN
  NEW.executor_auth_version:=OLD.executor_auth_version+1;
  UPDATE public.ppl_executor_sessions SET revoked_at=clock_timestamp()
   WHERE company_id=OLD.company_id AND employee_id=OLD.id AND revoked_at IS NULL;
 ELSE NEW.executor_auth_version:=OLD.executor_auth_version;
 END IF;
 RETURN NEW;
END;
$revoke$;
CREATE OR REPLACE TRIGGER ppl_executor_employee_changed_v54 BEFORE UPDATE ON public.ppl_employees
 FOR EACH ROW EXECUTE FUNCTION public.ppl_executor_employee_changed_v54();

-- Duas cotas persistentes. IDs inexistentes consomem somente a cota da empresa;
-- isso evita criar uma linha nova para cada identificador arbitrário recebido.
CREATE OR REPLACE FUNCTION public.ppl_executor_reserve_attempt_v54(c uuid,e uuid)
 RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $limit$
DECLARE stamp timestamptz:=clock_timestamp(); global_count integer; person_count integer;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ppl_companies WHERE id=c AND status='ready')
 THEN RAISE EXCEPTION 'executor_company_unavailable' USING ERRCODE='P5404'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(c::text,54));
 INSERT INTO public.ppl_executor_attempts(company_id,bucket,window_start,attempts)
 VALUES(c,'company',stamp,1)
 ON CONFLICT(company_id,bucket) DO UPDATE SET
  attempts=CASE WHEN public.ppl_executor_attempts.window_start<=stamp-interval '15 minutes' THEN 1 ELSE public.ppl_executor_attempts.attempts+1 END,
  window_start=CASE WHEN public.ppl_executor_attempts.window_start<=stamp-interval '15 minutes' THEN stamp ELSE public.ppl_executor_attempts.window_start END
 RETURNING attempts INTO global_count;
 IF global_count>120 THEN RETURN false; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ppl_employees WHERE company_id=c AND id=e) THEN RETURN true; END IF;
 INSERT INTO public.ppl_executor_attempts(company_id,bucket,window_start,attempts)
 VALUES(c,e::text,stamp,1)
 ON CONFLICT(company_id,bucket) DO UPDATE SET
  attempts=CASE WHEN public.ppl_executor_attempts.window_start<=stamp-interval '15 minutes' THEN 1 ELSE public.ppl_executor_attempts.attempts+1 END,
  window_start=CASE WHEN public.ppl_executor_attempts.window_start<=stamp-interval '15 minutes' THEN stamp ELSE public.ppl_executor_attempts.window_start END
 RETURNING attempts INTO person_count;
 RETURN person_count<=8;
END;
$limit$;

CREATE OR REPLACE FUNCTION public.ppl_executor_issue_v54(c uuid,e uuid,v bigint,h text)
 RETURNS timestamptz LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $issue$
DECLARE person public.ppl_employees; stamp timestamptz:=clock_timestamp(); expiry timestamptz;
BEGIN
 SELECT * INTO person FROM public.ppl_employees WHERE company_id=c AND id=e FOR UPDATE;
 IF NOT FOUND OR NOT person.active OR person.executor_auth_version<>v
 OR NOT EXISTS(SELECT 1 FROM public.ppl_companies WHERE id=c AND status='ready')
 THEN RAISE EXCEPTION 'executor_credentials_changed' USING ERRCODE='P5401'; END IF;
 IF h IS NULL OR h !~ '^[a-f0-9]{64}$' THEN RAISE EXCEPTION 'executor_token_invalid' USING ERRCODE='22023'; END IF;
 expiry:=stamp+interval '12 hours';
 -- Somente sessões expiradas/revogadas são limpas; não contém evidências.
 DELETE FROM public.ppl_executor_sessions WHERE company_id=c AND employee_id=e
 AND (expires_at<stamp-interval '7 days' OR revoked_at<stamp-interval '7 days');
 INSERT INTO public.ppl_executor_sessions(token_hash,company_id,employee_id,auth_version,issued_at,expires_at)
 VALUES(h,c,e,v,stamp,expiry);
 RETURN expiry;
END;
$issue$;

CREATE OR REPLACE FUNCTION public.ppl_executor_session_v54(c uuid,h text)
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $session$
 SELECT jsonb_build_object('expiresAt',s.expires_at,'employee',jsonb_build_object(
  'id',e.id,'name',e.name,'employee_number',e.employee_number,'job_title',e.job_title,'job_description',coalesce(e.job_description,'')))
 FROM public.ppl_executor_sessions s
 JOIN public.ppl_employees e ON e.company_id=s.company_id AND e.id=s.employee_id
 JOIN public.ppl_companies company ON company.id=s.company_id
 WHERE s.company_id=c AND s.token_hash=h AND s.revoked_at IS NULL AND s.expires_at>now()
 AND e.active AND e.executor_auth_version=s.auth_version AND company.status='ready';
$session$;
CREATE OR REPLACE FUNCTION public.ppl_executor_logout_v54(c uuid,h text)
 RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $logout$
 UPDATE public.ppl_executor_sessions SET revoked_at=coalesce(revoked_at,clock_timestamp()) WHERE company_id=c AND token_hash=h;
$logout$;
CREATE OR REPLACE FUNCTION public.ppl_executor_set_required_v54(c uuid,a uuid,r boolean)
 RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $config$
BEGIN
 IF r IS NULL OR NOT EXISTS(SELECT 1 FROM public.ppl_access WHERE user_id=a AND active AND role='owner')
 THEN RAISE EXCEPTION 'executor_owner_required' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.ppl_companies WHERE id=c FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'executor_company_unavailable' USING ERRCODE='P5404'; END IF;
 UPDATE public.ppl_companies SET executor_access_required=r WHERE id=c;
 INSERT INTO public.ppl_executor_config_audit(company_id,required,changed_by) VALUES(c,r,a);
 RETURN r;
END;
$config$;

ALTER TABLE public.ppl_executor_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ppl_executor_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ppl_executor_config_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ppl_executor_sessions,public.ppl_executor_attempts,public.ppl_executor_config_audit FROM public,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.ppl_executor_employee_changed_v54(),
 public.ppl_executor_reserve_attempt_v54(uuid,uuid),public.ppl_executor_issue_v54(uuid,uuid,bigint,text),
 public.ppl_executor_session_v54(uuid,text),public.ppl_executor_logout_v54(uuid,text),
 public.ppl_executor_set_required_v54(uuid,uuid,boolean) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ppl_executor_reserve_attempt_v54(uuid,uuid),public.ppl_executor_issue_v54(uuid,uuid,bigint,text),
 public.ppl_executor_session_v54(uuid,text),public.ppl_executor_logout_v54(uuid,text),
 public.ppl_executor_set_required_v54(uuid,uuid,boolean) TO service_role;
COMMIT;
