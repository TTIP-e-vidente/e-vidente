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
- `PASSWORD_RESET_TOKEN_EXPIRES_MINUTES`

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

### POST /auth/forgot-password

- Auth requerida: no.
- Body:

```json
{
  "mail": "agus@test.com"
}
```

- Respuesta exitosa: `200`.
- Siempre devuelve un mensaje generico para no revelar si la cuenta existe.
- Si el mail existe en `users.mail` o `users.email`, se genera un token seguro y se guarda su hash en `password_reset_tokens`.
- En `NODE_ENV !== "production"` puede devolver `devResetToken` para pruebas locales.
- En production no devuelve el token.
- No hay envio real de email en esta PoC.

```json
{
  "status": "ok",
  "message": "If an account exists for that mail, password reset instructions were generated.",
  "devResetToken": "..."
}
```

- Errores posibles: `400` mail faltante/invalido, `500` error inesperado.

```sh
curl -X POST http://localhost:3000/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d "{\"mail\":\"agus@test.com\"}"
```

### POST /auth/reset-password

- Auth requerida: no.
- Body:

```json
{
  "token": "token_recibido",
  "newPassword": "NewPassword123"
}
```

- Respuesta exitosa: `200`.
- El token debe existir, no estar usado y no estar expirado.
- Al actualizar la password, el backend marca el token como usado e invalida otros tokens activos del usuario.

```json
{
  "status": "ok",
  "message": "Password updated"
}
```

- Errores posibles: `400` body invalido o token invalido/expirado, `500` error inesperado.

```sh
curl -X POST http://localhost:3000/auth/reset-password \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"TOKEN\",\"newPassword\":\"NewPassword123\"}"
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
  "clientRunId": "run_20260602T150000_12345",
  "restriction": "CELIAQUIA",
  "expToAdd": 10,
  "nodeId": "demo_node_1",
  "gameType": "quiz",
  "accuracy": 90,
  "completed": true,
  "score": 100,
  "correctAnswers": 17,
  "wrongAnswers": 3,
  "durationSeconds": 90,
  "finishedAt": "2026-06-02T15:00:00.000Z"
}
```

- Campos opcionales: `clientRunId`, `correctAnswers`, `wrongAnswers`, `durationSeconds`, `finishedAt`.
- `clientRunId`: id unico generado por Godot para una partida local. Si se repite bajo el mismo progreso, el backend responde con el progreso actual sin duplicar `game_sessions`, EXP, `completed_games_count` ni nodos completados.
- `correctAnswers`, `wrongAnswers`, `durationSeconds`: deben ser `>= 0` si se envían.
- `finishedAt`: fecha ISO 8601. El backend mantiene además `completed_at` como timestamp de servidor.
- `completed_games_count` solo incrementa si `completed: true`.
- Si el nodo ya fue completado antes (`nodeId` repetido), `best_score` y `best_accuracy` se actualizan si el nuevo valor es mayor (no se bajan).
- Respuesta exitosa: `201`, progreso actualizado y resumen.
- Errores posibles: `400` body invalido, `401` token faltante/invalido, `500` error inesperado.

```sh
curl -X POST http://localhost:3000/player/me/progress \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d "{\"clientRunId\":\"run_demo_1\",\"restriction\":\"CELIAQUIA\",\"expToAdd\":10,\"nodeId\":\"demo_node_1\",\"gameType\":\"quiz\",\"accuracy\":90,\"completed\":true,\"score\":100}"
```

## Endpoints dev

### POST /dev/player-progress

Endpoint de validacion manual y compatibilidad de PoC. Para codigo nuevo, preferir `/player/me/progress`.

### GET /dev/player-progress/:username

Endpoint de lectura manual por username. Para integraciones futuras, preferir `/player/me/progress`.
