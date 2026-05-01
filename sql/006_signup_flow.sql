-- ============================================================
-- Migration 006 : Flow d'inscription patron-artisan
-- ============================================================
-- Quand un patron s'inscrit, il doit pouvoir :
--   1. Creer son entreprise
--   2. Devenir automatiquement admin de cette entreprise
--
-- Probleme : le trigger protect_profile_sensitive_fields (mig 005)
-- empeche un user non-admin de modifier son propre role/company_id.
-- C'est volontaire (anti auto-promotion), mais ca bloque l'onboarding.
--
-- Solution : une fonction SECURITY DEFINER qui pose un flag de
-- session, fait l'operation, retire le flag. Le trigger sait
-- detecter ce flag et autorise l'op.

-- ============================================================
-- 1. PATCH du trigger : autoriser le bypass via flag de session
-- ============================================================
create or replace function public.protect_profile_sensitive_fields()
returns trigger
language plpgsql
security invoker
as $$
declare
  my_role text;
begin
  -- BYPASS : si une fonction SECURITY DEFINER pose ce flag, on laisse passer
  if coalesce(current_setting('app.bypass_profile_protection', true), 'off') = 'on' then
    return new;
  end if;

  my_role := public.get_my_role();

  if my_role = 'super_admin' then
    return new;
  end if;

  if my_role = 'admin' and old.company_id = public.get_my_company_id() then
    return new;
  end if;

  if new.role is distinct from old.role then
    raise exception 'Modification du role non autorisee';
  end if;

  if new.company_id is distinct from old.company_id then
    raise exception 'Modification de l''entreprise non autorisee';
  end if;

  if new.status is distinct from old.status then
    raise exception 'Modification du statut non autorisee';
  end if;

  if new.email is distinct from old.email then
    raise exception 'Modification de l''email non autorisee';
  end if;

  return new;
end;
$$;

-- ============================================================
-- 2. RPC : creer son entreprise et devenir admin (1ere fois)
-- ============================================================
-- Conditions :
--   - User authentifie
--   - Pas encore rattache a une entreprise (company_id IS NULL)
--   - Pas encore de role
--
-- Effet :
--   - Cree une nouvelle company (status = pending)
--   - Met a jour le profile : company_id, role='admin', status='pending'
--   - Renvoie l'id de la company creee
--
-- Le super-admin devra ensuite valider la company (status='active')
-- ce qui declenchera (par un autre RPC) l'activation de l'user.

create or replace function public.create_company_and_become_admin(
  p_company_name text,
  p_trade text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company_id uuid;
  v_user_id uuid := auth.uid();
  v_existing record;
begin
  if v_user_id is null then
    raise exception 'Non authentifie';
  end if;

  if p_company_name is null or length(trim(p_company_name)) < 2 then
    raise exception 'Nom d''entreprise invalide';
  end if;

  select company_id, role into v_existing from public.profiles where id = v_user_id;
  if v_existing.company_id is not null or v_existing.role is not null then
    raise exception 'Cet utilisateur est deja rattache a une entreprise';
  end if;

  insert into public.companies (name, trade)
  values (trim(p_company_name), nullif(trim(coalesce(p_trade, '')), ''))
  returning id into v_company_id;

  perform set_config('app.bypass_profile_protection', 'on', true);
  update public.profiles
    set company_id = v_company_id,
        role = 'admin',
        status = 'pending'
    where id = v_user_id;
  perform set_config('app.bypass_profile_protection', 'off', true);

  return v_company_id;
end;
$$;

comment on function public.create_company_and_become_admin(text, text) is
  'Inscription patron-artisan : cree son entreprise et lui assigne le role admin (status pending, en attente validation super-admin)';

-- ============================================================
-- 3. RPC : super-admin approuve une entreprise
-- ============================================================
-- Approuver une entreprise = passer status='active' sur la company
-- ET activer tous ses users (status='active' aussi).

create or replace function public.approve_company(p_company_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin() then
    raise exception 'Reserve au super-admin';
  end if;

  update public.companies set status = 'active'
    where id = p_company_id and status = 'pending';

  perform set_config('app.bypass_profile_protection', 'on', true);
  update public.profiles set status = 'active'
    where company_id = p_company_id and status = 'pending';
  perform set_config('app.bypass_profile_protection', 'off', true);
end;
$$;

create or replace function public.reject_company(p_company_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin() then
    raise exception 'Reserve au super-admin';
  end if;

  update public.companies set status = 'rejected' where id = p_company_id;
end;
$$;

comment on function public.approve_company(uuid)  is 'Super-admin approuve une entreprise pending';
comment on function public.reject_company(uuid)   is 'Super-admin rejette une entreprise';
