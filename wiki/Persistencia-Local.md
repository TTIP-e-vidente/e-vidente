# Persistencia Local

Resumen funcional de la persistencia local incorporada en e-vidente.

---

## Que agrega

La demo ahora guarda datos locales sin backend ni servicios externos.

Incluye:
- perfil local unico por dispositivo
- guardado de usuario, mail, edad y avatar
- persistencia de progreso por recorrido
- historial de eventos del perfil
- guardado manual desde Archivero

---

## Flujo de uso

La persistencia local forma parte del recorrido normal del jugador.

El jugador entra directo al Archivero. Ahi puede consultar el perfil local, el resumen de avance y el historial asociado al dispositivo actual. Si necesita completar nombre, edad, mail o avatar, puede abrir el editor de perfil local. El progreso de los capitulos queda guardado en el dispositivo y se recupera automaticamente cuando vuelve a abrir el juego.

---

## Piezas principales

- `SaveManager` como autoload para manejar perfil local y persistencia
- `auth.tscn` reutilizada como editor de perfil local
- `archivero.tscn` como dashboard del perfil local
- `Global` para exportar e importar progreso de juego
- tests headless integrados en CI para evitar regresiones de perfil, avatar, progreso y recarga desde disco

---

## Como lo verificamos

La integracion se valida de dos maneras:

- import headless del proyecto Godot
- tests de smoke y validacion sobre perfil local, avatar, progreso y recarga desde disco

En CI eso corre dentro del job bloqueante `validate`, y `build-web` depende de ese resultado.

---

## Alcance y limite

La persistencia es local al dispositivo actual. No hay sincronizacion entre equipos ni backend asociado.