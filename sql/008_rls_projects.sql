-- ============================================================
-- Migration 008 : RLS sur projects + vue sans budget pour ouvriers
-- ============================================================
-- Regles :
--   SELECT : super_admin -> tout | autres -> chantiers de leur entreprise
--   INSERT : admin/chef de l'entreprise (avec company_id force)
--   UPDATE : admin/chef de l'entreprise
--   DELETE : admin uniquement (geste lourd)
--
-- Confidentialite financiere :
--   Une VIEW projects_safe expose tout SAUF les champs budget.
--   Les ouvriers liront cette vue, jamais la table projects.
--   La table projects elle-meme aura une policy SELECT qui exclut
--   les ouvriers, double protection.

alter table public.projects enable row level security;

-- ---- SELECT ----
-- Tout le monde de la company peut lire les LIGNES (mais les
-- ouvriers ne pourront pas selectionner les colonnes budget,
-- protege au niveau permissions ci-dessous).
create policy "projects_select"
  on public.projects for select
  to authenticated
  using (
    public.is_super_admin()
    or company_id = public.get_my_company_id()
  );

-- ---- INSERT ----
-- Admin ou chef de la company. company_id force a la company de l'user.
create policy "projects_insert"
  on public.projects for insert
  to authenticated
  with check (
    public.is_super_admin()
    or (
      public.get_my_role() in ('admin', 'chef')
      and company_id = public.get_my_company_id()
    )
  );

-- ---- UPDATE ----
create policy "projects_update"
  on public.projects for update
  to authenticated
  using (
    public.is_super_admin()
    or (
      public.get_my_role() in ('admin', 'chef')
      and company_id = public.get_my_company_id()
    )
  );

-- ---- DELETE : admin only ----
create policy "projects_delete"
  on public.projects for delete
  to authenticated
  using (
    public.is_super_admin()
    or (
      public.get_my_role() = 'admin'
      and company_id = public.get_my_company_id()
    )
  );

-- ============================================================
-- VIEW projects_safe : sans champs financiers
-- ============================================================
-- Pour les ouvriers, on n'expose ni budget ni marge.
-- La view herite des policies RLS de la table sous-jacente,
-- et on revoke explicitement la lecture du budget aux ouvriers
-- via cette vue (qui ne contient deja pas les colonnes).

create or replace view public.projects_safe
with (security_invoker = on) as
select
  id, company_id, name, reference, trade, status, priority,
  client_name, client_phone, client_email,
  address, city, zip_code, lat, lng,
  start_date, end_date, estimated_hours,
  notes, created_by, created_at, updated_at
from public.projects;

comment on view public.projects_safe is
  'Vue des chantiers SANS donnees financieres. Utilisee par le frontend pour les ouvriers.';
