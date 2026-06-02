# BACKEND · E-VIDENTE

## Objetivo

PoC local de backend y persistencia para TTIP. Prepara PostgreSQL, migraciones SQL y endpoints de validacion, pero no reemplaza todavia la persistencia local de Godot.

## Documentacion

- [API Backend](docs/API.md)
- [Modelo canonico](docs/CANONICAL_MODEL.md)
- [DER inicial](docs/DER.md)

## Requisitos

- Docker
- Docker Compose
- Node.js
- npm

## Configuracion inicial

```sh
cd BACKEND
cp .env.example .env
npm install
```

`COMPOSE_PROJECT_NAME=e-vidente` define el nombre del stack/proyecto que muestra Docker Desktop. La carpeta puede seguir llamandose `BACKEND/`; el servicio de Docker Compose se llama `postgres` y el contenedor se llama `e-vidente-postgres`.

## Levantar PostgreSQL

```sh
docker compose up -d
```

## Ver estado

```sh
docker compose ps
```

## Ver logs

```sh
docker compose logs -f postgres
```

## Correr migraciones

```sh
npm run migrate
```

## Validacion rapida

```sh
npm install
docker compose up -d
npm run migrate
npm run build
npm test
```

Smoke local de API:

```sh
npm run smoke:api
```

## Levantar backend

```sh
npm run dev
```

## Probar health

```txt
GET http://localhost:3000/health
GET http://localhost:3000/health/db
```

## Probar escritura y lectura

```txt
POST http://localhost:3000/dev/player-progress
```

Body:

```json
{
  "username": "demo_player",
  "name": "Demo Player",
  "restriction": "CELIAQUIA",
  "expToAdd": 10,
  "nodeId": "demo_node_1",
  "gameType": "quiz",
  "accuracy": 90,
  "completed": true
}
```

```txt
GET http://localhost:3000/dev/player-progress/demo_player
```

Estos endpoints `/dev/...` son solamente para validar persistencia local. No son la API final y no estan conectados con Godot.

## Endpoints autenticados de jugador

Estos endpoints son la base recomendada para una futura sincronizacion de jugador. Todavia no son consumidos por Godot y usan solo las tablas canonicas documentadas en `docs/CANONICAL_MODEL.md`.

Consultar usuario, perfil y racha:

```sh
curl http://localhost:3000/player/me \
  -H "Authorization: Bearer TOKEN"
```

Consultar progreso completo:

```sh
curl http://localhost:3000/player/me/progress \
  -H "Authorization: Bearer TOKEN"
```

Guardar progreso:

```sh
curl -X POST http://localhost:3000/player/me/progress \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d "{\"restriction\":\"CELIAQUIA\",\"expToAdd\":10,\"nodeId\":\"demo_node_1\",\"gameType\":\"quiz\",\"accuracy\":90,\"completed\":true,\"score\":100}"
```

`/dev/player-progress` queda como endpoint de validacion manual de PoC. Para codigo nuevo o futuras integraciones, preferir `/player/me/*` porque usa el usuario autenticado y no acepta `username` por body para modificar progreso de terceros.

## Ejecutar test de integracion

```sh
npm test
```

## Autenticacion PoC

Esta autenticacion es una PoC minima de backend. Godot todavia no consume estos endpoints. No hay refresh tokens, roles, recuperacion de contrasena, verificacion por mail, admin ni sesiones persistidas en DB.

Variables de entorno:

- `JWT_SECRET`
- `JWT_EXPIRES_IN`
- `BCRYPT_SALT_ROUNDS`

Flujo local:

```sh
cd BACKEND
npm install
docker compose up -d
npm run migrate
npm run dev
```

Registrar usuario:

```sh
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"agus\",\"name\":\"Agus\",\"mail\":\"agus@test.com\",\"password\":\"Password123\",\"age\":24}"
```

Login por username, mail o email:

```sh
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"usernameOrMail\":\"agus\",\"password\":\"Password123\"}"
```

Consultar usuario autenticado:

```sh
curl http://localhost:3000/auth/me \
  -H "Authorization: Bearer TOKEN"
```

Logout stateless:

```sh
curl -X POST http://localhost:3000/auth/logout \
  -H "Authorization: Bearer TOKEN"
```

El logout es manejado del lado del cliente: el backend no invalida tokens en servidor para esta PoC.

## Conexion local PostgreSQL

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

Connection string:

```txt
postgresql://evidente_user:evidente_password@localhost:5432/evidente_dev
```

## Apagar

```sh
docker compose down
```

`docker compose down` no borra los datos del volumen.

## Apagar borrando volumen

```sh
docker compose down -v
```

`docker compose down -v` borra el volumen y los datos locales de PostgreSQL.

## Notas de alcance

- La autenticacion actual es una PoC backend con JWT stateless.
- No hay leaderboard online.
- No hay admin ni telemetria.
- No hay conexion con Godot.
- No hay ORM; las migraciones usan SQL plano.
