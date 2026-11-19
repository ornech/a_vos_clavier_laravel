#!/bin/sh
# Vérifie que l'application Laravel répond et que la base de données est prête.
# Trois états : OK, ATTENTION (une action est attendue, le script continue), ECHEC.
cd "$(dirname "$0")/docker" || exit 1

TOTAL=4
ERREURS=0
ATTENTIONS=0

test_n() { printf '\n[%s/%s] %s\n' "$1" "$TOTAL" "$2"; }
info() { printf '      %s\n' "$1"; }
ok() { echo "      -> OK"; }
attention() { echo "      -> ATTENTION : $1"; ATTENTIONS=$((ATTENTIONS + 1)); }
ko() { echo "      -> ECHEC : $1"; ERREURS=$((ERREURS + 1)); }
indente() { sed 's/^/        /'; }

COMMANDE_MIGRATION="cd docker && docker compose exec app php artisan migrate --force"

# Code HTTP d'un chemin, requête faite depuis le conteneur avec PHP :
# aucun outil à installer sur la machine.
code_http() {
    docker compose exec -T app php -r '$h = @get_headers("http://localhost:8080" . $argv[1]); echo $h ? substr($h[0], 9, 3) : "000";' "$1" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
test_n 1 "Serveur web"
# /up est la route de santé de Laravel : elle ne dépend pas de la base.
# Jusqu'à 60 s d'attente (démarrage du conteneur).
info "Requête : GET http://localhost:8080/up (depuis le conteneur app)"
code=000
essais=0
while [ "$essais" -lt 30 ]; do
    essais=$((essais + 1))
    code=$(code_http /up)
    code=${code:-000}
    [ "$code" = "200" ] && break
    sleep 2
done
info "Réponse : HTTP $code (essai $essais/30)"
if [ "$code" = "200" ]; then
    code_accueil=$(code_http /)
    info "Requête : GET http://localhost:8080/ (page d'accueil)"
    info "Réponse : HTTP ${code_accueil:-000}"
    if [ "${code_accueil:-000}" = "200" ]; then
        ok
    else
        ko "la page d'accueil ne répond pas 200 alors que l'application est démarrée"
        info "Cause fréquente : migrations non appliquées (sessions stockées en base). Voir le test 4."
    fi
else
    ko "le serveur ne répond pas (attendu : HTTP 200)"
    info "Dernières lignes du journal de l'application :"
    docker compose logs --tail 15 app 2>&1 | indente
fi

# ---------------------------------------------------------------------------
test_n 2 "Application Laravel"
if version=$(docker compose exec -T app php artisan --version 2>&1); then
    info "$version"
    info "PHP $(docker compose exec -T app php -r 'echo PHP_VERSION;' 2>/dev/null)"
    env_app=$(docker compose exec -T app printenv APP_ENV 2>/dev/null || true)
    debug=$(docker compose exec -T app printenv APP_DEBUG 2>/dev/null || true)
    info "Environnement : APP_ENV=${env_app:-?}, APP_DEBUG=${debug:-?}"
    if [ "$debug" = "true" ]; then
        attention "APP_DEBUG=true : les pages d'erreur affichent le détail de l'application. À éviter sur un serveur exposé."
    else
        ok
    fi
else
    info "$version"
    ko "artisan inaccessible dans le conteneur app"
fi

# ---------------------------------------------------------------------------
test_n 3 "Base de données"
base_ok=0
if sortie=$(docker compose exec -T app php artisan db:show 2>&1); then
    base_ok=1
    # Seul l'en-tête (version, connexion, base, hôte, nombre de tables) : la liste des tables est omise.
    printf '%s\n' "$sortie" | awk '/Schema \/ Table/ { exit } NF' | sed 's/^/      /'
    ok
else
    printf '%s\n' "$sortie" | head -5 | sed 's/^/      /'
    ko "base de données inaccessible"
fi

# ---------------------------------------------------------------------------
test_n 4 "Migrations"
# Les migrations sont volontaires : une migration en attente est un rappel, pas une panne.
if [ "$base_ok" -eq 0 ]; then
    info "Non testé : la base est inaccessible."
elif statut=$(docker compose exec -T app php artisan migrate:status 2>&1); then
    appliquees=$(printf '%s\n' "$statut" | grep -c '\] Ran' || true)
    attente=$(printf '%s\n' "$statut" | grep -c 'Pending' || true)
    info "Appliquées : $appliquees, en attente : $attente"
    printf '%s\n' "$statut" | grep -E '\] Ran|Pending' | indente
    if [ "$attente" -eq 0 ]; then
        ok
    else
        attention "$attente migration(s) en attente. Pour les appliquer :"
        info "  $COMMANDE_MIGRATION"
    fi
else
    printf '%s\n' "$statut" | head -3 | sed 's/^/      /'
    attention "aucune migration appliquée (base neuve ?). Pour les appliquer :"
    info "  $COMMANDE_MIGRATION"
fi

# ---------------------------------------------------------------------------
echo
echo "Bilan : $ERREURS échec(s), $ATTENTIONS attention(s)."
if [ "$ERREURS" -ne 0 ]; then
    exit 1
elif [ "$ATTENTIONS" -eq 0 ]; then
    echo "Tout est OK."
else
    echo "Aucun échec ; des actions sont attendues (voir ATTENTION ci-dessus)."
fi
