FROM serversideup/php:8.5-fpm-nginx-v5.0.5 AS base
WORKDIR /var/www/html

# Dépendances PHP (couche mise en cache tant que composer.lock ne change pas)
FROM base AS vendor
COPY --chown=www-data:www-data src/composer.json src/composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --no-scripts --no-autoloader

# Assets front
FROM node:24-alpine AS assets
WORKDIR /app
COPY src/package.json src/package-lock.json src/.npmrc ./
RUN npm ci
COPY src/ ./
RUN npm run build

# Image finale
FROM base
COPY --chown=www-data:www-data --from=vendor /var/www/html/vendor ./vendor
COPY --chown=www-data:www-data src/ .
COPY --chown=www-data:www-data --from=assets /app/public/build ./public/build
RUN composer dump-autoload --optimize --no-dev