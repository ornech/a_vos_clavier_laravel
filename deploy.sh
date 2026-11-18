#!/bin/sh
# Construit l'image et démarre les conteneurs.
set -e
cd "$(dirname "$0")/docker"

# docker/.env n'est pas dans Git : on le crée au premier déploiement.
if [ ! -f .env ]; then
    cp .env.example .env
    echo "docker/.env créé à partir de .env.example (pensez à changer les mots de passe)."
fi

# Clé Laravel générée une seule fois (la changer invalide les sessions).
if ! grep -q '^APP_KEY=.' .env; then
    sed -i "s|^APP_KEY=.*|APP_KEY=base64:$(head -c 32 /dev/urandom | base64)|" .env
    echo "APP_KEY générée dans docker/.env."
fi

docker-compose up -d --build
