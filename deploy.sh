#!/bin/sh
# Construit l'image et démarre les conteneurs.
set -e
cd "$(dirname "$0")/docker"

TOTAL=5
etape() { printf '\n[%s/%s] %s\n' "$1" "$TOTAL" "$2"; }
info() { printf '      %s\n' "$1"; }

DEPLOYE=.dernier-deploiement   # commit du dernier déploiement réussi (hors Git)

# ---------------------------------------------------------------------------
etape 1 "Configuration (docker/.env)"
# docker/.env n'est pas dans Git : on le crée au premier déploiement,
# avec des mots de passe de base de données aléatoires.
# (Ils ne sont générés qu'à la création : MariaDB les enregistre dans le volume
# au premier démarrage, les changer ensuite casserait la connexion.)
if [ ! -f .env ]; then
    cp .env.example .env
    sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$(head -c 18 /dev/urandom | base64 | tr -d '/+=')|" .env
    sed -i "s|^DB_ROOT_PASSWORD=.*|DB_ROOT_PASSWORD=$(head -c 18 /dev/urandom | base64 | tr -d '/+=')|" .env
    info "docker/.env créé à partir de .env.example."
    info "DB_PASSWORD et DB_ROOT_PASSWORD générés (non affichés). Sauvegardez ce fichier."
else
    info "docker/.env existant conservé (mots de passe inchangés)."
fi

# Clé Laravel générée une seule fois (la changer invalide les sessions).
if ! grep -q '^APP_KEY=.' .env; then
    sed -i "s|^APP_KEY=.*|APP_KEY=base64:$(head -c 32 /dev/urandom | base64)|" .env
    info "APP_KEY générée (non affichée)."
else
    info "APP_KEY déjà définie, conservée."
fi

# ---------------------------------------------------------------------------
etape 2 "Migrations depuis le dernier déploiement"
# Information seulement : rien n'est bloqué. Le serveur ne rejoue jamais une
# migration déjà exécutée ; une migration modifiée ou supprimée n'a donc aucun
# effet sur la base du serveur. Seules les migrations ajoutées sont à appliquer.
if ! git -C .. rev-parse --git-dir >/dev/null 2>&1; then
    info "Dépôt Git introuvable : comparaison impossible."
elif [ ! -f "$DEPLOYE" ]; then
    info "Aucun déploiement précédent enregistré : comparaison impossible."
else
    dernier=$(cat "$DEPLOYE")
    if ! git -C .. cat-file -e "${dernier}^{commit}" 2>/dev/null; then
        info "Dernier commit déployé (${dernier}) introuvable dans ce dépôt : comparaison impossible."
    else
        # Compare le dernier commit déployé au dossier de travail (ce qui sera construit).
        changes=$(git -C .. diff --no-renames --name-status "$dernier" -- src/database/migrations)
        ajoutees=$(printf '%s\n' "$changes" | awk '$1 == "A" { print $2 }')
        modifiees=$(printf '%s\n' "$changes" | awk '$1 == "M" { print $2 " (modifiée)" } $1 == "D" { print $2 " (supprimée)" }')
        info "Comparaison avec le dernier déploiement ($(printf '%.7s' "$dernier"))."
        if [ -z "$changes" ]; then
            info "Aucun changement dans src/database/migrations."
        fi
        if [ -n "$ajoutees" ]; then
            info "Migrations ajoutées (à appliquer, voir la fin du script) :"
            printf '%s\n' "$ajoutees" | sed 's/^/        + /'
        fi
        if [ -n "$modifiees" ]; then
            info "ATTENTION : migrations modifiées ou supprimées, sans effet sur la base du serveur :"
            printf '%s\n' "$modifiees" | sed 's/^/        ! /'
            info "Pour faire évoluer une table, il faut une nouvelle migration."
        fi
    fi
fi

# ---------------------------------------------------------------------------
etape 3 "Images de base"
# Téléchargées AVANT le build.
# Sinon BuildKit les télécharge en parallèle des étapes du Dockerfile : sur une
# connexion lente, le lien saturé fait échouer « npm run build », qui doit
# récupérer les polices sur fonts.bunny.net.
# Les images sont lues dans les lignes FROM du Dockerfile (les noms d'étapes
# déclarés avec AS, comme « base », sont ignorés) : pas de version à dupliquer ici.
# SC2013 : les noms d'images ne contiennent pas d'espace ; boucle for conservée car, avec set -e,
# elle arrête le script au premier docker pull en échec (ce que ne ferait pas un pipeline | while read).
# shellcheck disable=SC2013
for image in $(awk 'toupper($1) == "FROM" { if (!($2 in etape)) print $2; if (toupper($3) == "AS") etape[$4] = 1 }' Dockerfile); do
    info "docker pull $image"
    docker pull "$image"
done

# ---------------------------------------------------------------------------
etape 4 "Construction et démarrage"
# --wait : la commande ne rend la main que lorsque les services sont « healthy »
# et échoue sinon.
info "docker compose up -d --build --wait"
if ! docker compose up -d --build --wait; then
    echo
    echo "ECHEC : les conteneurs ne sont pas devenus « healthy »."
    echo "État des conteneurs :"
    docker compose ps
    echo
    echo "Dernières lignes du journal de l'application :"
    docker compose logs --tail 30 app
    exit 1
fi

# ---------------------------------------------------------------------------
etape 5 "Résultat"
docker compose ps
if git -C .. rev-parse HEAD > "$DEPLOYE" 2>/dev/null; then
    info "Commit déployé enregistré : $(printf '%.7s' "$(cat "$DEPLOYE")")"
else
    rm -f "$DEPLOYE"
fi
echo
echo "Application : http://localhost (port 80 de cette machine)"
echo
echo "Les migrations ne sont PAS appliquées automatiquement. Pour appliquer celles en attente :"
echo "  cd docker && docker compose exec app php artisan migrate --force"
echo "État détaillé (version, base, migrations) : ./test.sh"
