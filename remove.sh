#!/bin/sh
# Supprime conteneurs, image construite et volumes (dont la base de données)
# pour repartir de zéro. docker/.env est conservé.
set -e
cd "$(dirname "$0")/docker"

printf "Supprimer conteneurs, image et volumes (base de données comprise) ? [o/N] "
read -r reponse
if [ "$reponse" != "o" ]; then
    echo "Annulé."
    exit 0
fi

docker compose down --volumes --rmi local --remove-orphans
