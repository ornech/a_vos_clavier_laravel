#!/bin/sh
# Sauvegarde la base de données, puis supprime conteneurs, image construite et
# volumes pour repartir de zéro. docker/.env est conservé.
set -e
cd "$(dirname "$0")/docker"

echo "Ce qui sera supprimé :"
echo "  - les conteneurs app et db"
echo "  - l'image de l'application construite localement"
echo "  - les volumes : dbdata (base de données) et storage (fichiers de l'application)"
echo "Conservé : docker/.env et les sauvegardes dans docker/backups/"
echo
echo "État actuel :"
docker compose ps -a
echo

printf "Supprimer conteneurs, image et volumes (base de données comprise) ? [o/N] "
read -r reponse
if [ "$reponse" != "o" ]; then
    echo "Annulé : rien n'a été supprimé."
    exit 0
fi

echo
echo "[1/2] Sauvegarde de la base de données"
if docker compose ps --status running --services 2>/dev/null | grep -qx db; then
    # Sauvegarde lisible par le seul propriétaire : elle contient les données et les mots de passe hachés.
    umask 077
    mkdir -p backups
    fichier="backups/db_$(date +%Y-%m-%d_%H-%M-%S).sql"
    echo "      mariadb-dump de la base du conteneur db vers docker/$fichier"
    # Mot de passe lu dans l'environnement du conteneur : pas besoin de lire docker/.env ici.
    if ! docker compose exec -T db sh -c 'exec mariadb-dump -u root -p"$MARIADB_ROOT_PASSWORD" --single-transaction --routines --databases "$MARIADB_DATABASE"' > "$fichier" || [ ! -s "$fichier" ]; then
        rm -f "$fichier"
        echo "ECHEC de la sauvegarde : rien n'a été supprimé."
        exit 1
    fi
    echo "      Fichier : docker/$fichier ($(wc -c < "$fichier") octets, $(grep -c '^CREATE TABLE' "$fichier" || true) tables)"
    echo "      Restauration : ./deploy.sh, puis"
    echo "        cd docker && docker compose exec -T db sh -c 'mariadb -u root -p\"\$MARIADB_ROOT_PASSWORD\"' < $fichier"
else
    echo "      Le conteneur db ne tourne pas : aucune sauvegarde possible."
    printf "      Supprimer quand même, sans sauvegarde ? [o/N] "
    read -r reponse
    if [ "$reponse" != "o" ]; then
        echo "Annulé : rien n'a été supprimé."
        exit 0
    fi
fi

echo
echo "[2/2] Suppression"
echo "      docker compose down --volumes --rmi local --remove-orphans"
docker compose down --volumes --rmi local --remove-orphans
echo
echo "Terminé. Pour redéployer : ./deploy.sh"
