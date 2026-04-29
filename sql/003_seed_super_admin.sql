-- ============================================================
-- Migration 003 : Création du compte super-admin
-- ============================================================
-- Ce script promeut un user existant (créé dans auth.users) au
-- rang de super_admin. Le super_admin est le propriétaire du SaaS
-- et n'appartient à aucune entreprise (company_id = NULL).
--
-- ⚠️ PROCÉDURE EN 2 TEMPS :
--
--   1. D'ABORD, créer le user dans Supabase Auth :
--      Authentication → Users → Add user → Create new user
--      Email    : bastiencvc@gmail.com
--      Password : (un mot de passe FORT, à noter dans un gestionnaire)
--      ✅ Cocher "Auto Confirm User"
--      → Create user
--
--      Le trigger handle_new_user va automatiquement créer le profil
--      dans public.profiles (avec role=NULL, status='pending').
--
--   2. ENSUITE, exécuter le SQL ci-dessous pour le promouvoir.

-- Étape 2.1 : vérifier que le profil a bien été créé par le trigger
select id, email, role, status, created_at
from public.profiles
where email = 'bastiencvc@gmail.com';
-- → tu dois voir 1 ligne avec role=NULL, status='pending'

-- Étape 2.2 : promotion en super_admin + activation
update public.profiles
set role = 'super_admin',
    status = 'active'
where email = 'bastiencvc@gmail.com';

-- Étape 2.3 : vérifier la promotion
select id, email, role, company_id, status
from public.profiles
where email = 'bastiencvc@gmail.com';
-- → tu dois voir : role='super_admin', company_id=NULL, status='active'
