-- ============================================================
-- Migration 011 : Tables des modules metier (Phase 7)
-- ============================================================
-- Reprend les modules de l'app v6, version multi-entreprises :
--   tools          -> Outillage (perceuses, echafaudages...)
--   materials      -> Materiel / fournitures (plaques BA13, rails...)
--   todos          -> "A prevoir" (taches avec priorite et echeance)
--   announcements  -> Messages internes de l'entreprise
--   project_notes  -> Journal de chantier (notes datees par chantier)
--
-- Toutes les tables ont un company_id (cloisonnement par entreprise).
-- Quand une ligne reference un chantier (project_id), un trigger
-- verifie que ce chantier appartient bien a la MEME entreprise
-- (sinon on pourrait rattacher son materiel au chantier d'un autre).

-- ============================================================
-- 0. HELPER : verifier qu'un chantier est dans la bonne entreprise
-- ============================================================
create or replace function public.check_project_same_company()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.project_id is not null and not exists (
    select 1 from public.projects
    where id = new.project_id and company_id = new.company_id
  ) then
    raise exception 'Chantier introuvable dans cette entreprise';
  end if;
  return new;
end;
$$;

comment on function public.check_project_same_company() is
  'Trigger : empeche de rattacher une ligne a un chantier d''une autre entreprise';

-- ============================================================
-- 1. OUTILLAGE
-- ============================================================
create table public.tools (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,

  name text not null,
  category text,                                 -- Electroportatif, Echafaudage...
  quantity integer not null default 1 check (quantity >= 0),
  status text not null default 'ok'
    check (status in ('ok', 'reparation', 'hs')),
  location text not null default 'depot'
    check (location in ('camion', 'depot', 'atelier', 'chantier')),
  project_id uuid references public.projects(id) on delete set null,  -- si location = chantier
  notes text,

  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_tools_company_id on public.tools(company_id);
create index idx_tools_project_id on public.tools(project_id);

create trigger tools_updated_at
  before update on public.tools
  for each row execute function public.handle_updated_at();
create trigger tools_check_project
  before insert or update of project_id, company_id on public.tools
  for each row execute function public.check_project_same_company();

comment on table public.tools is 'Outillage de l''entreprise (etat + emplacement)';

-- ============================================================
-- 2. MATERIEL / FOURNITURES
-- ============================================================
create table public.materials (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,

  name text not null,                            -- "Plaques BA13"
  quantity numeric(12, 2) not null default 0 check (quantity >= 0),
  unit text not null default 'unites',           -- unites, plaques, metres, sacs...
  status text not null default 'a_commander'
    check (status in ('a_commander', 'commande', 'en_stock', 'livre')),
  supplier text,
  project_id uuid references public.projects(id) on delete set null,  -- NULL = stock general
  needed_by date,                                -- date a laquelle il faut l'avoir
  notes text,

  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_materials_company_id on public.materials(company_id);
create index idx_materials_project_id on public.materials(project_id);
create index idx_materials_status     on public.materials(status);

create trigger materials_updated_at
  before update on public.materials
  for each row execute function public.handle_updated_at();
create trigger materials_check_project
  before insert or update of project_id, company_id on public.materials
  for each row execute function public.check_project_same_company();

comment on table public.materials is 'Materiel et fournitures : a commander -> commande -> en stock -> livre';

-- ============================================================
-- 3. A PREVOIR (taches)
-- ============================================================
create table public.todos (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,

  title text not null,
  details text,
  priority text not null default 'normale'
    check (priority in ('basse', 'normale', 'urgente')),
  category text,                                 -- Commande, Administratif, Chantier...
  due_date date,
  project_id uuid references public.projects(id) on delete cascade,   -- NULL = tache generale
  assigned_to uuid references public.profiles(id) on delete set null,

  done boolean not null default false,
  done_at timestamptz,
  done_by uuid references auth.users(id) on delete set null,

  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_todos_company_id  on public.todos(company_id);
create index idx_todos_project_id  on public.todos(project_id);
create index idx_todos_assigned_to on public.todos(assigned_to);
create index idx_todos_open        on public.todos(company_id, done, due_date);

create trigger todos_updated_at
  before update on public.todos
  for each row execute function public.handle_updated_at();
create trigger todos_check_project
  before insert or update of project_id, company_id on public.todos
  for each row execute function public.check_project_same_company();

-- La personne assignee doit faire partie de l'entreprise
create or replace function public.check_todo_assignee()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.assigned_to is not null and not exists (
    select 1 from public.profiles
    where id = new.assigned_to and company_id = new.company_id
  ) then
    raise exception 'La personne assignee ne fait pas partie de l''entreprise';
  end if;
  return new;
end;
$$;

create trigger todos_check_assignee
  before insert or update of assigned_to, company_id on public.todos
  for each row execute function public.check_todo_assignee();

comment on table public.todos is 'Taches "A prevoir" (generales ou liees a un chantier)';

-- ============================================================
-- 4. MESSAGES INTERNES
-- ============================================================
create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,

  title text not null,
  content text not null,
  priority text not null default 'info'
    check (priority in ('info', 'important', 'urgent')),
  pinned boolean not null default false,

  author_id uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_announcements_company_id on public.announcements(company_id, created_at desc);

create trigger announcements_updated_at
  before update on public.announcements
  for each row execute function public.handle_updated_at();

comment on table public.announcements is 'Messages / annonces internes publies par le patron ou les chefs';

-- ============================================================
-- 5. JOURNAL DE CHANTIER (notes)
-- ============================================================
create table public.project_notes (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,

  content text not null,

  author_id uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index idx_project_notes_project on public.project_notes(project_id, created_at desc);
create index idx_project_notes_company on public.project_notes(company_id);

create trigger project_notes_check_project
  before insert or update of project_id, company_id on public.project_notes
  for each row execute function public.check_project_same_company();

comment on table public.project_notes is 'Notes datees par chantier (journal de chantier), ecrites par toute l''equipe';
