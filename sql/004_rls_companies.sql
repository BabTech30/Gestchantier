-- ============================================================
-- Migration 004 : Row-Level Security (RLS) sur companies
-- ============================================================
-- Cette migration fait 3 choses :
--   1. Crée des fonctions HELPER pour identifier l'user connecté
--   2. Active RLS sur la table companies
--   3. Crée les policies (règles de qui peut faire quoi)

-- ============================================================
-- 1. FONCTIONS HELPER
-- ============================================================
-- Ces fonctions répondent à "qui suis-je ?" et seront utilisées
-- dans toutes les policies. SECURITY DEFINER = elles s'exécutent
-- avec les droits du créateur (= bypass RLS de profiles, sinon
-- on aurait une boucle infinie : pour lire profiles, on regarde
-- profiles, qui regarde profiles...)

-- Mon rôle (super_admin / admin / chef / ouvrier / NULL)
create or replace function public.get_my_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- Mon company_id (NULL si super_admin ou pas encore rattaché)
create or replace function public.get_my_company_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select company_id from public.profiles where id = auth.uid();
$$;

-- Suis-je super_admin ?
create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'super_admin'
  );
$$;

comment on function public.get_my_role() is 'Retourne le rôle de l''user authentifié';
comment on function public.get_my_company_id() is 'Retourne le company_id de l''user authentifié';
comment on function public.is_super_admin() is 'TRUE si l''user authentifié est super_admin';

-- ============================================================
-- 2. ACTIVER RLS SUR companies
-- ============================================================
-- Dès qu'on active RLS, par défaut PERSONNE ne peut rien faire
-- sur la table tant qu'on n'a pas créé de policies. C'est le
-- comportement "deny by default" — sécurité maximale.

alter table public.companies enable row level security;

-- ============================================================
-- 3. POLICIES SUR companies
-- ============================================================

-- ---- SELECT : qui peut LIRE quelles entreprises ? ----
-- super_admin → toutes les entreprises
-- admin/chef/ouvrier → uniquement la leur
create policy "companies_select"
  on public.companies for select
  to authenticated
  using (
    public.is_super_admin()
    or id = public.get_my_company_id()
  );

-- ---- INSERT : qui peut CRÉER une entreprise ? ----
-- N'importe quel user authentifié peut créer une entreprise
-- (cas du patron qui s'inscrit). Le statut sera 'pending' par
-- défaut, donc le super_admin devra valider.
create policy "companies_insert"
  on public.companies for insert
  to authenticated
  with check (true);

-- ---- UPDATE : qui peut MODIFIER une entreprise ? ----
-- super_admin → tout (notamment le statut pour valider/rejeter)
-- admin → SON entreprise (pour modifier nom, trade...)
create policy "companies_update"
  on public.companies for update
  to authenticated
  using (
    public.is_super_admin()
    or (
      public.get_my_role() = 'admin'
      and id = public.get_my_company_id()
    )
  );

-- ---- DELETE : qui peut SUPPRIMER une entreprise ? ----
-- Seulement super_admin (action lourde, irréversible)
create policy "companies_delete"
  on public.companies for delete
  to authenticated
  using (public.is_super_admin());
