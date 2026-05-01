-- ============================================================
-- Migration 007 : Table projects (chantiers)
-- ============================================================
-- Coeur metier de l'app. Un chantier appartient a une entreprise
-- (company_id) et est creee par un user (created_by).
-- Cycle de vie : devis -> planifie -> en_cours -> termine -> archive

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,

  -- Identification
  name text not null,
  reference text,                       -- numero interne / devis
  trade text,                           -- corps de metier specifique au chantier

  -- Statut
  status text not null default 'devis'
    check (status in ('devis', 'planifie', 'en_cours', 'termine', 'archive')),
  priority text default 'normale'
    check (priority in ('basse', 'normale', 'haute', 'urgente')),

  -- Client
  client_name text,
  client_phone text,
  client_email text,

  -- Localisation
  address text,
  city text,
  zip_code text,
  -- Geoloc (lat/lng) — utile pour la carte des chantiers, mode terrain mobile
  lat double precision,
  lng double precision,

  -- Planning
  start_date date,
  end_date date,
  estimated_hours numeric(10, 2),

  -- Financier (visible UNIQUEMENT par admin/chef, jamais par ouvrier)
  budget_ht numeric(12, 2),
  budget_ttc numeric(12, 2),
  margin_target numeric(5, 2),          -- % de marge cible

  -- Notes generales (visibles par tous les membres de l'entreprise)
  notes text,

  -- Audit
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Index utiles
create index idx_projects_company_id on public.projects(company_id);
create index idx_projects_status     on public.projects(status);
create index idx_projects_dates      on public.projects(start_date, end_date);

-- Auto updated_at
create trigger projects_updated_at
  before update on public.projects
  for each row execute function public.handle_updated_at();

comment on table  public.projects             is 'Chantiers (cloisonnes par company_id)';
comment on column public.projects.budget_ht   is 'Confidentiel : visible uniquement admin/chef (filtre cote client + view a venir)';
comment on column public.projects.budget_ttc  is 'Confidentiel : visible uniquement admin/chef';
