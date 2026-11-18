#!/bin/sh
# Vérifie que l'application Laravel répond et que la base de données est à jour.
# Usage : ./test.sh [url]   (par défaut http://localhost)
cd "$(dirname "$0")/docker"

URL=${1:-http://localhost}
ERREURS=0

ok() { echo "OK     $1"; }
ko() { echo "ECHEC  $1"; ERREURS=$((ERREURS + 1)); }

command -v curl >/dev/null 2>&1 || { echo "curl est requis pour ce test."; exit 1; }

# 1. Le serveur répond avec un code 200 (jusqu'à 60 s : migrations au démarrage)
code=000
i=0
while [ "$i" -lt 30 ]; do
    code=$(curl -s -o /dev/null -w '%{http_code}' "$URL" || true)
    [ "$code" = "200" ] && break
    i=$((i + 1))
    sleep 2
done
if [ "$code" = "200" ]; then
    ok "$URL répond (HTTP 200)"
else
    ko "$URL répond HTTP $code (attendu : 200)"
fi

# 2. Laravel s'exécute dans le conteneur
if version=$(docker-compose exec -T app php artisan --version 2>&1); then
    ok "$version"
else
    ko "artisan inaccessible dans le conteneur app : $version"
fi

# 3. La base de données est joignable et les migrations sont appliquées
if migrations=$(docker-compose exec -T app php artisan migrate:status 2>&1); then
    if echo "$migrations" | grep -q "Pending"; then
        ko "des migrations sont en attente"
    else
        ok "base de données joignable, migrations appliquées"
    fi
else
    ko "base de données inaccessible : $migrations"
fi

echo
if [ "$ERREURS" -eq 0 ]; then
    echo "Tout est OK."
else
    echo "$ERREURS vérification(s) en échec."
    exit 1
fi
