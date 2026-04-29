-- ============================================================
-- Migration 002 : Table profiles (utilisateurs)
-- ============================================================
-- Cette table étend auth.users (géré par Supabase Auth) avec
-- des infos métier : nom, prénom, rôle, entreprise.
--
-- Rôles :
--   super_admin : toi (proprio du SaaS), pas rattaché à une entreprise
--   admin       : patron-artisan (gère son entreprise)
--   chef        : chef de chantier
--   ouvrier     : compagnon
--
-- À l'inscription, le profil est créé automatiquement (trigger),
-- avec role=NULL et status='pending'. La complétion (role,
-- company_id) se fait dans une 2e étape du flux d'inscription.

create table public.profiles (
  -- Lien 1-1 avec auth.users : si l'user est supprimé, le profil aussi
  id uuid primary key references auth.users(id) on delete cascade,

  -- Identité
  email text not null unique,
  first_name text,
  last_name text,
  phone text,

  -- Rattachement entreprise (NULL pour super_admin uniquement)
  -- Si l'entreprise est supprimée, ses users le sont aussi
  company_id uuid references public.companies(id) on delete cascade,

  -- Rôle : NULL au début (pending), à compléter
  role text check (role in ('super_admin', 'admin', 'chef', 'ouvrier')),

  -- Statut du compte
  status text not null default 'pending'
    check (status in ('pending', 'active', 'suspended')),

  -- Dates
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Index pour accélérer les requêtes fréquentes
create index idx_profiles_company_id on public.profiles(company_id);
create index idx_profiles_role on public.profiles(role);

-- Documentation
comment on table public.profiles is 'Profils utilisateurs (extension de auth.users)';
comment on column public.profiles.role is
  'super_admin=propriétaire SaaS | admin=patron entreprise | chef=chef chantier | ouvrier=compagnon';
comment on column public.profiles.company_id is
  'NULL pour super_admin uniquement, obligatoire pour les autres rôles (vérifié côté app)';

-- ============================================================
-- TRIGGER 1 : créer automatiquement un profile à l'inscription
-- ============================================================
-- Dès qu'un user est créé dans auth.users (via Supabase Auth),
-- on crée sa ligne dans profiles avec son email.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- TRIGGER 2 : auto-update du champ updated_at
-- ============================================================
-- Chaque fois qu'on modifie un profil, updated_at est rafraîchi.

create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.handle_updated_at();
