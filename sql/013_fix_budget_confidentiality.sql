-- ============================================================
-- Migration 013 : Confidentialite des budgets (correctif)
-- ============================================================
-- PROBLEME corrige :
--   Avec la migration 008, la policy "projects_select" laissait TOUS
--   les membres de l'entreprise lire la table projects, colonnes budget
--   comprises. Le front lisait bien la vue projects_safe pour les
--   ouvriers, mais un ouvrier un peu malin pouvait interroger
--   directement l'API sur "projects" et voir budget_ht / budget_ttc.
--
-- CORRECTIF :
--   1. La table projects n'est plus lisible QUE par admin / chef
--      (et super_admin).
--   2. La vue projects_safe (sans colonnes financieres) s'execute
--      desormais avec les droits de son proprietaire et filtre
--      elle-meme sur l'entreprise de l'utilisateur. C'est la seule
--      porte d'entree des ouvriers sur les chantiers.

-- 1. Table projects : lecture reservee aux managers
drop policy if exists "projects_select" on public.projects;
create policy "projects_select"
  on public.projects for select
  to authenticated
  using (
    public.is_super_admin()
    or public.is_company_manager(company_id)
  );

-- 2. Vue projects_safe : filtre explicite par entreprise
create or replace view public.projects_safe
with (security_invoker = off) as
select
  id, company_id, name, reference, trade, status, priority,
  client_name, client_phone, client_email,
  address, city, zip_code, lat, lng,
  start_date, end_date, estimated_hours,
  notes, created_by, created_at, updated_at
from public.projects
where public.is_super_admin()
   or public.is_company_member(company_id);

revoke all on public.projects_safe from anon;
grant select on public.projects_safe to authenticated;

comment on view public.projects_safe is
  'Chantiers SANS donnees financieres, filtres sur l''entreprise de l''user. Seul acces des ouvriers aux chantiers.';
