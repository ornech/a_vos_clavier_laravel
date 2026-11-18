FROM serversideup/php:8.5-fpm-nginx

# L'image de base n'embarque pas git, nécessaire à entrypoint.sh (clone/pull du dépôt).
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*
USER www-data
