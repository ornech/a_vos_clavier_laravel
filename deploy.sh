#!/bin/sh
# Construit l'image et démarre les conteneurs.
set -e
cd "$(dirname "$0")/docker"
docker-compose up -d --build
