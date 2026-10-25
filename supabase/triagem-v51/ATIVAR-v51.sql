BEGIN;
-- Incremental: preserva inspeções, cadastros, usuários, PDFs e resultados existentes.
CREATE UNIQUE INDEX IF NOT EXISTS ppl_employees_company_identity_v51 ON public.ppl_employees(company_id,id);
CREATE TABLE IF NOT EXISTS public.ppl_attention_assessments (
 id uuid PRIMARY KEY,
 company_id uuid NOT NULL REFERENCES public.ppl_companies(id),
 employee_id uuid NOT NULL,
 employee_name text NOT NULL, employee_number text NOT NULL, job_title text NOT NULL,
 employee_snapshot jsonb NOT NULL,
 unit text NOT NULL CHECK(length(btrim(unit)) BETWEEN 1 AND 160),
 team text NOT NULL CHECK(length(btrim(team)) BETWEEN 1 AND 160),
 moment text NOT NULL CHECK(moment IN ('inicio','durante')),
 started_at timestamptz NOT NULL, finished_at timestamptz NOT NULL,
 status text NOT NULL CHECK(status IN ('completa','incompleta')),
 duration_ms integer NOT NULL CHECK(duration_ms BETWEEN 0 AND 180000),
 metrics jsonb NOT NULL, protocol_version text NOT NULL, app_version text NOT NULL,
 payload jsonb NOT NULL,
 created_by uuid NOT NULL, received_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(company_id,employee_id) REFERENCES public.ppl_employees(company_id,id),
 CHECK(finished_at>=started_at)
);
CREATE INDEX IF NOT EXISTS ppl_attention_company_time_v51 ON public.ppl_attention_assessments(company_id,started_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS ppl_attention_employee_time_v51 ON public.ppl_attention_assessments(company_id,employee_id,started_at DESC,id DESC);
ALTER TABLE public.ppl_attention_assessments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS attention_scope_v51 ON public.ppl_attention_assessments;
CREATE POLICY attention_scope_v51 ON public.ppl_attention_assessments FOR SELECT TO authenticated
 USING(public.ppl_can_read_company(company_id,unit,team));
REVOKE ALL ON public.ppl_attention_assessments FROM public,anon,authenticated,service_role;
GRANT SELECT ON public.ppl_attention_assessments TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.ppl_attention_preserve_v51() RETURNS trigger
 LANGUAGE plpgsql SET search_path='' AS $preserve$
BEGIN RAISE EXCEPTION 'attention_immutable' USING ERRCODE='42501'; END;
$preserve$;
CREATE OR REPLACE TRIGGER ppl_attention_preserve_v51 BEFORE UPDATE OR DELETE ON public.ppl_attention_assessments
 FOR EACH ROW EXECUTE FUNCTION public.ppl_attention_preserve_v51();

CREATE OR REPLACE FUNCTION public.ppl_attention_actor_allowed_v51(a uuid,c uuid,u text,t text) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $allowed$
SELECT EXISTS(SELECT 1 FROM public.ppl_access p WHERE p.user_id=a AND p.active AND
 (p.role='owner' OR (p.role='manager' AND EXISTS(
  SELECT 1 FROM public.ppl_company_access ca WHERE ca.user_id=a AND ca.company_id=c AND ca.active
  AND (ca.scope_mode='company' OR EXISTS(SELECT 1 FROM public.ppl_scopes s
   WHERE s.user_id=a AND s.company_id=c AND s.unit=u AND s.team=t))))));
$allowed$;

CREATE OR REPLACE FUNCTION public.ppl_attention_submit_v51(p_company_id uuid,p_actor uuid,p_assessment jsonb)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $submit$
DECLARE
 person public.ppl_employees; existing public.ppl_attention_assessments;
 assessment_id uuid; employee_id uuid; start_time timestamptz; end_time timestamptz;
 unit_name text; team_name text; state text; duration integer; n integer; count_correct integer:=0;
 event jsonb; x jsonb; target integer:=1; sequence integer:=0; last_time integer:=0;
 touched integer; expected integer; event_time integer; correct boolean; errors integer:=0;
 success_times integer[]:='{}'; intervals integer[]:='{}'; quartiles integer[]:='{}';
 i integer; boundary integer; previous_boundary integer; mean numeric; deviation numeric;
 total numeric:=0; squares numeric:=0; first_touch integer; metrics jsonb; normalized jsonb;
 outcome text:='ok';
BEGIN
 IF p_company_id IS NULL OR p_actor IS NULL OR jsonb_typeof(p_assessment) IS DISTINCT FROM 'object'
 OR pg_column_size(p_assessment)>262144
 OR (p_assessment-ARRAY['id','employeeId','unit','team','moment','startedAt','finishedAt','status','durationMs','grid','touches','protocolVersion','appVersion'])<>'{}'::jsonb
 THEN RAISE EXCEPTION 'attention_invalid' USING ERRCODE='22023'; END IF;
 IF jsonb_typeof(p_assessment->'id') IS DISTINCT FROM 'string' OR jsonb_typeof(p_assessment->'employeeId') IS DISTINCT FROM 'string'
 OR jsonb_typeof(p_assessment->'unit') IS DISTINCT FROM 'string' OR jsonb_typeof(p_assessment->'team') IS DISTINCT FROM 'string'
 OR jsonb_typeof(p_assessment->'startedAt') IS DISTINCT FROM 'string' OR jsonb_typeof(p_assessment->'finishedAt') IS DISTINCT FROM 'string'
 OR jsonb_typeof(p_assessment->'appVersion') IS DISTINCT FROM 'string'
 THEN RAISE EXCEPTION 'attention_invalid' USING ERRCODE='22023'; END IF;
 assessment_id:=(p_assessment->>'id')::uuid; employee_id:=(p_assessment->>'employeeId')::uuid;
 unit_name:=btrim(p_assessment->>'unit'); team_name:=btrim(p_assessment->>'team');
 IF length(unit_name) NOT BETWEEN 1 AND 160 OR length(team_name) NOT BETWEEN 1 AND 160
 OR coalesce(p_assessment->>'moment','') NOT IN ('inicio','durante')
 OR coalesce(p_assessment->>'protocolVersion','')<>'sequencia-v1'
 OR length(btrim(p_assessment->>'appVersion')) NOT BETWEEN 1 AND 40
 OR jsonb_typeof(p_assessment->'durationMs') IS DISTINCT FROM 'number'
 OR (p_assessment->>'durationMs') !~ '^[0-9]+$'
 THEN RAISE EXCEPTION 'attention_invalid' USING ERRCODE='22023'; END IF;
 IF NOT public.ppl_attention_actor_allowed_v51(p_actor,p_company_id,unit_name,team_name)
 THEN RAISE EXCEPTION 'attention_scope_denied' USING ERRCODE='42501'; END IF;
 duration:=(p_assessment->>'durationMs')::integer; state:=p_assessment->>'status';
 start_time:=(p_assessment->>'startedAt')::timestamptz; end_time:=(p_assessment->>'finishedAt')::timestamptz;
 IF NOT isfinite(start_time) OR NOT isfinite(end_time) OR end_time<start_time
 OR (p_assessment->>'startedAt') !~ '^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:\d{2})$'
 OR (p_assessment->>'finishedAt') !~ '^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:\d{2})$'
 OR duration NOT BETWEEN 0 AND 180000 OR coalesce(state,'') NOT IN ('completa','incompleta')
 OR jsonb_typeof(p_assessment->'grid') IS DISTINCT FROM 'array'
 OR jsonb_typeof(p_assessment->'touches') IS DISTINCT FROM 'array'
 THEN RAISE EXCEPTION 'attention_invalid' USING ERRCODE='22023'; END IF;
 n:=jsonb_array_length(p_assessment->'grid');
 IF n NOT BETWEEN 4 AND 99 OR jsonb_array_length(p_assessment->'touches')>2000
 THEN RAISE EXCEPTION 'attention_invalid' USING ERRCODE='22023'; END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(p_assessment->'grid') LOOP
  IF jsonb_typeof(x)<>'number' OR (x#>>'{}') !~ '^[0-9]+$' OR (x#>>'{}')::integer NOT BETWEEN 1 AND n
  THEN RAISE EXCEPTION 'attention_grid_invalid' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF (SELECT count(DISTINCT value) FROM jsonb_array_elements(p_assessment->'grid'))<>n
 THEN RAISE EXCEPTION 'attention_grid_invalid' USING ERRCODE='22023'; END IF;
 FOR event IN SELECT value FROM jsonb_array_elements(p_assessment->'touches') LOOP
  IF jsonb_typeof(event) IS DISTINCT FROM 'object'
  OR (event-ARRAY['seq','tMs','touched','expected','correct'])<>'{}'::jsonb
  OR jsonb_typeof(event->'correct') IS DISTINCT FROM 'boolean'
  THEN RAISE EXCEPTION 'attention_event_invalid' USING ERRCODE='22023'; END IF;
  FOREACH unit_name IN ARRAY ARRAY['seq','tMs','touched','expected'] LOOP
   IF jsonb_typeof(event->unit_name) IS DISTINCT FROM 'number' OR (event->>unit_name) !~ '^[0-9]+$'
   THEN RAISE EXCEPTION 'attention_event_invalid' USING ERRCODE='22023'; END IF;
  END LOOP;
  sequence:=sequence+1; event_time:=(event->>'tMs')::integer;
  touched:=(event->>'touched')::integer; expected:=(event->>'expected')::integer; correct:=(event->>'correct')::boolean;
  IF (event->>'seq')::integer<>sequence OR target>n OR expected<>target OR touched NOT BETWEEN 1 AND n
  OR correct IS DISTINCT FROM (touched=target) OR event_time<last_time OR event_time>duration OR event_time>=180000
  THEN RAISE EXCEPTION 'attention_event_invalid' USING ERRCODE='22023'; END IF;
  IF first_touch IS NULL THEN first_touch:=event_time; END IF;
  last_time:=event_time;
  IF correct THEN
   success_times:=array_append(success_times,event_time); target:=target+1; count_correct:=count_correct+1;
  ELSE errors:=errors+1; END IF;
 END LOOP;
 unit_name:=btrim(p_assessment->>'unit');
 IF (state='completa') IS DISTINCT FROM (count_correct=n)
 OR (state='completa' AND duration<>last_time)
 THEN RAISE EXCEPTION 'attention_status_invalid' USING ERRCODE='22023'; END IF;
 IF count_correct>1 THEN
  FOR i IN 2..count_correct LOOP
   intervals:=array_append(intervals,success_times[i]-success_times[i-1]);
   total:=total+(success_times[i]-success_times[i-1]);
  END LOOP;
  mean:=total/(count_correct-1);
  FOREACH i IN ARRAY intervals LOOP squares:=squares+(i-mean)*(i-mean); END LOOP;
  deviation:=sqrt(squares/(count_correct-1));
 END IF;
 FOR i IN 1..4 LOOP
  boundary:=ceil(i*n/4.0); previous_boundary:=ceil((i-1)*n/4.0);
  quartiles:=array_append(quartiles,CASE WHEN boundary<=count_correct THEN success_times[boundary]-CASE WHEN previous_boundary=0 THEN 0 ELSE success_times[previous_boundary] END ELSE NULL END);
 END LOOP;
 metrics:=jsonb_build_object('tempo_total_ms',duration,'tempo_primeiro_toque_ms',first_touch,'erros',errors,
  'media_intervalo_ms',mean,'dp_intervalo_ms',deviation,'quartis_ms',to_jsonb(quartiles),'acertos',count_correct,'total_alvos',n);
 normalized:=jsonb_build_object('id',assessment_id,'employeeId',employee_id,'unit',unit_name,'team',team_name,
  'moment',p_assessment->>'moment','startedAt',to_char(start_time AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'finishedAt',to_char(end_time AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'status',state,'durationMs',duration,'grid',p_assessment->'grid','touches',p_assessment->'touches',
  'protocolVersion','sequencia-v1','appVersion',btrim(p_assessment->>'appVersion'));
 -- A repetição usa conteúdo completo, sem depender apenas de um hash.
 SELECT * INTO existing FROM public.ppl_attention_assessments WHERE id=assessment_id;
 IF FOUND THEN
  IF existing.company_id<>p_company_id OR existing.payload<>normalized
  THEN RAISE EXCEPTION 'attention_id_conflict' USING ERRCODE='P5109'; END IF;
  RETURN jsonb_build_object('status','duplicada','id',existing.id,'received_at',existing.received_at,'assessment',to_jsonb(existing)-'payload');
 END IF;
 SELECT * INTO person FROM public.ppl_employees WHERE id=employee_id AND company_id=p_company_id AND active FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'attention_employee_not_found' USING ERRCODE='P5104'; END IF;
 INSERT INTO public.ppl_attention_assessments(id,company_id,employee_id,employee_name,employee_number,job_title,employee_snapshot,
  unit,team,moment,started_at,finished_at,status,duration_ms,metrics,protocol_version,app_version,payload,created_by)
 VALUES(assessment_id,p_company_id,employee_id,person.name,person.employee_number,person.job_title,
  jsonb_build_object('id',person.id,'name',person.name,'employee_number',person.employee_number,'job_title',person.job_title),
  unit_name,team_name,p_assessment->>'moment',start_time,end_time,state,duration,metrics,'sequencia-v1',btrim(p_assessment->>'appVersion'),normalized,p_actor)
 ON CONFLICT(id) DO NOTHING;
 IF NOT FOUND THEN outcome:='duplicada'; END IF;
 SELECT * INTO existing FROM public.ppl_attention_assessments WHERE id=assessment_id;
 IF existing.company_id<>p_company_id OR existing.payload<>normalized
 THEN RAISE EXCEPTION 'attention_id_conflict' USING ERRCODE='P5109'; END IF;
 RETURN jsonb_build_object('status',outcome,'id',existing.id,'received_at',existing.received_at,'assessment',to_jsonb(existing)-'payload');
END;
$submit$;
REVOKE ALL ON FUNCTION public.ppl_attention_preserve_v51(),public.ppl_attention_actor_allowed_v51(uuid,uuid,text,text),public.ppl_attention_submit_v51(uuid,uuid,jsonb) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ppl_attention_submit_v51(uuid,uuid,jsonb) TO service_role;
COMMIT;
