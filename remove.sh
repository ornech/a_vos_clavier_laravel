#!/bin/sh
# Supprime conteneurs, image construite et volumes (dont la base de données)
# pour repartir de zéro.
set -e
cd "$(dirname "$0")/docker"
docker-compose down --volumes --rmi local --remove-orphans
