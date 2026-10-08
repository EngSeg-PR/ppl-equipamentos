-- Alternativa: executar somente depois da migração. Não é necessário repetir.
BEGIN;
UPDATE public.ppl_inspections SET archived_at=COALESCE(archived_at,now())
WHERE company_id=(SELECT id FROM public.ppl_companies WHERE slug='ppl') AND received_at<='2026-10-08T17:59:24Z'::timestamptz;
COMMIT;
