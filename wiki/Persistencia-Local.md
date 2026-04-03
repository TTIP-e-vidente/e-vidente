# Persistencia Local

Resumen funcional de la persistencia local incorporada en e-vidente.

---

## Que agrega

La demo ahora guarda datos locales sin backend ni servicios externos.

Incluye:
- registro e inicio de sesion local
- guardado de usuario, mail, edad y avatar
- persistencia de progreso por recorrido
- historial de eventos del perfil
- guardado manual desde Archivero

---

## Flujo de uso

La persistencia local forma parte del recorrido normal del jugador.

Cuando no existe una sesion activa, el acceso se resuelve desde la pantalla de autenticacion. Luego del registro o inicio de sesion, el jugador entra al Archivero, donde puede consultar su perfil, el resumen de avance y el historial asociado a la cuenta local. A partir de ese momento, el progreso de los capitulos queda guardado en el dispositivo y se recupera cuando el jugador vuelve a ingresar.

---

## Piezas principales

- `SaveManager` como autoload para manejar sesion y persistencia
- `auth.tscn` para registro e inicio de sesion
- `archivero.tscn` como dashboard del perfil local
- `Global` para exportar e importar progreso de juego
- tests headless integrados en CI para evitar regresiones

---

## Como lo verificamos

La integracion se valida de dos maneras:

- import headless del proyecto Godot
- tests de smoke y validacion sobre registro, login, avatar, progreso y recarga desde disco

En CI eso corre dentro del job bloqueante `validate`, y `build-web` depende de ese resultado.

---

## Alcance y limite

La persistencia es local al dispositivo actual. No hay sincronizacion entre equipos ni backend asociado.