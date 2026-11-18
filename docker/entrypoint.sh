#!/bin/sh
set -e

APP_DIR=/var/www/html
REPO=${GIT_REPO}

if [ ! -d "$APP_DIR/.git" ]; then
    git clone "$REPO" "$APP_DIR"
else
    cd "$APP_DIR"
    git pull
fi

cd "$APP_DIR"

# Le dépôt ne contient pas (encore) d'application Laravel :
# on crée le squelette au premier démarrage (dans un dossier temporaire,
# car create-project exige un dossier vide et $APP_DIR contient déjà .git et docker/).
if [ ! -f composer.json ]; then
    TMP_DIR=$(mktemp -d)
    composer create-project laravel/laravel "$TMP_DIR" \
        --no-dev --no-scripts --no-interaction --prefer-dist
    cp -a "$TMP_DIR"/. "$APP_DIR"/
    rm -rf "$TMP_DIR"
fi

if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
    else
        touch .env
    fi
fi

composer install --no-dev --optimize-autoloader --no-interaction

# La clé n'est générée qu'une fois : la régénérer à chaque démarrage
# invaliderait les sessions et les données chiffrées.
if ! grep -q '^APP_KEY=.' .env; then
    php artisan key:generate --force
fi

php artisan migrate --force
php artisan storage:link 2>/dev/null || true
php artisan config:cache
php artisan route:cache
php artisan view:cache

exec "$@"
