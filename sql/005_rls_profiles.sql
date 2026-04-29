-- ============================================================
-- Migration 005 : RLS sur profiles
-- ============================================================
-- Plus complexe que companies car on gère 3 cas :
--   - Mon propre profil (toujours accessible)
--   - Les profils de MON entreprise (visibles, modifiables si admin)
--   - Les profils des AUTRES entreprises (interdits sauf super_admin)
--
-- Bonus : trigger pour empêcher l'auto-promotion (un ouvrier ne
-- peut pas se transformer en admin tout seul).

-- ============================================================
-- 1. ACTIVER RLS
-- ============================================================
alter table public.profiles enable row level security;

-- ============================================================
-- 2. POLICIES
-- ============================================================

-- ---- SELECT ----
-- super_admin → tous les profils
-- tout user → son propre profil
-- tout user → les profils de son entreprise
create policy "profiles_select"
  on public.profiles for select
  to authenticated
  using (
    public.is_super_admin()
    or id = auth.uid()
    or (company_id is not null and company_id = public.get_my_company_id())
  );

-- ---- INSERT ----
-- En temps normal, l'insertion se fait via le trigger handle_new_user
-- (SECURITY DEFINER → bypass RLS). On autorise quand même les
-- super_admins à créer manuellement si besoin.
create policy "profiles_insert"
  on public.profiles for insert
  to authenticated
  with check (public.is_super_admin());

-- ---- UPDATE ----
-- super_admin → tout
-- admin → profils de son entreprise (pour gérer ses chefs/ouvriers)
-- tout user → son propre profil (les champs sensibles sont
--             protégés par le trigger ci-dessous)
create policy "profiles_update"
  on public.profiles for update
  to authenticated
  using (
    public.is_super_admin()
    or id = auth.uid()
    or (
      public.get_my_role() = 'admin'
      and company_id = public.get_my_company_id()
    )
  );

-- ---- DELETE ----
-- Seulement super_admin (rare, généralement on désactive avec
-- status='suspended' plutôt que de supprimer)
create policy "profiles_delete"
  on public.profiles for delete
  to authenticated
  using (public.is_super_admin());

-- ============================================================
-- 3. TRIGGER DE PROTECTION DES CHAMPS SENSIBLES
-- ============================================================
-- Empêche un user non-admin de modifier ses propres champs
-- sensibles (role, company_id, status, email). Sinon n'importe
-- quel ouvrier pourrait s'auto-promouvoir admin par une simple
-- requête UPDATE sur son propre profil.

create or replace function public.protect_profile_sensitive_fields()
returns trigger
language plpgsql
security invoker
as $$
declare
  my_role text;
begin
  -- Récupérer le rôle de l'user qui fait la modif
  my_role := public.get_my_role();

  -- Si c'est super_admin ou admin de l'entreprise concernée → tout autorisé
  if my_role = 'super_admin' then
    return new;
  end if;

  if my_role = 'admin' and old.company_id = public.get_my_company_id() then
    return new;
  end if;

  -- Sinon : on est en train de modifier son propre profil (cas autorisé
  -- par la policy UPDATE), il faut bloquer les champs sensibles
  if new.role is distinct from old.role then
    raise exception 'Modification du rôle non autorisée';
  end if;

  if new.company_id is distinct from old.company_id then
    raise exception 'Modification de l''entreprise non autorisée';
  end if;

  if new.status is distinct from old.status then
    raise exception 'Modification du statut non autorisée';
  end if;

  if new.email is distinct from old.email then
    raise exception 'Modification de l''email non autorisée';
  end if;

  return new;
end;
$$;

create trigger protect_profile_sensitive_fields
  before update on public.profiles
  for each row execute function public.protect_profile_sensitive_fields();
