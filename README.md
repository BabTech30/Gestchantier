# GestChantier SaaS

Application SaaS de gestion de chantier pour artisans BTP (plaquistes, plombiers, électriciens, maçons, etc.).

## 🏗️ Stack

- **Frontend** : React + Tailwind CSS (en HTML monofichier au démarrage)
- **Backend** : Supabase (Auth + PostgreSQL + Storage + Edge Functions)
- **Emails** : Resend
- **Hosting** : Netlify

## 👥 Architecture multi-tenant

| Niveau | Rôle |
|---|---|
| 🔱 Super-admin | Propriétaire du SaaS — valide les inscriptions |
| 👔 Admin entreprise | Patron-artisan — gère son entreprise |
| 🧢 Chef de chantier | Crée chantiers, gère matériel, assigne équipe |
| 🦺 Ouvrier | Consulte (sans budget/taux), coche tâches |

## 🔐 Sécurité

- Row-Level Security (RLS) sur toutes les tables
- Cloisonnement strict entre entreprises
- Confidentialité financière : ouvriers ne voient ni budgets ni taux horaires

## 📁 Structure du projet

\`\`\`
GestChantier-SaaS/
├── docs/      → Documentation (architecture, décisions, roadmap)
├── sql/       → Scripts SQL (migrations Supabase)
├── public/    → Fichiers HTML/CSS/JS du frontend
├── .env.example → Template des variables d'environnement
└── README.md
\`\`\`

## 🚀 Roadmap

- [x] Phase 0 — Setup comptes Supabase + Resend
- [x] Phase 1 — Schéma de la base (companies, profiles, projects)
- [x] Phase 2 — Sécurité RLS multi-tenant (companies, profiles, projects)
- [x] Phase 3 — Auth + page inscription (app.html)
- [x] Phase 4 — Page de login (app.html)
- [x] Phase 5 — Dashboard super-admin (validation des entreprises)
- [ ] Phase 6 — Système d'invitations + emails (Resend)
- [ ] Phase 7 — Modules métier restants (équipe, outils, matériel, todos, messages)
- [ ] Phase 8 — Polish + déploiement Netlify + paiement Stripe

## ▶️ Démarrer en local

1. Applique les migrations SQL dans Supabase (SQL Editor) **dans l'ordre** : `001` → `008`.
2. Crée ton compte super-admin dans Supabase Auth, puis exécute `sql/003_seed_super_admin.sql`.
3. Ouvre `public/app.html` dans un navigateur (double-clic ou via `python3 -m http.server` dans `/public`).
4. Renseigne ton **Supabase URL** et **anon key** au premier lancement (stockés en localStorage).
5. Connecte-toi avec ton compte super-admin → tu vois le panneau "Entreprises" pour valider les inscriptions.

## 📝 Licence

Privé — © BabTech30
