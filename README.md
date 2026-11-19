# À vos claviers — Laravel

Application Laravel développée en local, déployée dans Docker : un conteneur `app` (nginx + PHP-FPM) et un conteneur `db` (MariaDB).

```
src/      Application Laravel
docker/   Dockerfile, docker-compose.yaml, .env.example (modèle de configuration du serveur)
deploy.sh / test.sh / remove.sh
```

## Fonctionnement

- `src/` est **copié dans l'image** au build, pas monté. Une modification n'apparaît sur le serveur qu'après `./deploy.sh`.
- nginx ne sert que `src/public/`, sur le port 8080 du conteneur, publié sur le **port 80** de la machine.
- Les tests se lancent en local (`src/tests` n'est pas dans l'image).

## Développer

Prérequis : PHP ≥ 8.3, Composer, Node ≥ 22.13, Internet (polices depuis `fonts.bunny.net` au build).

```sh
cd src
composer run setup    # une fois : dépendances, .env, clé, base, front
composer run dev      # http://localhost:8000 (serveur, Vite, file d'attente, logs)
composer test         # avant de pousser
```

> En local, `src/.env.example` utilise encore SQLite alors que le serveur utilise MariaDB : passage à MariaDB en cours.

Base de données (commandes volontaires) :

- `php artisan make:migration nom` · `php artisan migrate` · `php artisan migrate:fresh --seed` (efface la base locale).
- **Une migration déjà poussée ne se modifie jamais** : en créer une nouvelle. Le serveur ne rejoue pas une migration déjà exécutée.
- Le seeder crée `test@example.com` : jamais sur le serveur exposé.

Puis `git add`, `git commit`, `git push`. Le déploiement est manuel.

## Déployer

Prérequis : Docker avec `docker compose` v2, port 80 libre.

```sh
git pull
./deploy.sh     # construit et démarre ; crée docker/.env au premier lancement
./test.sh       # vérifie HTTP 200, artisan et la base
./remove.sh     # supprime conteneurs, image et volumes, base comprise
```

## Variables (`docker/.env`)

| Variable                                                        | Rôle                                                                                                   |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `APP_ENV`, `APP_DEBUG`                                          | `production` et `false` : jamais `true` sur un serveur exposé                                          |
| `APP_KEY`                                                       | Clé de chiffrement, générée une seule fois par `deploy.sh`                                             |
| `DB_CONNECTION`, `DB_HOST`                                      | Pilote (`mysql` convient à MariaDB) et nom du service `db`                                             |
| `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, `DB_ROOT_PASSWORD` | Base et mots de passe (aléatoires, générés une fois), repris par MariaDB (`MARIADB_*`)                 |
| `AUTORUN_ENABLED`                                               | Image serversideup/php : au démarrage du conteneur, lance les migrations, `storage:link` et les caches |
| `LOG_CHANNEL`                                                   | `stderr` : journaux visibles avec `docker compose logs`                                                |
| `HEALTHCHECK_PATH`                                              | `/up` (défini dans le compose) : route de santé de Laravel                                             |

Les autres variables de l'image (par exemple `AUTORUN_LARAVEL_MIGRATION=false` pour désactiver les seules migrations automatiques) : [référence complète](https://serversideup.net/open-source/docker-php/docs/reference/environment-variable-specification).

## Attention

- **Sauvegardez `docker/.env`** (hors Git). Les mots de passe de la base sont figés à sa création : un nouveau `.env` ne correspondrait plus.
- Aucune sauvegarde automatique de la base.
- HTTP uniquement : pour Internet, ajoutez un reverse proxy TLS.
- `deploy.sh` construit le dossier de travail, pas un commit.

## Références

- [Variables d'environnement de l'image serversideup/php](https://serversideup.net/open-source/docker-php/docs/reference/environment-variable-specification)
- [Automatisations Laravel de l'image](https://serversideup.net/open-source/docker-php/docs/framework-guides/laravel/automations)
