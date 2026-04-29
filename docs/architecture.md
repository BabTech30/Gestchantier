# Architecture du projet GestChantier SaaS

## 🎯 Vision

SaaS de gestion de chantier pour artisans BTP, multi-entreprises, avec hiérarchie d'utilisateurs et cloisonnement strict des données.

## 📋 Décisions de cadrage (validées)

| Sujet | Décision |
|---|---|
| Cible | Tous artisans BTP (plaquistes, plombiers, élec, maçons...) |
| Modèle | SaaS multi-tenant (multi-entreprises cloisonnées) |
| Inscription | Libre, validée par super-admin |
| Hiérarchie | 4 niveaux : Super-admin → Admin entreprise → Chef → Ouvrier |
| Onboarding | Patron s'inscrit, puis invite son équipe par email |
| Prix | Gratuit limité (5 users / 10 chantiers max) → payant ensuite |
| Confidentialité | Ouvriers ne voient ni budgets ni taux horaires |
| Communications | Emails transactionnels (Resend) |
| Stack | Supabase (Auth + Postgres + Storage + Functions) |
| Hosting | Netlify (sous-domaine gratuit pour démarrer) |
| Domaine | À acquérir plus tard |
| Données | Reset complet, on repart de zéro |

## 👥 Rôles et permissions

### 🔱 Super-admin (le propriétaire du SaaS)
- Voir TOUTES les entreprises
- Valider / refuser / suspendre les inscriptions
- Voir les statistiques globales
- N'appartient à aucune entreprise

### 👔 Admin entreprise (le patron-artisan)
- Tout gérer dans SON entreprise
- Inviter / révoquer des chefs et ouvriers
- Voir budgets et taux horaires
- Premier inscrit d'une entreprise → devient automatiquement Admin

### 🧢 Chef de chantier
- Créer / modifier / supprimer des chantiers
- Gérer le matériel et l'outillage
- Assigner des ouvriers aux chantiers
- Voir budgets et taux horaires

### 🦺 Ouvrier
- Consulter les chantiers où il est assigné
- Cocher des tâches
- Ajouter des notes de chantier
- ❌ NE VOIT PAS : budgets, taux horaires des collègues

## 🏗️ Modules fonctionnels (héritage de l'app v6)

1. **Dashboard** — KPIs et alertes
2. **Chantiers** — projets BTP avec statuts (devis/planifié/en cours/terminé)
3. **Équipe** — salariés et sous-traitants
4. **Outillage** — par catégorie, statut OK/réparation
5. **Matériel** — à commander/commandé/en stock/livré
6. **À prévoir** — todos avec priorités
7. **Messages** — annonces internes

## 🗄️ Schéma de base de données (en construction)

Voir `/sql/` pour les scripts de migration.

### Tables principales prévues

- `companies` — entreprises clientes
- `profiles` — utilisateurs (extension de `auth.users` Supabase)
- `invitations` — invitations en attente
- `team_members` — fiches équipe (peut inclure des sous-traitants sans compte)
- `tools` — outillage
- `projects` — chantiers
- `project_notes` — notes datées par chantier
- `materials` — matériel
- `todos` — tâches
- `announcements` — messages

## 🔐 Sécurité

- **Row-Level Security (RLS)** activée sur toutes les tables
- Toute donnée métier liée à une `company_id` → cloisonnement automatique
- Permissions par rôle gérées en SQL (policies)
- Secrets dans `.env` (jamais commités)

## 📅 Roadmap technique

- [x] Phase 0 — Setup comptes
- [x] Phase 0.5 — Repo GitHub + structure projet
- [ ] Phase 1 — Schéma de la base (tables + relations)
- [ ] Phase 2 — Politiques RLS
- [ ] Phase 3 — Auth + page inscription
- [ ] Phase 4 — Page de login
- [ ] Phase 5 — Dashboard super-admin
- [ ] Phase 6 — Système d'invitations + emails
- [ ] Phase 7 — Migration des 7 modules métier
- [ ] Phase 8 — Polish + déploiement
