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
- [ ] Phase 1 — Schéma de la base de données
- [ ] Phase 2 — Sécurité RLS multi-tenant
- [ ] Phase 3 — Auth + page inscription
- [ ] Phase 4 — Page de login
- [ ] Phase 5 — Dashboard super-admin
- [ ] Phase 6 — Système d'invitations
- [ ] Phase 7 — Migration des 7 modules métier
- [ ] Phase 8 — Polish + déploiement

## 📝 Licence

Privé — © BabTech30
