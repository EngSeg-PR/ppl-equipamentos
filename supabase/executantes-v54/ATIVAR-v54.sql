-- Atualização incremental54: executantes e acompanhamento Sistema Apto.
-- Mantém inspeções, PDFs, modelos, usuários e avaliações existentes.
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


-- Sistema Apto: acompanhamento administrativo separado da avaliação imutável.
-- Aplicar depois de triagem-v51. Incremental e repetível; não altera avaliações.
CREATE UNIQUE INDEX IF NOT EXISTS ppl_attention_company_id_v54 ON public.ppl_attention_assessments(company_id,id);
CREATE TABLE IF NOT EXISTS public.ppl_attention_followup_events_v54 (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 company_id uuid NOT NULL,
 assessment_id uuid NOT NULL,
 revision integer NOT NULL CHECK(revision>0),
 status text NOT NULL CHECK(status IN ('aberta','em_andamento','concluida')),
 note text NOT NULL CHECK(length(btrim(note)) BETWEEN 1 AND 4000),
 actor_id uuid NOT NULL,
 actor_name text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(company_id,assessment_id) REFERENCES public.ppl_attention_assessments(company_id,id),
 UNIQUE(assessment_id,revision)
);
CREATE INDEX IF NOT EXISTS ppl_attention_followup_latest_v54 ON public.ppl_attention_followup_events_v54(company_id,assessment_id,revision DESC);
ALTER TABLE public.ppl_attention_followup_events_v54 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS attention_followup_scope_v54 ON public.ppl_attention_followup_events_v54;
CREATE POLICY attention_followup_scope_v54 ON public.ppl_attention_followup_events_v54 FOR SELECT TO authenticated
 USING(EXISTS(SELECT 1 FROM public.ppl_attention_assessments a WHERE a.id=assessment_id AND a.company_id=ppl_attention_followup_events_v54.company_id AND public.ppl_can_read_company(a.company_id,a.unit,a.team)));
REVOKE ALL ON public.ppl_attention_followup_events_v54 FROM public,anon,authenticated,service_role;
GRANT SELECT ON public.ppl_attention_followup_events_v54 TO authenticated,service_role;
CREATE OR REPLACE TRIGGER ppl_attention_followup_preserve_v54 BEFORE UPDATE OR DELETE ON public.ppl_attention_followup_events_v54
 FOR EACH ROW EXECUTE FUNCTION public.ppl_attention_preserve_v51();

CREATE OR REPLACE FUNCTION public.ppl_attention_dashboard_rows_v54(
 p_company uuid,p_employee uuid DEFAULT NULL,p_number text DEFAULT '',p_from date DEFAULT NULL,p_to date DEFAULT NULL,p_status text DEFAULT '',p_followup text DEFAULT '')
 RETURNS TABLE(id uuid,company_id uuid,employee_id uuid,employee_name text,employee_number text,job_title text,unit text,team text,moment text,started_at timestamptz,finished_at timestamptz,status text,duration_ms integer,metrics jsonb,protocol_version text,app_version text,received_at timestamptz,followup_status text,followup_revision integer)
 LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $rows$
 SELECT a.id,a.company_id,a.employee_id,a.employee_name,a.employee_number,a.job_title,a.unit,a.team,a.moment,a.started_at,a.finished_at,a.status,a.duration_ms,a.metrics,a.protocol_version,a.app_version,a.received_at,coalesce(f.status,'sem_acompanhamento'),coalesce(f.revision,0)
 FROM public.ppl_attention_assessments a
 LEFT JOIN LATERAL(SELECT e.status,e.revision FROM public.ppl_attention_followup_events_v54 e WHERE e.company_id=a.company_id AND e.assessment_id=a.id ORDER BY e.revision DESC LIMIT 1)f ON true
 WHERE a.company_id=p_company AND (p_employee IS NULL OR a.employee_id=p_employee)
 AND (p_number='' OR a.employee_number=p_number)
 AND (p_from IS NULL OR a.started_at>=p_from::timestamp AT TIME ZONE 'America/Fortaleza')
 AND (p_to IS NULL OR a.started_at<(p_to+1)::timestamp AT TIME ZONE 'America/Fortaleza')
 AND (p_status='' OR a.status=p_status)
 AND (p_followup='' OR coalesce(f.status,'sem_acompanhamento')=p_followup);
$rows$;

CREATE OR REPLACE FUNCTION public.ppl_attention_dashboard_v54(
 p_company uuid,p_employee uuid DEFAULT NULL,p_number text DEFAULT '',p_from date DEFAULT NULL,p_to date DEFAULT NULL,p_status text DEFAULT '',p_followup text DEFAULT '',p_offset integer DEFAULT 0,p_limit integer DEFAULT 50)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $dashboard$
DECLARE result jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'attention_login' USING ERRCODE='42501'; END IF;
 IF p_company IS NULL OR p_offset IS NULL OR p_offset<0 OR p_offset>1000000 OR p_limit IS NULL OR p_limit<1 OR p_limit>100
 OR p_status IS NULL OR p_status NOT IN ('','completa','incompleta') OR p_followup IS NULL OR p_followup NOT IN ('','sem_acompanhamento','aberta','em_andamento','concluida')
 OR p_number IS NULL OR length(p_number)>160 OR (p_from IS NOT NULL AND p_to IS NOT NULL AND p_from>p_to)
 THEN RAISE EXCEPTION 'attention_filter' USING ERRCODE='22023'; END IF;
 WITH filtered AS MATERIALIZED(SELECT * FROM public.ppl_attention_dashboard_rows_v54(p_company,p_employee,p_number,p_from,p_to,p_status,p_followup)),
 page AS(SELECT * FROM filtered ORDER BY started_at DESC,id DESC OFFSET p_offset LIMIT p_limit),
 totals AS(SELECT count(*) total,count(*)FILTER(WHERE status='completa') complete,count(*)FILTER(WHERE status='incompleta') incomplete,count(DISTINCT employee_id) people,
 count(*)FILTER(WHERE followup_status='sem_acompanhamento') untracked,count(*)FILTER(WHERE followup_status='aberta') open,count(*)FILTER(WHERE followup_status='em_andamento') in_progress,count(*)FILTER(WHERE followup_status='concluida') concluded FROM filtered)
 SELECT jsonb_build_object('rows',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.started_at DESC,p.id DESC)FROM page p),'[]'::jsonb),
 'nextOffset',CASE WHEN t.total>p_offset+p_limit THEN p_offset+p_limit ELSE NULL END,
 'summary',jsonb_build_object('total',t.total,'complete',t.complete,'incomplete',t.incomplete,'people',t.people,'untracked',t.untracked,'open',t.open,'inProgress',t.in_progress,'concluded',t.concluded))INTO result FROM totals t;
 RETURN result;
END;
$dashboard$;

CREATE OR REPLACE FUNCTION public.ppl_attention_followup_detail_v54(p_company uuid,p_id uuid)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $detail$
DECLARE events jsonb; current_event jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'attention_login' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ppl_attention_assessments a WHERE a.company_id=p_company AND a.id=p_id)THEN RAISE EXCEPTION 'attention_missing' USING ERRCODE='P5404'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY e.revision DESC),'[]'::jsonb) INTO events FROM public.ppl_attention_followup_events_v54 e WHERE e.company_id=p_company AND e.assessment_id=p_id;
 current_event:=events->0;
 RETURN jsonb_build_object('current',current_event,'events',events);
END;
$detail$;

CREATE OR REPLACE FUNCTION public.ppl_attention_followup_save_v54(p_company uuid,p_id uuid,p_status text,p_note text,p_expected integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $save$
DECLARE a public.ppl_attention_assessments; current_revision integer; actor_name text; events jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'attention_login' USING ERRCODE='42501'; END IF;
 SELECT x.* INTO a FROM public.ppl_attention_assessments x WHERE x.company_id=p_company AND x.id=p_id;
 IF NOT FOUND OR NOT public.ppl_attention_actor_allowed_v51(auth.uid(),a.company_id,a.unit,a.team)THEN RAISE EXCEPTION 'attention_missing' USING ERRCODE='P5404'; END IF;
 IF p_expected IS NULL OR p_expected<0 OR p_status IS NULL OR p_status NOT IN ('aberta','em_andamento','concluida') OR p_note IS NULL OR length(btrim(p_note))NOT BETWEEN 1 AND 4000
 THEN RAISE EXCEPTION 'attention_followup_invalid' USING ERRCODE='22023'; END IF;
 -- Serializa revisões concorrentes sem bloquear nem alterar a avaliação.
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('attention-followup:'||p_id::text,0));
 SELECT coalesce(max(e.revision),0)INTO current_revision FROM public.ppl_attention_followup_events_v54 e WHERE e.company_id=p_company AND e.assessment_id=p_id;
 IF current_revision<>p_expected THEN RAISE EXCEPTION 'attention_followup_conflict' USING ERRCODE='P5409'; END IF;
 SELECT p.name INTO actor_name FROM public.ppl_access p WHERE p.user_id=auth.uid() AND p.active;
 INSERT INTO public.ppl_attention_followup_events_v54(company_id,assessment_id,revision,status,note,actor_id,actor_name)
 VALUES(p_company,p_id,current_revision+1,p_status,btrim(p_note),auth.uid(),coalesce(actor_name,'Gestor autorizado'));
 SELECT jsonb_agg(to_jsonb(e) ORDER BY e.revision DESC)INTO events FROM public.ppl_attention_followup_events_v54 e WHERE e.company_id=p_company AND e.assessment_id=p_id;
 RETURN jsonb_build_object('current',events->0,'events',events);
END;
$save$;
REVOKE ALL ON FUNCTION public.ppl_attention_dashboard_rows_v54(uuid,uuid,text,date,date,text,text),public.ppl_attention_dashboard_v54(uuid,uuid,text,date,date,text,text,integer,integer),public.ppl_attention_followup_detail_v54(uuid,uuid),public.ppl_attention_followup_save_v54(uuid,uuid,text,text,integer)FROM public,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.ppl_attention_dashboard_rows_v54(uuid,uuid,text,date,date,text,text),public.ppl_attention_dashboard_v54(uuid,uuid,text,date,date,text,text,integer,integer),public.ppl_attention_followup_detail_v54(uuid,uuid),public.ppl_attention_followup_save_v54(uuid,uuid,text,text,integer)TO authenticated;

COMMIT;
