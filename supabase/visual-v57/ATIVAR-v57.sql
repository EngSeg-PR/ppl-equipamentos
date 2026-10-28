BEGIN;
-- Adiciona somente um validador privado. Tabelas, RLS e protocolos anteriores permanecem.
CREATE OR REPLACE FUNCTION public.ppl_attention_visual_submit_v57(p_company_id uuid,p_actor uuid,p_personal boolean,p_assessment jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $visual$
DECLARE
 person public.ppl_employees; existing public.ppl_attention_assessments;
 aid uuid; eid uuid; u text; t text; state text; started timestamptz; finished timestamptz;
 duration integer; e jsonb; s jsonb; x jsonb; k text; i integer:=0; j integer;
 shown integer; shown_us bigint; closed integer; previous_closed integer:=0; due integer; last_event integer:=0; last_us bigint:=0; response_us bigint;
 ng integer:=0; n integer; count_closed integer:=0; hit_count integer; rt numeric;
 valid integer:=0; omissions integer:=0; commissions integer:=0; inside integer:=0; extras integer:=0; lag integer:=0;
 times numeric[]:='{}'; blocks integer[]:='{}'; quarters jsonb:='[]'; metrics jsonb; normalized jsonb;
 mean_ms numeric; median_ms numeric; deviation numeric; p10 numeric; p90 numeric; block_mean numeric;
 anticipation integer:=0; lapses integer:=0; fast_mean numeric; slow_mean numeric; decile integer;
 outcome text:='ok';
BEGIN
 IF p_company_id IS NULL OR p_actor IS NULL OR p_personal IS NULL
 OR jsonb_typeof(p_assessment) IS DISTINCT FROM 'object' OR pg_column_size(p_assessment)>262144
 OR (p_assessment-ARRAY['id','employeeId','unit','team','moment','startedAt','finishedAt','status','durationMs','schedule','trials','responses','interruption','technical','protocolVersion','appVersion'])<>'{}'::jsonb
 THEN RAISE EXCEPTION 'attention_invalid' USING ERRCODE='22023'; END IF;
 FOREACH k IN ARRAY ARRAY['id','employeeId','unit','team','moment','startedAt','finishedAt','status','protocolVersion','appVersion'] LOOP
  IF jsonb_typeof(p_assessment->k) IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'attention_invalid' USING ERRCODE='22023'; END IF;
 END LOOP;
 aid:=(p_assessment->>'id')::uuid; eid:=(p_assessment->>'employeeId')::uuid;
 u:=btrim(p_assessment->>'unit'); t:=btrim(p_assessment->>'team'); state:=p_assessment->>'status';
 IF length(u) NOT BETWEEN 1 AND 160 OR length(t) NOT BETWEEN 1 AND 160
 OR p_assessment->>'protocolVersion'<>'visual-v1' OR length(btrim(p_assessment->>'appVersion')) NOT BETWEEN 1 AND 40
 OR p_assessment->>'moment' NOT IN ('inicio','durante') OR state NOT IN ('completa','incompleta')
 OR jsonb_typeof(p_assessment->'durationMs') IS DISTINCT FROM 'number' OR (p_assessment->>'durationMs') !~ '^[0-9]+$'
 THEN RAISE EXCEPTION 'attention_invalid' USING ERRCODE='22023'; END IF;
 IF p_personal THEN
  IF eid<>p_actor OR NOT EXISTS(SELECT 1 FROM public.ppl_employees e JOIN public.ppl_companies c ON c.id=e.company_id
   WHERE e.id=eid AND e.company_id=p_company_id AND e.active AND c.status='ready')
  THEN RAISE EXCEPTION 'attention_scope_denied' USING ERRCODE='42501'; END IF;
 ELSIF NOT public.ppl_attention_actor_allowed_v51(p_actor,p_company_id,u,t) THEN
  RAISE EXCEPTION 'attention_scope_denied' USING ERRCODE='42501';
 END IF;
 duration:=(p_assessment->>'durationMs')::integer;
 started:=(p_assessment->>'startedAt')::timestamptz; finished:=(p_assessment->>'finishedAt')::timestamptz;
 IF duration NOT BETWEEN 0 AND 90000 OR NOT isfinite(started) OR NOT isfinite(finished) OR finished<started
 OR (p_assessment->>'startedAt') !~ '^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:\d{2})$'
 OR (p_assessment->>'finishedAt') !~ '^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:\d{2})$'
 OR abs(extract(epoch FROM finished-started)*1000-duration)>2
 OR jsonb_typeof(p_assessment->'schedule') IS DISTINCT FROM 'array'
 OR jsonb_typeof(p_assessment->'trials') IS DISTINCT FROM 'array'
 OR jsonb_typeof(p_assessment->'responses') IS DISTINCT FROM 'array'
 OR jsonb_typeof(p_assessment->'technical') IS DISTINCT FROM 'object'
 OR ((p_assessment->'technical')-ARRAY['runtime','width','height','pixelRatio','multitouch','deviceModel','refreshRateHz'])<>'{}'::jsonb
 OR NOT(p_assessment?'interruption')
 OR jsonb_typeof(p_assessment->'interruption') NOT IN ('string','null')
 OR length(coalesce(p_assessment->>'interruption',''))>200
 THEN RAISE EXCEPTION 'attention_invalid' USING ERRCODE='22023'; END IF;
 -- Somente características disponíveis da interface, sem sensores ou identificação adicional.
 IF (p_assessment->'technical')<>'{}'::jsonb THEN
  IF p_assessment#>'{technical,multitouch}' IS NOT NULL AND jsonb_typeof(p_assessment#>'{technical,multitouch}')<>'boolean'
  THEN RAISE EXCEPTION 'attention_environment_invalid' USING ERRCODE='22023'; END IF;
  IF p_assessment#>'{technical,deviceModel}' IS NOT NULL AND (jsonb_typeof(p_assessment#>'{technical,deviceModel}')<>'string' OR length(p_assessment#>>'{technical,deviceModel}')>160)
  THEN RAISE EXCEPTION 'attention_environment_invalid' USING ERRCODE='22023'; END IF;
  IF p_assessment#>'{technical,refreshRateHz}' IS NOT NULL AND p_assessment#>'{technical,refreshRateHz}'<>'null'::jsonb
   AND (jsonb_typeof(p_assessment#>'{technical,refreshRateHz}')<>'number' OR (p_assessment#>>'{technical,refreshRateHz}')::numeric NOT BETWEEN 1 AND 1000)
  THEN RAISE EXCEPTION 'attention_environment_invalid' USING ERRCODE='22023'; END IF;
  IF coalesce(p_assessment#>>'{technical,runtime}','') NOT IN ('web','android','iOS','linux','macOS','windows','fuchsia')
  THEN RAISE EXCEPTION 'attention_environment_invalid' USING ERRCODE='22023'; END IF;
  FOREACH k IN ARRAY ARRAY['width','height','pixelRatio'] LOOP
   IF jsonb_typeof(p_assessment#>ARRAY['technical',k]) IS DISTINCT FROM 'number'
   OR (p_assessment#>>ARRAY['technical',k])::numeric NOT BETWEEN 0.1 AND 100000
   THEN RAISE EXCEPTION 'attention_environment_invalid' USING ERRCODE='22023'; END IF;
  END LOOP;
 END IF;
 IF jsonb_array_length(p_assessment->'schedule')<>30 OR jsonb_array_length(p_assessment->'trials')>30
 OR jsonb_array_length(p_assessment->'responses')>500
 THEN RAISE EXCEPTION 'attention_plan_invalid' USING ERRCODE='22023'; END IF;
 FOR s IN SELECT value FROM jsonb_array_elements(p_assessment->'schedule') LOOP
  IF jsonb_typeof(s) IS DISTINCT FROM 'object' OR (s-ARRAY['kind','waitMs','position'])<>'{}'::jsonb
  OR coalesce(s->>'kind','') NOT IN ('go','nogo') OR jsonb_typeof(s->'waitMs') IS DISTINCT FROM 'number'
  OR (s->>'waitMs') !~ '^[0-9]+$' OR (s->>'waitMs')::integer NOT BETWEEN 800 AND 1600
  THEN RAISE EXCEPTION 'attention_plan_invalid' USING ERRCODE='22023'; END IF;
  IF jsonb_typeof(s->'position') IS DISTINCT FROM 'number' OR (s->>'position') !~ '^[0-9]+$' OR (s->>'position')::integer NOT BETWEEN 0 AND 2
  THEN RAISE EXCEPTION 'attention_plan_invalid' USING ERRCODE='22023'; END IF;
  IF s->>'kind'='nogo' THEN ng:=ng+1; END IF;
 END LOOP;
 IF ng<>6 THEN RAISE EXCEPTION 'attention_plan_invalid' USING ERRCODE='22023'; END IF;
 FOR e IN SELECT value FROM jsonb_array_elements(p_assessment->'responses') LOOP
  i:=i+1;
  IF jsonb_typeof(e) IS DISTINCT FROM 'object' OR (e-ARRAY['seq','tMs','tUs','source'])<>'{}'::jsonb
  OR coalesce(e->>'source','') NOT IN ('pointer','keyboard')
  THEN RAISE EXCEPTION 'attention_event_invalid' USING ERRCODE='22023'; END IF;
  FOREACH k IN ARRAY ARRAY['seq','tMs'] LOOP
   IF jsonb_typeof(e->k) IS DISTINCT FROM 'number' OR (e->>k) !~ '^[0-9]+$'
   THEN RAISE EXCEPTION 'attention_event_invalid' USING ERRCODE='22023'; END IF;
  END LOOP;
  IF (e->>'seq')::integer<>i OR (e->>'tMs')::integer NOT BETWEEN last_event AND duration
  THEN RAISE EXCEPTION 'attention_event_invalid' USING ERRCODE='22023'; END IF;
  last_event:=(e->>'tMs')::integer;
  IF e?'tUs' AND (jsonb_typeof(e->'tUs') IS DISTINCT FROM 'number' OR (e->>'tUs') !~ '^[0-9]+$')
  THEN RAISE EXCEPTION 'attention_event_invalid' USING ERRCODE='22023'; END IF;
  response_us:=coalesce((e->>'tUs')::bigint,last_event::bigint*1000);
  IF response_us<last_us OR response_us/1000<>last_event THEN RAISE EXCEPTION 'attention_event_invalid' USING ERRCODE='22023'; END IF;
  last_us:=response_us;
 END LOOP;
 i:=0; n:=jsonb_array_length(p_assessment->'trials');
 FOR e IN SELECT value FROM jsonb_array_elements(p_assessment->'trials') LOOP
  i:=i+1;
  IF jsonb_typeof(e) IS DISTINCT FROM 'object' OR (e-ARRAY['seq','shownMs','shownUs','closedMs'])<>'{}'::jsonb
  OR NOT(e?'closedMs') OR jsonb_typeof(e->'closedMs') NOT IN ('number','null')
  THEN RAISE EXCEPTION 'attention_trial_invalid' USING ERRCODE='22023'; END IF;
  FOREACH k IN ARRAY ARRAY['seq','shownMs'] LOOP
   IF jsonb_typeof(e->k) IS DISTINCT FROM 'number' OR (e->>k) !~ '^[0-9]+$'
   THEN RAISE EXCEPTION 'attention_trial_invalid' USING ERRCODE='22023'; END IF;
  END LOOP;
  IF (e->>'closedMs') IS NOT NULL AND (e->>'closedMs') !~ '^[0-9]+$'
  THEN RAISE EXCEPTION 'attention_trial_invalid' USING ERRCODE='22023'; END IF;
  shown:=(e->>'shownMs')::integer; closed:=(e->>'closedMs')::integer;
  IF e?'shownUs' AND (jsonb_typeof(e->'shownUs') IS DISTINCT FROM 'number' OR (e->>'shownUs') !~ '^[0-9]+$')
  THEN RAISE EXCEPTION 'attention_trial_invalid' USING ERRCODE='22023'; END IF;
  shown_us:=coalesce((e->>'shownUs')::bigint,shown::bigint*1000);
  IF shown_us/1000<>shown THEN RAISE EXCEPTION 'attention_trial_invalid' USING ERRCODE='22023'; END IF;
  s:=p_assessment->'schedule'->(i-1);
  due:=(CASE WHEN i=1 THEN 0 ELSE previous_closed+200 END)+(s->>'waitMs')::integer;
  IF (e->>'seq')::integer<>i OR shown NOT BETWEEN due AND duration
  OR (closed IS NULL AND i<>n) OR (closed IS NOT NULL AND closed NOT BETWEEN shown+1000 AND duration)
  THEN RAISE EXCEPTION 'attention_trial_invalid' USING ERRCODE='22023'; END IF;
  lag:=greatest(lag,shown-due,coalesce(closed-shown-1000,0));
  IF closed IS NOT NULL THEN count_closed:=count_closed+1; END IF;
  previous_closed:=closed;
  SELECT count(*),(min(coalesce((r->>'tUs')::bigint,(r->>'tMs')::bigint*1000))-shown_us)/1000.0 INTO hit_count,rt
  FROM jsonb_array_elements(p_assessment->'responses') r
  WHERE coalesce((r->>'tUs')::bigint,(r->>'tMs')::bigint*1000)>=shown_us AND coalesce((r->>'tUs')::bigint,(r->>'tMs')::bigint*1000)<shown_us+1000000;
  inside:=inside+hit_count; extras:=extras+greatest(0,hit_count-1);
  IF s->>'kind'='go' THEN
   IF hit_count>0 THEN
    IF rt<100 THEN anticipation:=anticipation+1;
    ELSE
     valid:=valid+1; times:=array_append(times,rt); blocks:=array_append(blocks,(i-1)*4/30);
     IF rt>500 THEN lapses:=lapses+1; END IF;
    END IF;
   ELSIF closed IS NOT NULL THEN omissions:=omissions+1; END IF;
  ELSIF hit_count>0 THEN commissions:=commissions+1; END IF;
 END LOOP;
 IF (state='completa') IS DISTINCT FROM (count_closed=30) OR (state='completa' AND duration<>previous_closed)
 THEN RAISE EXCEPTION 'attention_status_invalid' USING ERRCODE='22023'; END IF;
 SELECT round(avg(v),1),round(stddev_pop(v),1),round((percentile_cont(.5) WITHIN GROUP(ORDER BY v))::numeric,1),
  round((percentile_cont(.1) WITHIN GROUP(ORDER BY v))::numeric,1),round((percentile_cont(.9) WITHIN GROUP(ORDER BY v))::numeric,1)
 INTO mean_ms,deviation,median_ms,p10,p90 FROM unnest(times) v;
 decile:=greatest(1,ceil(valid*.1)::integer);
 SELECT round(avg(v),1) INTO fast_mean FROM (SELECT v FROM unnest(times) v ORDER BY v LIMIT decile) z;
 SELECT round(avg(v),1) INTO slow_mean FROM (SELECT v FROM unnest(times) v ORDER BY v DESC LIMIT decile) z;
 FOR j IN 0..3 LOOP
  SELECT round(avg(times[z]),1) INTO block_mean FROM generate_subscripts(times,1) z WHERE blocks[z]=j;
  quarters:=quarters||jsonb_build_array(block_mean);
 END LOOP;
 metrics:=jsonb_build_object('tempo_total_ms',duration,'previstos',30,'apresentados',n,'encerrados',count_closed,
  'respostas_validas',valid,'omissoes',omissions,'comissoes',commissions,
  'fora_estimulo',jsonb_array_length(p_assessment->'responses')-inside,'toques_extras',extras,
  'media_reacao_ms',mean_ms,'mediana_reacao_ms',median_ms,'dp_reacao_ms',deviation,'p10_reacao_ms',p10,'p90_reacao_ms',p90,
  'quartos_media_ms',quarters,'maior_atraso_ms',lag,
  'antecipacoes',anticipation+jsonb_array_length(p_assessment->'responses')-inside,'lapsos',lapses,
  'rapidos10_media_ms',fast_mean,'lentos10_media_ms',slow_mean,
  'declinio_ms',(quarters->>3)::numeric-(quarters->>0)::numeric);
 metrics:=metrics||jsonb_build_object('classification',public.ppl_attention_classify_v57(p_company_id,eid,aid,started,state,metrics,p_assessment->'technical'));
 normalized:=jsonb_build_object('id',aid,'employeeId',eid,'unit',u,'team',t,'moment',p_assessment->>'moment',
  'startedAt',to_char(started AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'finishedAt',to_char(finished AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'status',state,'durationMs',duration,'schedule',p_assessment->'schedule','trials',p_assessment->'trials','responses',p_assessment->'responses',
  'interruption',p_assessment->'interruption','technical',p_assessment->'technical','protocolVersion','visual-v1','appVersion',btrim(p_assessment->>'appVersion'));
 SELECT * INTO existing FROM public.ppl_attention_assessments WHERE id=aid;
 IF FOUND THEN
  IF existing.company_id<>p_company_id OR existing.payload<>normalized THEN RAISE EXCEPTION 'attention_id_conflict' USING ERRCODE='P5109'; END IF;
  RETURN jsonb_build_object('status','duplicada','id',aid,'received_at',existing.received_at,'assessment',to_jsonb(existing)-'payload');
 END IF;
 SELECT * INTO person FROM public.ppl_employees WHERE id=eid AND company_id=p_company_id AND active FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'attention_employee_not_found' USING ERRCODE='P5104'; END IF;
 INSERT INTO public.ppl_attention_assessments(id,company_id,employee_id,employee_name,employee_number,job_title,employee_snapshot,
  unit,team,moment,started_at,finished_at,status,duration_ms,metrics,protocol_version,app_version,payload,created_by)
 VALUES(aid,p_company_id,eid,person.name,person.employee_number,person.job_title,
  jsonb_build_object('id',person.id,'name',person.name,'employee_number',person.employee_number,'job_title',person.job_title),
  u,t,p_assessment->>'moment',started,finished,state,duration,metrics,'visual-v1',btrim(p_assessment->>'appVersion'),normalized,p_actor)
 ON CONFLICT(id) DO NOTHING;
 IF NOT FOUND THEN outcome:='duplicada'; END IF;
 SELECT * INTO existing FROM public.ppl_attention_assessments WHERE id=aid;
 IF existing.company_id<>p_company_id OR existing.payload<>normalized THEN RAISE EXCEPTION 'attention_id_conflict' USING ERRCODE='P5109'; END IF;
 RETURN jsonb_build_object('status',outcome,'id',aid,'received_at',existing.received_at,'assessment',to_jsonb(existing)-'payload');
END;
$visual$;
REVOKE ALL ON FUNCTION public.ppl_attention_visual_submit_v57(uuid,uuid,boolean,jsonb) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ppl_attention_visual_submit_v57(uuid,uuid,boolean,jsonb) TO service_role;
COMMIT;
