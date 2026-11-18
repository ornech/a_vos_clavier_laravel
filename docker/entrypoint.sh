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

composer install --no-dev --optimize-autoloader --no-interaction
php artisan key:generate --force 2>/dev/null || true
php artisan migrate --force
php artisan storage:link 2>/dev/null || true
php artisan config:cache
php artisan route:cache
php artisan view:cache

exec "$@"   