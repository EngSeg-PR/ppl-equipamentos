BEGIN;
CREATE TABLE IF NOT EXISTS public.ppl_attention_rules_v57(
 company_id uuid NOT NULL REFERENCES public.ppl_companies(id),revision integer NOT NULL CHECK(revision>0),
 config jsonb NOT NULL,created_by uuid NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(company_id,revision));
ALTER TABLE public.ppl_attention_rules_v57 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ppl_attention_rules_v57 FROM public,anon,authenticated,service_role;
CREATE OR REPLACE TRIGGER ppl_attention_rules_preserve_v57 BEFORE UPDATE OR DELETE ON public.ppl_attention_rules_v57
 FOR EACH ROW EXECUTE FUNCTION public.ppl_attention_preserve_v51();

CREATE OR REPLACE FUNCTION public.ppl_attention_rules_default_v57() RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $default$
 SELECT '{"z1":1,"z2":2,"z3":3,"habituation":6,"individualMinimum":30,"individualWindow":30,"populationMinimum":30,"populationPeople":5,"segment":"job_title","maxExtraResponses":48,"maxTimingDelayMs":250,"recurrenceWindow":5,"recurrenceMinimum":3,"validation":"experimental"}'::jsonb;
$default$;

CREATE OR REPLACE FUNCTION public.ppl_attention_rules_v57(p_company uuid,p_actor uuid,p_config jsonb DEFAULT NULL,p_expected integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $rules$
DECLARE r public.ppl_attention_rules_v57; k text; cfg jsonb;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ppl_access WHERE user_id=p_actor AND active AND role='owner')
 THEN RAISE EXCEPTION 'attention_scope_denied' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ppl_companies WHERE id=p_company AND status='ready')
 THEN RAISE EXCEPTION 'attention_invalid' USING ERRCODE='22023'; END IF;
 -- A configuração é versionada; resultados anteriores mantêm a regra aplicada.
 PERFORM pg_advisory_xact_lock(hashtextextended(p_company::text,57));
 SELECT * INTO r FROM public.ppl_attention_rules_v57 WHERE company_id=p_company ORDER BY revision DESC LIMIT 1;
 IF p_config IS NOT NULL THEN
  IF coalesce(r.revision,0)<>p_expected THEN RAISE EXCEPTION 'attention_rules_conflict' USING ERRCODE='P5109'; END IF;
  IF jsonb_typeof(p_config) IS DISTINCT FROM 'object' OR (p_config-ARRAY['z1','z2','z3','habituation','individualMinimum','individualWindow','populationMinimum','populationPeople','segment','maxExtraResponses','maxTimingDelayMs','recurrenceWindow','recurrenceMinimum','validation'])<>'{}'::jsonb
  OR p_config->>'validation' IS DISTINCT FROM 'experimental' OR coalesce(p_config->>'segment','') NOT IN ('job_title','company')
  THEN RAISE EXCEPTION 'attention_rules_invalid' USING ERRCODE='22023'; END IF;
  FOREACH k IN ARRAY ARRAY['z1','z2','z3','habituation','individualMinimum','individualWindow','populationMinimum','populationPeople','maxExtraResponses','maxTimingDelayMs','recurrenceWindow','recurrenceMinimum'] LOOP
   IF jsonb_typeof(p_config->k) IS DISTINCT FROM 'number' OR (p_config->>k)::numeric NOT BETWEEN 0 AND 10000
   THEN RAISE EXCEPTION 'attention_rules_invalid' USING ERRCODE='22023'; END IF;
  END LOOP;
  FOREACH k IN ARRAY ARRAY['habituation','individualMinimum','individualWindow','populationMinimum','populationPeople','maxExtraResponses','maxTimingDelayMs','recurrenceWindow','recurrenceMinimum'] LOOP
   IF (p_config->>k) !~ '^[0-9]+$' THEN RAISE EXCEPTION 'attention_rules_invalid' USING ERRCODE='22023'; END IF;
  END LOOP;
  IF (p_config->>'z1')::numeric<=0 OR (p_config->>'z1')::numeric>=(p_config->>'z2')::numeric
  OR (p_config->>'z2')::numeric>=(p_config->>'z3')::numeric OR (p_config->>'z3')::numeric>10
  OR (p_config->>'individualMinimum')::integer<2 OR (p_config->>'individualWindow')::integer<(p_config->>'individualMinimum')::integer
  OR (p_config->>'individualWindow')::integer>100 OR (p_config->>'populationMinimum')::integer NOT BETWEEN 2 AND 5000
  OR (p_config->>'populationPeople')::integer NOT BETWEEN 2 AND 100 OR (p_config->>'habituation')::integer>100
  OR (p_config->>'maxExtraResponses')::integer>500 OR (p_config->>'maxTimingDelayMs')::integer NOT BETWEEN 10 AND 1000
  OR (p_config->>'recurrenceWindow')::integer NOT BETWEEN 2 AND 30 OR (p_config->>'recurrenceMinimum')::integer NOT BETWEEN 2 AND (p_config->>'recurrenceWindow')::integer
  THEN RAISE EXCEPTION 'attention_rules_invalid' USING ERRCODE='22023'; END IF;
  INSERT INTO public.ppl_attention_rules_v57(company_id,revision,config,created_by)
   VALUES(p_company,coalesce(r.revision,0)+1,p_config,p_actor) RETURNING * INTO r;
 END IF;
 RETURN jsonb_build_object('revision',coalesce(r.revision,0),'config',coalesce(r.config,public.ppl_attention_rules_default_v57()),'createdAt',r.created_at);
END;
$rules$;

CREATE OR REPLACE FUNCTION public.ppl_attention_classify_v57(p_company uuid,p_employee uuid,p_id uuid,p_started timestamptz,p_status text,p_metrics jsonb,p_technical jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $classify$
DECLARE
 cfg jsonb; rev integer; person public.ppl_employees; reasons jsonb:='[]'; scores jsonb:='[]';
 own_rows jsonb; population jsonb; own_count integer; population_count integer; population_people integer;
 group_name text; key text; sample jsonb; sample_count integer; current_value numeric; mean_value numeric; sd numeric; z numeric; worst numeric:=0;
 own_ready boolean; pop_ready boolean; incomparable boolean:=false; level text; guidance text; recurrent integer; in_window integer;
BEGIN
 SELECT config,revision INTO cfg,rev FROM public.ppl_attention_rules_v57 WHERE company_id=p_company ORDER BY revision DESC LIMIT 1;
 cfg:=coalesce(cfg,public.ppl_attention_rules_default_v57());rev:=coalesce(rev,0);
 IF coalesce((p_metrics->>'maior_atraso_ms')::integer,0)>(cfg->>'maxTimingDelayMs')::integer THEN
  RETURN jsonb_build_object('state','qualidade_insuficiente','level',NULL,'eligible',false,
   'guidance','Foi observado atraso de apresentação ou fechamento acima do parâmetro técnico. Solicite orientação para repetir em um aparelho com funcionamento estável.',
   'reasons',jsonb_build_array('Atraso observado: '||(p_metrics->>'maior_atraso_ms')||' ms; limite técnico: '||(cfg->>'maxTimingDelayMs')||' ms'),
   'ruleVersion',rev,'config',cfg,'formulaVersion','z-pior-v1','experimental',true);
 END IF;
 IF p_status<>'completa' THEN reasons:=reasons||'"Avaliação interrompida ou incompleta"'::jsonb; END IF;
 IF coalesce((p_metrics->>'respostas_validas')::integer,0)=0 THEN reasons:=reasons||'"Nenhuma resposta válida ao círculo parado"'::jsonb; END IF;
 IF coalesce((p_technical->>'multitouch')::boolean,false) THEN reasons:=reasons||'"Mais de um ponto de toque simultâneo registrado"'::jsonb; END IF;
 IF coalesce((p_metrics->>'fora_estimulo')::integer,0)+coalesce((p_metrics->>'toques_extras')::integer,0)>(cfg->>'maxExtraResponses')::integer
 THEN reasons:=reasons||'"Quantidade de entradas fora da regra excedeu o parâmetro técnico"'::jsonb; END IF;
 IF jsonb_array_length(reasons)>0 THEN
  RETURN jsonb_build_object('state','nao_interpretavel','level','Comportamento Inseguro','eligible',false,'reasons',reasons,
   'guidance','Peça orientação e converse com a gestão antes de uma nova tentativa. Este rótulo descreve a aplicação do teste e não atribui intenção ou culpa.',
   'ruleVersion',rev,'config',cfg,'formulaVersion','z-pior-v1','experimental',true);
 END IF;
 SELECT * INTO person FROM public.ppl_employees WHERE id=p_employee AND company_id=p_company;
 -- Hábitos: primeiros testes completos elegíveis de cada pessoa. Nunca usa o teste corrente.
 -- Referências usam exclusivamente visual-v1 com os mesmos limiares de coleta (100/500 ms).
 WITH eligible AS (
  SELECT a.*,row_number() OVER(PARTITION BY employee_id ORDER BY started_at,id) AS ordinal
  FROM public.ppl_attention_assessments a WHERE company_id=p_company AND protocol_version='visual-v1'
   AND started_at<=p_started AND id<>p_id AND status='completa' AND metrics#>>'{classification,eligible}'='true'
 ), selected AS (SELECT * FROM eligible WHERE employee_id=p_employee AND ordinal>(cfg->>'habituation')::integer
  ORDER BY started_at DESC,id DESC LIMIT (cfg->>'individualWindow')::integer)
 SELECT coalesce(jsonb_agg(metrics),'[]'::jsonb) INTO own_rows FROM selected;
 WITH eligible AS (
  SELECT a.*,row_number() OVER(PARTITION BY employee_id ORDER BY started_at,id) AS ordinal
  FROM public.ppl_attention_assessments a WHERE company_id=p_company AND protocol_version='visual-v1'
   AND started_at<=p_started AND id<>p_id AND status='completa' AND metrics#>>'{classification,eligible}'='true'
 ), selected AS (SELECT * FROM eligible WHERE employee_id<>p_employee AND ordinal>(cfg->>'habituation')::integer
  AND (cfg->>'segment'='company' OR job_title=person.job_title) ORDER BY started_at DESC,id DESC LIMIT 5000)
 SELECT coalesce(jsonb_agg(metrics),'[]'::jsonb),count(DISTINCT employee_id) INTO population,population_people FROM selected;
 own_count:=jsonb_array_length(own_rows); population_count:=jsonb_array_length(population);
 own_ready:=own_count>=(cfg->>'individualMinimum')::integer;
 pop_ready:=population_count>=(cfg->>'populationMinimum')::integer AND population_people>=(cfg->>'populationPeople')::integer;
 IF own_ready AND pop_ready THEN
  FOREACH group_name IN ARRAY ARRAY['individual','populacional'] LOOP
   sample:=CASE WHEN group_name='individual' THEN own_rows ELSE population END;
   FOREACH key IN ARRAY ARRAY['mediana_reacao_ms','lentos10_media_ms','dp_reacao_ms','lapsos','omissoes','antecipacoes','comissoes','declinio_ms'] LOOP
    current_value:=(p_metrics->>key)::numeric;
    SELECT count(*),avg((v->>key)::numeric),stddev_pop((v->>key)::numeric) INTO sample_count,mean_value,sd FROM jsonb_array_elements(sample) v WHERE v->>key IS NOT NULL;
    IF current_value IS NULL OR mean_value IS NULL OR sample_count < (cfg->>(CASE WHEN group_name='individual' THEN 'individualMinimum' ELSE 'populationMinimum' END))::integer THEN
     incomparable:=true;z:=NULL;
    ELSIF sd=0 THEN
     z:=CASE WHEN current_value<=mean_value THEN 0 ELSE NULL END;
     IF z IS NULL THEN incomparable:=true; END IF;
    ELSE z:=(current_value-mean_value)/sd;
    END IF;
    worst:=greatest(worst,coalesce(z,0));
    scores:=scores||jsonb_build_array(jsonb_build_object('reference',group_name,'parameter',key,'value',current_value,'mean',round(mean_value,3),'sd',round(sd,3),'z',round(z,3),'sampleCount',sample_count));
   END LOOP;
  END LOOP;
 END IF;
 IF NOT own_ready OR NOT pop_ready THEN level:=NULL;guidance:='Continue as avaliações conforme orientação da gestão. As bases ainda não permitem uma comparação completa.';
 ELSIF incomparable THEN level:=NULL;guidance:='A referência tem parâmetro sem dados ou sem variação suficiente. Solicite revisão da configuração pela equipe responsável.';
 ELSE
  level:=CASE WHEN worst<=(cfg->>'z1')::numeric THEN 'Normal' WHEN worst<=(cfg->>'z2')::numeric THEN 'Limítrofe' WHEN worst<=(cfg->>'z3')::numeric THEN 'Alterado' ELSE 'Significativamente Alterado' END;
  guidance:=CASE WHEN level='Normal' THEN 'Mantenha hábitos de descanso e atenção. Se sentir sonolência ou mal-estar, comunique a gestão independentemente deste resultado.'
   WHEN level='Limítrofe' THEN 'Faça uma pausa em local seguro e informe à gestão se houver sonolência ou dificuldade de atenção.'
   ELSE 'Converse com a gestão antes de iniciar ou retomar uma atividade de risco. A equipe responsável deve avaliar o contexto e as medidas preventivas.' END;
 END IF;
 SELECT count(*),count(*) FILTER(WHERE m#>>'{classification,level}' IN ('Limítrofe','Alterado','Significativamente Alterado')) INTO in_window,recurrent
 FROM(SELECT metrics m FROM public.ppl_attention_assessments WHERE company_id=p_company AND employee_id=p_employee AND id<>p_id AND protocol_version='visual-v1'
  AND started_at<=p_started AND metrics#>>'{classification,state}'='classificada' AND metrics#>>'{classification,ruleVersion}'=rev::text
  ORDER BY started_at DESC,id DESC LIMIT (cfg->>'recurrenceWindow')::integer-1) recent;
 IF level IS NOT NULL THEN
  in_window:=in_window+1;
  IF level<>'Normal' THEN recurrent:=recurrent+1; END IF;
 END IF;
 IF recurrent>=(cfg->>'recurrenceMinimum')::integer THEN guidance:=guidance||' Há recorrência de resultados fora da faixa Normal nesta regra. Solicite diálogo preventivo com a gestão; a recorrência não eleva o nível automaticamente.'; END IF;
 RETURN jsonb_build_object('state',CASE WHEN level IS NOT NULL THEN 'classificada' WHEN incomparable THEN 'referencia_insuficiente' ELSE 'base_em_formacao' END,
  'level',level,'eligible',true,'guidance',guidance,'ruleVersion',rev,'config',cfg,'formulaVersion','z-pior-v1','experimental',true,
  'individualCount',own_count,'populationCount',population_count,'populationPeople',population_people,
  'habituation',cfg->'habituation','scores',scores,'worstZ',CASE WHEN level IS NOT NULL THEN round(worst,3) ELSE NULL END,
  'recurrence',jsonb_build_object('count',recurrent,'observed',in_window,'window',cfg->'recurrenceWindow','minimum',cfg->'recurrenceMinimum','flag',recurrent>=(cfg->>'recurrenceMinimum')::integer),
  'reasons',jsonb_build_array(CASE WHEN level IS NULL THEN guidance ELSE 'Maior desvio de piora entre parâmetros e referências disponíveis; não é probabilidade de acidente ou diagnóstico.' END));
END;
$classify$;
REVOKE ALL ON FUNCTION public.ppl_attention_rules_default_v57() FROM public,anon,authenticated;
REVOKE ALL ON FUNCTION public.ppl_attention_rules_v57(uuid,uuid,jsonb,integer) FROM public,anon,authenticated;
REVOKE ALL ON FUNCTION public.ppl_attention_classify_v57(uuid,uuid,uuid,timestamptz,text,jsonb,jsonb) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ppl_attention_rules_v57(uuid,uuid,jsonb,integer) TO service_role;
-- Cálculo invocado apenas pelo validador privado; não é um endpoint público.
COMMIT;
