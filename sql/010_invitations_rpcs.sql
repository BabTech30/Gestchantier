-- ============================================================
-- Migration 010 : RLS et RPCs pour invitations
-- ============================================================

alter table public.invitations enable row level security;

-- ---- SELECT ----
-- Admin/chef de la company voit ses invitations
-- Super-admin voit tout
-- L'utilisateur voit aussi les invitations qui lui sont adressees
--   (via match d'email avec auth.users)
create policy "invitations_select"
  on public.invitations for select
  to authenticated
  using (
    public.is_super_admin()
    or company_id = public.get_my_company_id()
    or lower(email) = lower((select email from auth.users where id = auth.uid()))
  );

-- ---- DELETE ----
-- Seul l'admin de la company peut revoquer une invitation
create policy "invitations_delete"
  on public.invitations for delete
  to authenticated
  using (
    public.is_super_admin()
    or (
      public.get_my_role() = 'admin'
      and company_id = public.get_my_company_id()
    )
  );

-- INSERT/UPDATE : passe par RPCs SECURITY DEFINER (pas de policy directe)

-- ============================================================
-- RPC : invite_member
-- ============================================================
create or replace function public.invite_member(
  p_email text,
  p_role text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_my_role text;
  v_my_company_id uuid;
  v_token uuid;
  v_email text := lower(trim(p_email));
begin
  if v_email is null or v_email = '' or v_email !~ '^[^@]+@[^@]+\.[^@]+$' then
    raise exception 'Email invalide';
  end if;

  if p_role not in ('chef', 'ouvrier') then
    raise exception 'Role invalide (chef ou ouvrier uniquement)';
  end if;

  select role, company_id into v_my_role, v_my_company_id
  from public.profiles where id = auth.uid();

  if v_my_role not in ('admin', 'super_admin') then
    raise exception 'Reserve a l''admin de l''entreprise';
  end if;

  if v_my_company_id is null then
    raise exception 'Aucune entreprise rattachee';
  end if;

  -- Si une invitation pending existe deja, on la renouvelle
  delete from public.invitations
  where company_id = v_my_company_id
    and lower(email) = v_email
    and accepted_at is null;

  -- Si l'email correspond deja a un user de la company, refuser
  if exists (
    select 1 from public.profiles p
    join auth.users u on u.id = p.id
    where p.company_id = v_my_company_id
      and lower(u.email) = v_email
  ) then
    raise exception 'Cet email est deja membre de l''entreprise';
  end if;

  insert into public.invitations (company_id, email, role, invited_by)
  values (v_my_company_id, v_email, p_role, auth.uid())
  returning token into v_token;

  return v_token;
end;
$$;

-- ============================================================
-- RPC : accept_invitation
-- ============================================================
create or replace function public.accept_invitation(p_token uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv record;
  v_user_id uuid := auth.uid();
  v_my_email text;
begin
  if v_user_id is null then
    raise exception 'Non authentifie';
  end if;

  select email into v_my_email from auth.users where id = v_user_id;

  select * into v_inv from public.invitations
  where token = p_token
  for update;

  if v_inv.id is null then
    raise exception 'Invitation introuvable';
  end if;

  if v_inv.accepted_at is not null then
    raise exception 'Invitation deja utilisee';
  end if;

  if v_inv.expires_at < now() then
    raise exception 'Invitation expiree';
  end if;

  if lower(v_inv.email) != lower(v_my_email) then
    raise exception 'Cette invitation est destinee a une autre adresse email';
  end if;

  if exists (
    select 1 from public.profiles
    where id = v_user_id
      and (company_id is not null or role is not null)
  ) then
    raise exception 'Vous etes deja rattache a une entreprise';
  end if;

  perform set_config('app.bypass_profile_protection', 'on', true);
  update public.profiles
    set company_id = v_inv.company_id,
        role       = v_inv.role,
        status     = 'active'
    where id = v_user_id;
  perform set_config('app.bypass_profile_protection', 'off', true);

  update public.invitations
    set accepted_at = now(),
        accepted_by = v_user_id
    where id = v_inv.id;

  return v_inv.company_id;
end;
$$;

-- ============================================================
-- RPC : revoke_invitation (raccourci avec verif)
-- ============================================================
create or replace function public.revoke_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_my_role text;
  v_my_company_id uuid;
  v_inv_company_id uuid;
begin
  select role, company_id into v_my_role, v_my_company_id
  from public.profiles where id = auth.uid();

  select company_id into v_inv_company_id
  from public.invitations where id = p_invitation_id;

  if v_inv_company_id is null then return; end if;

  if v_my_role = 'super_admin' or
     (v_my_role = 'admin' and v_my_company_id = v_inv_company_id) then
    delete from public.invitations where id = p_invitation_id;
  else
    raise exception 'Non autorise';
  end if;
end;
$$;

comment on function public.invite_member(text, text)         is 'Admin invite un nouveau membre (chef/ouvrier) — retourne le token';
comment on function public.accept_invitation(uuid)            is 'Le destinataire accepte une invitation et rejoint l''entreprise';
comment on function public.revoke_invitation(uuid)            is 'Admin revoque une invitation pending';
