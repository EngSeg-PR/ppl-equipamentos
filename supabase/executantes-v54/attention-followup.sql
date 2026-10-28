-- Sistema Apto: acompanhamento administrativo separado da avaliação imutável.
-- Aplicar depois de triagem-v51. Incremental e repetível; não altera avaliações.
BEGIN;
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
