# BACKEND · E-VIDENTE

## Objetivo

Infraestructura local inicial para preparar la futura persistencia del juego con PostgreSQL.

## Requisitos

- Docker
- Docker Compose

## Configuracion inicial

```sh
cd BACKEND
cp .env.example .env
```

`COMPOSE_PROJECT_NAME=e-vidente` define el nombre del stack/proyecto que muestra Docker Desktop. La carpeta puede seguir llamandose `BACKEND/`; el servicio de Docker Compose se llama `postgres` y el contenedor se llama `e-vidente-postgres`.

## Levantar PostgreSQL

```sh
docker compose up -d
```

## Ver logs

```sh
docker compose logs -f postgres
```

## Ver estado del contenedor

```sh
docker compose ps
```

## Conectarse localmente

```sh
docker exec -it e-vidente-postgres psql -U evidente_user -d evidente_dev
docker exec -it e-vidente-postgres psql -U evidente_user -d evidente_dev -c "SELECT current_database(), current_user;"
```

Datos por defecto:

- Host: `localhost`
- Port: `5432`
- Database: `evidente_dev`
- User: `evidente_user`
- Password: `evidente_password`

## Connection string

```txt
postgresql://evidente_user:evidente_password@localhost:5432/evidente_dev
```

## Apagar servicios

```sh
docker compose down
```

`docker compose down` no borra los datos del volumen.

## Apagar y borrar volumen

```sh
docker compose down -v
```

`docker compose down -v` borra el volumen y los datos locales de PostgreSQL.

## Notas de alcance

Esta carpeta no implementa endpoints, autenticacion, migraciones, seeders ni integracion con Godot. Por ahora solo deja PostgreSQL listo para desarrollo local.
