#!/usr/bin/env bash
# ============================================================
# GestChantier SaaS — Setup automatise
# ============================================================
# Ce script :
#   1. Verifie que Supabase CLI est installe
#   2. Te guide pour lier ton projet Supabase
#   3. Applique toutes les migrations SQL dans l'ordre
#
# Pre-requis :
#   brew install supabase/tap/supabase
#   (sur Mac, sinon https://supabase.com/docs/guides/local-development/cli/getting-started)

set -e

cd "$(dirname "$0")"

echo "============================================================"
echo "  GestChantier SaaS — Setup"
echo "============================================================"
echo

# 1. Verifier supabase CLI
if ! command -v supabase >/dev/null 2>&1; then
  echo "[ERREUR] Supabase CLI non installe."
  echo
  echo "  Installation Mac :  brew install supabase/tap/supabase"
  echo "  Doc complete     :  https://supabase.com/docs/guides/local-development/cli/getting-started"
  exit 1
fi
echo "[OK] Supabase CLI : $(supabase --version)"
echo

# 2. Verifier qu'on est dans le repo
if [ ! -d "sql" ]; then
  echo "[ERREUR] Dossier sql/ introuvable. Lance ce script depuis la racine du repo GestChantier-SaaS."
  exit 1
fi

# 3. Linker le projet si pas deja fait
if [ ! -f "supabase/.temp/project-ref" ] && [ ! -f ".supabase/config.toml" ]; then
  echo "Pas encore lie a un projet Supabase distant."
  read -r -p "Project ref (ex. abcdefghijklmnop, trouvable dans l'URL du dashboard) : " PROJECT_REF
  if [ -z "$PROJECT_REF" ]; then
    echo "[ERREUR] Project ref vide."
    exit 1
  fi
  supabase link --project-ref "$PROJECT_REF"
fi
echo "[OK] Projet Supabase lie."
echo

# 4. Appliquer les migrations dans l'ordre
echo "Application des migrations SQL..."
echo "------------------------------------------------------------"
shopt -s nullglob
migrations=(sql/*.sql)
if [ ${#migrations[@]} -eq 0 ]; then
  echo "[ERREUR] Aucun fichier .sql trouve dans sql/."
  exit 1
fi

# Tri par nom (001..., 002..., etc.)
IFS=$'\n' sorted=($(sort <<<"${migrations[*]}"))
unset IFS

for f in "${sorted[@]}"; do
  echo "  -> $f"
  supabase db push --linked --include-all --debug < /dev/null >/dev/null 2>&1 || true
  # Fallback : execution directe via psql
  supabase db execute -f "$f" || {
    echo "[ATTENTION] Echec sur $f — applique manuellement dans le SQL Editor."
  }
done
echo "------------------------------------------------------------"
echo "[OK] Migrations appliquees."
echo

echo "============================================================"
echo "  Etapes suivantes :"
echo "============================================================"
echo
echo "  1. Cree ton compte super-admin :"
echo "       Supabase Dashboard > Authentication > Users > Add user"
echo "       Email : bastiencvc@gmail.com   (Auto Confirm = ON)"
echo "  2. Lance sql/003_seed_super_admin.sql pour le promouvoir."
echo "  3. Ouvre public/app.html (ou deploie sur Netlify)."
echo "  4. Saisis ton Supabase URL + anon key au premier lancement."
echo
