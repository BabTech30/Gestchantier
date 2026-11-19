-- ============================================================
-- Migration 012 : RLS des modules metier (Phase 7)
-- ============================================================
-- Regles communes :
--   LIRE      : tous les membres de l'entreprise (+ super_admin)
--   ECRIRE    : admin et chef de l'entreprise (+ super_admin)
-- Exceptions :
--   todos          : un ouvrier peut COCHER une tache (RPC set_todo_done)
--   project_notes  : tout membre peut AJOUTER une note sur un chantier,
--                    l'auteur (ou admin/chef) peut la supprimer

-- ============================================================
-- HELPERS
-- ============================================================
-- Suis-je membre de cette entreprise ?
create or replace function public.is_company_member(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and company_id = p_company_id
      and role is not null
      and status = 'active'
  );
$$;

-- Suis-je admin ou chef de cette entreprise ?
create or replace function public.is_company_manager(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and company_id = p_company_id
      and role in ('admin', 'chef')
      and status = 'active'
  );
$$;

comment on function public.is_company_member(uuid)  is 'TRUE si l''user est un membre actif de l''entreprise';
comment on function public.is_company_manager(uuid) is 'TRUE si l''user est admin ou chef actif de l''entreprise';

-- ============================================================
-- OUTILLAGE
-- ============================================================
alter table public.tools enable row level security;

create policy "tools_select" on public.tools for select to authenticated
  using (public.is_super_admin() or public.is_company_member(company_id));
create policy "tools_insert" on public.tools for insert to authenticated
  with check (public.is_super_admin() or public.is_company_manager(company_id));
create policy "tools_update" on public.tools for update to authenticated
  using      (public.is_super_admin() or public.is_company_manager(company_id))
  with check (public.is_super_admin() or public.is_company_manager(company_id));
create policy "tools_delete" on public.tools for delete to authenticated
  using (public.is_super_admin() or public.is_company_manager(company_id));

-- ============================================================
-- MATERIEL
-- ============================================================
alter table public.materials enable row level security;

create policy "materials_select" on public.materials for select to authenticated
  using (public.is_super_admin() or public.is_company_member(company_id));
create policy "materials_insert" on public.materials for insert to authenticated
  with check (public.is_super_admin() or public.is_company_manager(company_id));
create policy "materials_update" on public.materials for update to authenticated
  using      (public.is_super_admin() or public.is_company_manager(company_id))
  with check (public.is_super_admin() or public.is_company_manager(company_id));
create policy "materials_delete" on public.materials for delete to authenticated
  using (public.is_super_admin() or public.is_company_manager(company_id));

-- ============================================================
-- A PREVOIR (todos)
-- ============================================================
alter table public.todos enable row level security;

create policy "todos_select" on public.todos for select to authenticated
  using (public.is_super_admin() or public.is_company_member(company_id));
create policy "todos_insert" on public.todos for insert to authenticated
  with check (public.is_super_admin() or public.is_company_manager(company_id));
create policy "todos_update" on public.todos for update to authenticated
  using      (public.is_super_admin() or public.is_company_manager(company_id))
  with check (public.is_super_admin() or public.is_company_manager(company_id));
create policy "todos_delete" on public.todos for delete to authenticated
  using (public.is_super_admin() or public.is_company_manager(company_id));

-- Cocher / decocher une tache : ouvert a TOUS les membres de l'entreprise.
-- On passe par une RPC pour que l'ouvrier ne puisse modifier QUE le
-- champ "fait", et rien d'autre (titre, echeance, assignation...).
create or replace function public.set_todo_done(p_todo_id uuid, p_done boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company_id uuid;
begin
  select company_id into v_company_id from public.todos where id = p_todo_id;
  if v_company_id is null then
    raise exception 'Tache introuvable';
  end if;
  if not (public.is_super_admin() or public.is_company_member(v_company_id)) then
    raise exception 'Non autorise';
  end if;

  update public.todos
    set done    = p_done,
        done_at = case when p_done then now() else null end,
        done_by = case when p_done then auth.uid() else null end
    where id = p_todo_id;
end;
$$;

comment on function public.set_todo_done(uuid, boolean) is
  'Coche/decoche une tache. Ouvert a tous les membres (ouvriers inclus).';

-- ============================================================
-- MESSAGES
-- ============================================================
alter table public.announcements enable row level security;

create policy "announcements_select" on public.announcements for select to authenticated
  using (public.is_super_admin() or public.is_company_member(company_id));
create policy "announcements_insert" on public.announcements for insert to authenticated
  with check (
    public.is_super_admin()
    or (public.is_company_manager(company_id) and author_id = auth.uid())
  );
create policy "announcements_update" on public.announcements for update to authenticated
  using      (public.is_super_admin() or public.is_company_manager(company_id))
  with check (public.is_super_admin() or public.is_company_manager(company_id));
create policy "announcements_delete" on public.announcements for delete to authenticated
  using (public.is_super_admin() or public.is_company_manager(company_id));

-- ============================================================
-- JOURNAL DE CHANTIER
-- ============================================================
alter table public.project_notes enable row level security;

create policy "project_notes_select" on public.project_notes for select to authenticated
  using (public.is_super_admin() or public.is_company_member(company_id));
-- Tout membre peut ecrire, mais uniquement en son nom
create policy "project_notes_insert" on public.project_notes for insert to authenticated
  with check (
    public.is_super_admin()
    or (public.is_company_member(company_id) and author_id = auth.uid())
  );
-- Pas de modification : une note de chantier est un historique.
-- Suppression : l'auteur, ou admin/chef
create policy "project_notes_delete" on public.project_notes for delete to authenticated
  using (
    public.is_super_admin()
    or public.is_company_manager(company_id)
    or (author_id = auth.uid() and public.is_company_member(company_id))
  );
