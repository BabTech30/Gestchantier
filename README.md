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
- [x] Phase 6 — Système d'invitations (token UUID + page Équipe + RPCs)
- [x] Phase 6.5 — PWA installable (manifest + service worker + mode offline shell)
- [x] Phase 6.6 — Déploiement Netlify (`netlify.toml` + headers + SPA fallback)
- [ ] Phase 6.7 — Edge Function Resend pour envoi auto des invitations par email
- [ ] Phase 7 — Modules métier restants (outillage, matériel, todos, messages)
- [ ] Phase 8 — Polish + paiement Stripe

## ▶️ Démarrer en local

**Option 1 — Manuel (5 min) :**
1. Applique les migrations SQL dans Supabase (SQL Editor) **dans l'ordre** : `001` → `010`.
2. Crée ton compte super-admin dans Supabase Auth, puis exécute `sql/003_seed_super_admin.sql`.
3. Ouvre `public/app.html` dans un navigateur (double-clic ou `python3 -m http.server` dans `/public`).
4. Renseigne ton **Supabase URL** et **anon key** au premier lancement (stockés en localStorage).
5. Connecte-toi avec ton compte super-admin → tu vois le panneau "Entreprises" pour valider les inscriptions.

**Option 2 — Script automatisé :**
```bash
brew install supabase/tap/supabase   # si pas déjà fait
./setup.sh                           # link projet + applique toutes les migrations
```

## 🚀 Déploiement Netlify

1. Sur [netlify.com](https://netlify.com), "Add new site → Import from Git" → sélectionne ce repo.
2. Build settings : Netlify détecte `netlify.toml` automatiquement (publish dir = `public`).
3. Deploy → Netlify te donne une URL `https://xxx.netlify.app`.
4. Chaque `git push origin main` déclenche un redéploiement automatique.

## 📱 Installation PWA (mobile chantier)

Sur le téléphone des ouvriers : ouvrir l'URL Netlify dans Safari/Chrome → "Ajouter à l'écran d'accueil".
L'app s'installe comme une vraie app native, fonctionne en mode plein écran, et le shell est mis en cache pour les zones de chantier sans réseau.

## 👥 Inviter un membre

Page **Équipe** (admin uniquement) → bouton "Inviter un membre" → email + rôle → l'app génère un lien `?invite=TOKEN`. Envoie-le par mail/SMS/WhatsApp. Le destinataire crée son compte avec le même email et est automatiquement rattaché à ton entreprise.

## 📝 Licence

Privé — © BabTech30
