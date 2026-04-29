-- ============================================================
-- Migration 001 : Table companies (entreprises clientes)
-- ============================================================
-- C'est la TABLE MÈRE du multi-tenant. Toutes les autres données
-- métier (chantiers, équipe, outils...) seront rattachées à une
-- company_id pour isolation par entreprise.

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  trade text,
  status text not null default 'pending'
    check (status in ('pending', 'active', 'suspended', 'rejected')),
  created_at timestamptz not null default now()
);

comment on table public.companies is 'Entreprises clientes du SaaS';
comment on column public.companies.status is
  'pending=en attente validation | active=validée | suspended=bloquée | rejected=refusée';

-- ============================================================
-- Test (optionnel, à supprimer après validation)
-- ============================================================
-- insert into public.companies (name, trade)
-- values ('Plâtrerie Test', 'Plaquiste');
--
-- select * from public.companies;
