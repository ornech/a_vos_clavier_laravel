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

# Images de base téléchargées AVANT le build.
# Sinon BuildKit les télécharge en parallèle des étapes du Dockerfile : sur une
# connexion lente, le lien saturé fait échouer « npm run build », qui doit
# récupérer les polices sur fonts.bunny.net.
# Les images sont lues dans les lignes FROM du Dockerfile (les noms d'étapes
# déclarés avec AS, comme « base », sont ignorés) : pas de version à dupliquer ici.
for image in $(awk 'toupper($1) == "FROM" { if (!($2 in etape)) print $2; if (toupper($3) == "AS") etape[$4] = 1 }' Dockerfile); do
    docker pull "$image"
done

docker compose up -d --build