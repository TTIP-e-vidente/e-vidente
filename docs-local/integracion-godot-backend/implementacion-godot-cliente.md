# Implementacion Godot cliente

## Validacion con usuarios demo

Esta validacion usa usuarios locales creados por el setup de desarrollo. Las claves son solo para desarrollo local y no deben usarse en ambientes compartidos, QA remoto ni produccion.

### Preparar backend local

Desde `BACKEND/`:

```powershell
npm run setup:dev
npm run build
npm test
npm run dev
```

`npm run setup:dev` levanta PostgreSQL con Docker Compose, ejecuta migraciones y crea estos usuarios demo:

| Usuario | Password |
|---|---|
| `margo` | `123` |
| `agus` | `123` |

Para validar que existen y que la clave no esta guardada en claro:

```powershell
docker exec e-vidente-postgres psql -U evidente_user -d evidente_dev -c "SELECT username, mail, password_hash IS NOT NULL AS has_password, password_hash = '123' AS hash_is_plain_123 FROM users WHERE username IN ('margo', 'agus') ORDER BY username;"
```

Resultado esperado: ambos usuarios existen, `has_password` es `t` y `hash_is_plain_123` es `f`.

### Probar Login.tscn

Con el backend corriendo:

1. Abrir Godot con el proyecto `juego/`.
2. Abrir `res://project/auth/Login.tscn`.
3. Ejecutar la escena actual con F6.
4. Ingresar usuario `margo` y password `123`.
5. Hacer click en `Ingresar`.
6. Hacer click en `Probar sesion`.

Resultado esperado:

- Login OK.
- `GET /auth/me` OK.
- `BackendSession.is_logged_in()` queda en `true`.
- Si el backend esta apagado, la escena muestra error de login/auth sin crashear.
- `Login.tscn` no esta conectado al menu principal todavia.
- El token vive solo en memoria y no se guarda en disco.

### Probar partida real y sync

Con sesion activa en la misma ejecucion de Godot:

1. Cerrar o cambiar desde la escena de login sin cerrar el proceso de Godot.
2. Jugar una partida real de completar, vincular o pregunta.
3. Finalizar la actividad.

Resultado esperado:

- El guardado local ocurre primero.
- La navegacion a finalizacion ocurre normalmente.
- La sincronizacion backend corre en background.
- La UI no queda bloqueada.
- El gameplay y los saves locales siguen funcionando aunque el backend falle.

### Verificar PostgreSQL

Consultar ultimas sesiones:

```powershell
docker exec e-vidente-postgres psql -U evidente_user -d evidente_dev -c "SELECT game_type, node_id, score, accuracy, correct_answers, wrong_answers, duration_seconds, completed FROM game_sessions ORDER BY created_at DESC LIMIT 10;"
```

Consultar progreso agregado:

```powershell
docker exec e-vidente-postgres psql -U evidente_user -d evidente_dev -c "SELECT restriction_type, total_exp, completed_nodes_count, completed_games_count FROM player_progress ORDER BY updated_at DESC LIMIT 10;"
```

Las filas nuevas deben reflejar la partida recien jugada y el progreso del usuario autenticado.

## Login en flujo de entrada

`Login.tscn` aparece cuando el jugador presiona `Jugar` en el menu principal y no hay una sesion activa en `BackendSession`.

El login es opcional. La pantalla permite:

- `Ingresar`: inicia sesion con `BackendSession.login(...)`.
- `Crear cuenta demo`: registra una cuenta demo con `BackendSession.register(...)`.
- `Jugar sin iniciar sesion`: cierra el login y continua al mismo flujo de juego que usaba antes el boton `Jugar`.

Si ya existe una sesion activa en memoria, el menu no muestra login y entra directo al juego.

`Jugar sin iniciar sesion` mantiene el progreso local con `SaveManager` y no requiere backend. Si no hay sesion, al terminar una partida la sincronizacion backend sale silenciosamente y el juego sigue funcionando igual.

Si hay sesion activa, las partidas se sincronizan en background al finalizar. El token sigue viviendo solo en memoria y no se guarda en disco.

## Acceso a Mi progreso desde el menu

El menu principal muestra el boton `Mi progreso` junto a las acciones de entrada. Este acceso abre `res://project/player/Profile.tscn` como overlay cuando ya hay una sesion activa en `BackendSession`.

Si el jugador no inicio sesion, `Mi progreso` abre `res://project/auth/Login.tscn` como overlay. Despues de un login o registro demo exitoso, el login se cierra y se abre `Profile.tscn`.

El login sigue siendo opcional. Si el jugador elige `Jugar sin iniciar sesion` desde este flujo, el login se cierra y vuelve al menu principal sin abrir perfil ni bloquear la demo.

El progreso local se mantiene igual cuando no hay sesion. Con sesion activa, el perfil consulta progreso backend mediante `BackendSession.get_progress()` y las partidas finalizadas siguen sincronizando en background. Si el backend esta apagado, el jugador puede cerrar el login o jugar offline desde el flujo de `Jugar`; el backend no es obligatorio para jugar.
