# API Backend - E-VIDENTE

## Alcance

Backend PoC para TTIP. Godot todavia no consume estos endpoints y su persistencia local sigue intacta. La API cubre autenticacion minima JWT y endpoints autenticados de jugador para futura sincronizacion.

## Variables de entorno

- `POSTGRES_HOST`
- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_PORT`
- `BACKEND_PORT`
- `JWT_SECRET`
- `JWT_EXPIRES_IN`
- `BCRYPT_SALT_ROUNDS`

## Auth

### POST /auth/register

- Auth requerida: no.
- Body:

```json
{
  "username": "agus",
  "name": "Agus",
  "mail": "agus@test.com",
  "password": "Password123",
  "age": 24
}
```

- Respuesta exitosa: `201`.

```json
{
  "user": {
    "id": "...",
    "username": "agus",
    "name": "Agus",
    "mail": "agus@test.com",
    "age": 24
  },
  "accessToken": "..."
}
```

- Errores posibles: `400` body invalido, `409` username/mail duplicado, `500` error inesperado.

```sh
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"agus\",\"name\":\"Agus\",\"mail\":\"agus@test.com\",\"password\":\"Password123\",\"age\":24}"
```

### POST /auth/login

- Auth requerida: no.
- Body:

```json
{
  "usernameOrMail": "agus",
  "password": "Password123"
}
```

- Respuesta exitosa: `200`, user publico y `accessToken`.
- Errores posibles: `400` body invalido, `401` credenciales invalidas, `500` error inesperado.

```sh
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"usernameOrMail\":\"agus\",\"password\":\"Password123\"}"
```

### GET /auth/me

- Auth requerida: `Authorization: Bearer TOKEN`.
- Body: no.
- Respuesta exitosa: `200`, user publico.
- Errores posibles: `401` token faltante/invalido.

```sh
curl http://localhost:3000/auth/me \
  -H "Authorization: Bearer TOKEN"
```

### POST /auth/logout

- Auth requerida: `Authorization: Bearer TOKEN`.
- Body: no.
- Respuesta exitosa: `200`.

```json
{
  "status": "ok",
  "message": "Logout handled client-side"
}
```

- Errores posibles: `401` token faltante/invalido.

```sh
curl -X POST http://localhost:3000/auth/logout \
  -H "Authorization: Bearer TOKEN"
```

## Player

### GET /player/me

- Auth requerida: `Authorization: Bearer TOKEN`.
- Body: no.
- Respuesta exitosa: `200`, user publico, profile y streak.
- Errores posibles: `401` token faltante/invalido, `500` error inesperado.

```sh
curl http://localhost:3000/player/me \
  -H "Authorization: Bearer TOKEN"
```

### GET /player/me/progress

- Auth requerida: `Authorization: Bearer TOKEN`.
- Body: no.
- Respuesta exitosa: `200`.
- Devuelve: `user`, `profile`, `streak`, `progress`, `completedNodes`, `unlockedContent`, `recentGameSessions`.
- Errores posibles: `401` token faltante/invalido, `500` error inesperado.

```sh
curl http://localhost:3000/player/me/progress \
  -H "Authorization: Bearer TOKEN"
```

### POST /player/me/progress

- Auth requerida: `Authorization: Bearer TOKEN`.
- Body:

```json
{
  "restriction": "CELIAQUIA",
  "expToAdd": 10,
  "nodeId": "demo_node_1",
  "gameType": "quiz",
  "accuracy": 90,
  "completed": true,
  "score": 100
}
```

- Respuesta exitosa: `201`, progreso actualizado y resumen.
- Errores posibles: `400` body invalido, `401` token faltante/invalido, `500` error inesperado.

```sh
curl -X POST http://localhost:3000/player/me/progress \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d "{\"restriction\":\"CELIAQUIA\",\"expToAdd\":10,\"nodeId\":\"demo_node_1\",\"gameType\":\"quiz\",\"accuracy\":90,\"completed\":true,\"score\":100}"
```

## Endpoints dev

### POST /dev/player-progress

Endpoint de validacion manual y compatibilidad de PoC. Para codigo nuevo, preferir `/player/me/progress`.

### GET /dev/player-progress/:username

Endpoint de lectura manual por username. Para integraciones futuras, preferir `/player/me/progress`.
