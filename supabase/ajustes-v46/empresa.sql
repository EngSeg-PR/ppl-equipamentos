BEGIN;
ALTER TABLE public.ppl_companies ADD COLUMN IF NOT EXISTS cnpj text NOT NULL DEFAULT '';
ALTER TABLE public.ppl_companies ADD COLUMN IF NOT EXISTS cnae text NOT NULL DEFAULT '';
ALTER TABLE public.ppl_companies ADD COLUMN IF NOT EXISTS contract_manager text NOT NULL DEFAULT '';

CREATE OR REPLACE FUNCTION public.ppl_register_company(p_name text,p_slug text,p_logo text,p_cnpj text,p_cnae text,p_contract_manager text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $register_company_v46$
DECLARE c public.ppl_companies; b jsonb;
BEGIN
 INSERT INTO public.ppl_companies(name,slug,logo_data,status,cnpj,cnae,contract_manager)
 VALUES(p_name,p_slug,p_logo,'pending',p_cnpj,p_cnae,p_contract_manager) RETURNING * INTO c;
 b=jsonb_build_object('id',c.id,'slug',c.slug,'name',c.name,'version',c.brand_version,'logoData',c.logo_data);
 INSERT INTO public.ppl_brand_versions(company_id,version,snapshot) VALUES(c.id,c.brand_version,b);
 RETURN to_jsonb(c);
END;
$register_company_v46$;
REVOKE ALL ON FUNCTION public.ppl_register_company(text,text,text,text,text,text) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ppl_register_company(text,text,text,text,text,text) TO service_role;
COMMIT;
