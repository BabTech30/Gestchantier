-- ============================================================
-- Migration 009 : Table invitations
-- ============================================================
-- L'admin d'une entreprise invite un chef ou un ouvrier en lui
-- envoyant un lien contenant un token UUID. Le destinataire :
--   1. Cree son compte (signup classique avec l'email invite)
--   2. L'app detecte le ?invite=TOKEN dans l'URL
--   3. Le RPC accept_invitation(token) lui assigne company_id + role
--
-- Securite :
--   - Le token est un UUID (impossible a deviner)
--   - L'invitation a une expiration (defaut : 7 jours)
--   - L'email du compte qui accepte DOIT correspondre a l'email invite
--   - Une seule acceptation possible (accepted_at != NULL = consommee)

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,

  email text not null,
  role text not null check (role in ('chef', 'ouvrier')),

  token uuid not null unique default gen_random_uuid(),

  invited_by uuid references auth.users(id) on delete set null,
  accepted_by uuid references auth.users(id) on delete set null,

  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);

create index idx_invitations_company_id on public.invitations(company_id);
create index idx_invitations_email      on public.invitations(lower(email));
create index idx_invitations_token      on public.invitations(token);

-- Une email donnee ne peut avoir qu'UNE invitation active par entreprise
create unique index idx_invitations_unique_pending
  on public.invitations(company_id, lower(email))
  where accepted_at is null;

comment on table public.invitations is
  'Invitations en attente : un admin invite un chef/ouvrier par email avec un token UUID';
