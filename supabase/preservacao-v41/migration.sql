BEGIN;
ALTER TABLE public.ppl_management_entries DROP CONSTRAINT IF EXISTS ppl_management_entries_kind_check;
ALTER TABLE public.ppl_management_entries ADD CONSTRAINT ppl_management_entries_kind_check CHECK(kind IN ('training','legal-action','legal-document','nr','document'));
ALTER TABLE public.ppl_management_entries ADD COLUMN IF NOT EXISTS archived_at timestamptz;
ALTER TABLE public.ppl_management_entries ADD COLUMN IF NOT EXISTS archived_by uuid REFERENCES auth.users(id);
ALTER TABLE public.ppl_management_entries ADD COLUMN IF NOT EXISTS archive_reason text;
ALTER TABLE public.ppl_management_files ADD COLUMN IF NOT EXISTS sha256 text CHECK(sha256 IS NULL OR sha256 ~ '^[a-f0-9]{64}$');
CREATE TABLE IF NOT EXISTS public.ppl_management_audit(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 company_id uuid NOT NULL REFERENCES public.ppl_companies(id),
 entry_id uuid NOT NULL REFERENCES public.ppl_management_entries(id),
 actor_id uuid REFERENCES auth.users(id), actor_name text,
 operation text NOT NULL, before_data jsonb, after_data jsonb,
 occurred_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.ppl_management_audit ADD COLUMN IF NOT EXISTS actor_name text;
CREATE INDEX IF NOT EXISTS ppl_management_audit_entry ON public.ppl_management_audit(entry_id,id);
ALTER TABLE public.ppl_management_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ppl_management_audit FROM anon,authenticated,service_role;
GRANT SELECT ON public.ppl_management_audit TO authenticated,service_role;
GRANT INSERT ON public.ppl_management_audit TO service_role;
GRANT USAGE,SELECT ON SEQUENCE public.ppl_management_audit_id_seq TO service_role;
DROP POLICY IF EXISTS management_audit_read ON public.ppl_management_audit;
CREATE POLICY management_audit_read ON public.ppl_management_audit FOR SELECT TO authenticated
 USING(EXISTS(SELECT 1 FROM public.ppl_management_entries e WHERE e.id=ppl_management_audit.entry_id AND e.company_id=ppl_management_audit.company_id));
CREATE OR REPLACE FUNCTION public.ppl_preserve_management() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $preserve$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Exclusão definitiva bloqueada. Arquive o cadastro.'; END IF;
 IF TG_OP='UPDATE' THEN
  IF OLD.id<>NEW.id OR OLD.company_id<>NEW.company_id OR OLD.kind<>NEW.kind THEN RAISE EXCEPTION 'Identidade do cadastro não pode ser alterada.'; END IF;
  IF NEW.version<>OLD.version+1 THEN RAISE EXCEPTION 'Versão de atualização inválida.'; END IF;
  IF OLD.archived_at IS NOT NULL AND (NEW.payload IS DISTINCT FROM OLD.payload OR NEW.unit<>OLD.unit OR NEW.team<>OLD.team) THEN RAISE EXCEPTION 'Reative o cadastro antes de editar.'; END IF;
 END IF;
 RETURN NEW;
END;
$preserve$;
CREATE OR REPLACE FUNCTION public.ppl_audit_management() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $audit$
BEGIN
 INSERT INTO public.ppl_management_audit(company_id,entry_id,actor_id,actor_name,operation,before_data,after_data)
 VALUES(NEW.company_id,NEW.id,NEW.updated_by,(SELECT name FROM public.ppl_access WHERE user_id=NEW.updated_by),
  CASE WHEN TG_OP='INSERT' THEN 'Cadastro'
   WHEN OLD.archived_at IS NULL AND NEW.archived_at IS NOT NULL THEN 'Arquivamento'
   WHEN OLD.archived_at IS NOT NULL AND NEW.archived_at IS NULL THEN 'Reativação' ELSE 'Alteração' END,
  CASE WHEN TG_OP='UPDATE' THEN to_jsonb(OLD) ELSE NULL END,to_jsonb(NEW));
 RETURN NEW;
END;
$audit$;
CREATE OR REPLACE FUNCTION public.ppl_preserve_management_file() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $file$
BEGIN
 RAISE EXCEPTION 'Arquivo preservado. Adicione uma nova versão sem substituir a anterior.';
END;
$file$;
CREATE OR REPLACE FUNCTION public.ppl_audit_management_file() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $attachment$
BEGIN
 INSERT INTO public.ppl_management_audit(company_id,entry_id,actor_id,actor_name,operation,after_data)
 VALUES(NEW.company_id,NEW.entry_id,NEW.created_by,(SELECT name FROM public.ppl_access WHERE user_id=NEW.created_by),'Arquivo anexado',to_jsonb(NEW));
 RETURN NEW;
END;
$attachment$;
REVOKE ALL ON FUNCTION public.ppl_preserve_management(),public.ppl_audit_management(),public.ppl_preserve_management_file(),public.ppl_audit_management_file() FROM public,anon,authenticated;
DROP TRIGGER IF EXISTS preserve_management ON public.ppl_management_entries;
CREATE TRIGGER preserve_management BEFORE UPDATE OR DELETE ON public.ppl_management_entries FOR EACH ROW EXECUTE FUNCTION public.ppl_preserve_management();
DROP TRIGGER IF EXISTS audit_management ON public.ppl_management_entries;
CREATE TRIGGER audit_management AFTER INSERT OR UPDATE ON public.ppl_management_entries FOR EACH ROW EXECUTE FUNCTION public.ppl_audit_management();
DROP TRIGGER IF EXISTS preserve_management_file ON public.ppl_management_files;
CREATE TRIGGER preserve_management_file BEFORE UPDATE OR DELETE ON public.ppl_management_files FOR EACH ROW EXECUTE FUNCTION public.ppl_preserve_management_file();
DROP TRIGGER IF EXISTS audit_management_file ON public.ppl_management_files;
CREATE TRIGGER audit_management_file AFTER INSERT ON public.ppl_management_files FOR EACH ROW EXECUTE FUNCTION public.ppl_audit_management_file();
-- Baseline explicitamente identificada: não inventa histórico anterior à migração.
INSERT INTO public.ppl_management_audit(company_id,entry_id,actor_id,actor_name,operation,after_data)
 SELECT e.company_id,e.id,e.updated_by,(SELECT name FROM public.ppl_access WHERE user_id=e.updated_by),'Estado existente na ativação v41',to_jsonb(e)
 FROM public.ppl_management_entries e WHERE NOT EXISTS(SELECT 1 FROM public.ppl_management_audit a WHERE a.entry_id=e.id);
COMMIT;
