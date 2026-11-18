FROM serversideup/php:8.5-fpm-nginx

WORKDIR /var/www/html
COPY --chown=www-data:www-data src/ .
RUN composer install --no-dev --optimize-autoloader --no-interaction
