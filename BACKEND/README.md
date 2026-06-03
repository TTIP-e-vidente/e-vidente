# Backend E-VIDENTE

## Que es

Este backend es una API local para la demo de E-VIDENTE. Esta hecho con
Node.js, TypeScript, Express y PostgreSQL. Permite registrar jugadores, iniciar
sesion, consultar perfil/progreso y guardar resumenes de partida.

El juego en Godot sigue pudiendo funcionar offline porque conserva su guardado
local. El backend se suma para persistir datos por usuario y sincronizar
progreso cuando hay sesion activa.

## Por que existe

El proyecto originalmente podia guardar progreso local desde Godot. Agregamos
el backend para preparar:

- cuentas de usuario;
- login con token JWT;
- perfil y experiencia por jugador;
- progreso remoto;
- historial de partidas;
- metricas reales de cada partida;
- persistencia en PostgreSQL.

La idea no fue reemplazar todo el juego ni obligarlo a depender de internet. El
backend agrega una capa de persistencia remota, pero Godot guarda local primero
y despues intenta sincronizar.

## Como se conecta con Godot

Godot no habla directo con PostgreSQL. El camino esperado es:

```text
Godot
-> BackendSession.gd
-> BackendApiClient.gd
-> Express API
-> Service
-> Repository
-> PostgreSQL
```

En Godot:

- `BackendApiClient.gd` es el cliente HTTP.
- `BackendSession.gd` maneja login, token y llamadas de sesion.
- `SaveManager` sigue guardando progreso local.
- Al terminar una partida, Godot arma un resumen y lo manda al backend si hay
  sesion activa.

Si el backend no responde, el juego no deberia romperse: la partida ya quedo
guardada localmente.

## Modelo de datos

El MER de Excalidraw tiene estas entidades:

- USER
- IMAGE
- PROFILE
- STREAK
- PROGRESO_RESTRICCION
- HISTORY_GAME
- GAME

En PostgreSQL algunas tablas no se llaman exactamente igual porque vienen de la
PoC y se conservaron para no romper datos ni migraciones. El codigo esta
organizado por modulos alineados al MER, aunque las tablas fisicas mantengan
nombres heredados.

| Entidad MER | Modulo backend | Tabla fisica | Comentario |
|---|---|---|---|
| USER | `user` + `auth` | `users` | Usuario registrado. `auth` maneja register/login/JWT. |
| IMAGE | `image` | `user_images` | Imagen/avatar del usuario. Preparado para uso futuro. |
| PROFILE | `profile` | `player_profiles` | Perfil, experiencia y datos principales. |
| STREAK | `streak` | `player_streaks` | Racha de actividad. |
| PROGRESO_RESTRICCION | `progreso-restriccion` | `player_progress` | Progreso por restriccion alimentaria. |
| HISTORY_GAME | `history-game` | `game_sessions` | Historial de partidas representado junto con GAME. |
| GAME | `game` | `game_sessions` | Metricas de una partida. |

`game_sessions` representa `HISTORY_GAME` + `GAME` en esta etapa porque una
partida y su historial se guardan juntos: progreso asociado, si se completo,
score, accuracy, aciertos, errores y duracion.

## Decisiones tecnicas importantes

- El `password` del MER se guarda como `password_hash` con bcrypt. Nunca se
  guarda ni se devuelve una password plana.
- `username` funciona como identificador publico, pero la DB tambien usa `id`
  UUID como PK tecnica para relaciones mas estables.
- `client_run_id` evita duplicar partidas si Godot reintenta una sincronizacion
  por problemas de red.
- `score`, `correct_answers`, `wrong_answers`, `duration_seconds` y
  `finished_at` existen porque guardan metricas reales de la partida.
- Las tablas fisicas heredadas no se renombran en esta etapa para evitar cambios
  destructivos.
- El estado actual no es "deuda cero", pero no hay deuda bloqueante para demo en
  la estructura principal del backend.

## Estructura del codigo

Los modulos principales viven en:

```text
BACKEND/src/modules/
|-- auth/
|-- health/
|-- user/
|-- image/
|-- profile/
|-- streak/
|-- progreso-restriccion/
|-- history-game/
`-- game/
```

`auth` y `health` son modulos tecnicos. Los demas representan entidades del MER
o partes directas del dominio.

Dentro de cada modulo se usa esta separacion:

```text
route -> controller -> service -> repository -> mapper
```

- `route` define endpoints y middlewares.
- `controller` maneja HTTP (`req`/`res`) y llama al service.
- `service` contiene reglas de negocio, transacciones e idempotencia.
- `repository` contiene SQL y acceso a PostgreSQL.
- `mapper` arma respuestas publicas y evita filtrar datos sensibles.
- `types` define contratos TypeScript.

Reglas de cuidado:

- No SQL en controllers.
- No Express `Request`/`Response` en repositories.
- No `password_hash` en respuestas publicas.
- No endpoints nuevos sin actualizar este README.

## Como levantar el entorno

Requisitos:

- Node.js
- npm
- Docker Desktop
- Docker Compose

Desde la raiz del repo:

```sh
cd BACKEND
cp .env.example .env
npm install
npm run setup:dev
npm run dev
```

`npm run setup:dev`:

1. Levanta PostgreSQL con Docker Compose.
2. Espera a que la base este disponible.
3. Corre migraciones.
4. Crea o actualiza usuarios demo.
5. Valida la conexion.

Es seguro correrlo mas de una vez. No borra datos.

## Variables de entorno

El archivo versionado es `.env.example`. Para desarrollo local se copia a
`.env`.

Valores locales esperados:

```txt
COMPOSE_PROJECT_NAME=e-vidente
POSTGRES_HOST=localhost
POSTGRES_DB=evidente_dev
POSTGRES_USER=evidente_user
POSTGRES_PASSWORD=evidente_password
POSTGRES_PORT=5432
BACKEND_PORT=3000
NODE_ENV=development
JWT_SECRET=evidente_local_dev_secret_change_me
JWT_EXPIRES_IN=7d
BCRYPT_SALT_ROUNDS=10
PASSWORD_RESET_TOKEN_EXPIRES_MINUTES=30
```

No commitear `.env`.

## Usuarios demo

Luego de `npm run setup:dev`:

| Usuario | Contrasena |
|---|---|
| `agus` | `123` |
| `margo` | `123` |

## Conexion a PostgreSQL

Para DataGrip o cualquier cliente SQL:

| Campo | Valor |
|---|---|
| Host | `localhost` |
| Port | `5432` |
| Database | `evidente_dev` |
| User | `evidente_user` |
| Password | revisar `POSTGRES_PASSWORD` en `.env` |

Tambien se puede validar por terminal:

```sh
docker exec -it e-vidente-postgres psql -U evidente_user -d evidente_dev -c "SELECT current_database(), current_user;"
```

## Migraciones

Las migraciones usan SQL plano y estan en `BACKEND/migrations`.

Se ejecutan con:

```sh
npm run migrate
```

El runner registra cada archivo aplicado en `schema_migrations` para no repetir
migraciones ya corridas.

No cambiar migraciones viejas salvo bug bloqueante. Si hace falta una nueva,
crear un archivo nuevo y probarlo con `npm test`.

## Endpoints principales

Auth:

- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`
- `POST /auth/logout`

Jugador:

- `GET /player/me`
- `GET /player/me/progress`
- `POST /player/me/progress`

Health:

- `GET /health`
- `GET /health/db`

Dev:

- `POST /dev/player-progress`
- `GET /dev/player-progress/:username`

`/dev/player-progress` queda como endpoint PoC/dev temporal para validar
persistencia manual. Para integraciones reales usar `/player/me/progress`, que
requiere token y usa el usuario autenticado.

## Probar manualmente

Health:

```sh
curl http://localhost:3000/health
curl http://localhost:3000/health/db
```

Login:

```sh
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"usernameOrMail\":\"agus\",\"password\":\"123\"}"
```

Usar el `accessToken` devuelto:

```sh
curl http://localhost:3000/player/me \
  -H "Authorization: Bearer TOKEN"
```

Guardar progreso:

```sh
curl -X POST http://localhost:3000/player/me/progress \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d "{\"clientRunId\":\"run_demo_1\",\"restriction\":\"CELIAQUIA\",\"expToAdd\":10,\"nodeId\":\"demo_node_1\",\"gameType\":\"quiz\",\"accuracy\":90,\"completed\":true,\"score\":100,\"correctAnswers\":8,\"wrongAnswers\":2,\"durationSeconds\":60}"
```

## Validaciones

Antes de dar el backend por listo:

```sh
cd BACKEND
npm run build
npm test
```

Con el backend levantado en otra terminal:

```sh
npm run smoke:api
```

El smoke revisa register, login, `auth/me`, guardar progreso y consultar
progreso.

## Fuera de alcance por ahora

- No hay refresh tokens.
- No hay roles/admin.
- No hay envio real de mails para recuperacion de contrasena.
- No hay leaderboard online.
- No hay migracion destructiva para renombrar tablas heredadas.
- No se borra la persistencia local de Godot.

## Que no tocar sin cuidado

- No ejecutar `docker compose down -v` salvo que se quiera borrar la DB local.
- No hacer `DROP TABLE` sin plan de limpieza y backup.
- No renombrar tablas fisicas sin migracion segura.
- No cambiar endpoints publicos sin revisar Godot.
- No cambiar contratos HTTP si Godot ya los consume.
- No exponer `password_hash`.
- No commitear `.env`, `node_modules`, `dist`, volumenes de PostgreSQL ni
  `docs-local`.
