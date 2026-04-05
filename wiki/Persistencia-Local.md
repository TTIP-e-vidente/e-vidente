# Persistencia local

La persistencia local guarda perfil, progreso y partidas sin depender de un backend ni de servicios externos.

## Qué guarda

- Un perfil local por dispositivo, con nombre, edad, mail y avatar.
- Varias partidas dentro de ese perfil.
- Progreso por recorrido.
- El punto exacto desde el que conviene retomar.
- Historial reciente de eventos de guardado y avance.
- Metadata de escritura para saber cuándo se guardó y desde dónde se recuperó el save.

## Cómo se usa hoy

El juego trabaja con un perfil local único, pero ya no con una sola partida.

Desde Intro se puede empezar una partida nueva o cargar una ya existente. Cada partida conserva su propio progreso, su historial y su `resume_state`. Eso permite volver a un punto anterior sin pisar el avance de otra sesión.

Archivero muestra el perfil local, el resumen de la partida activa y el estado del último guardado. El guardado manual sigue disponible y el sistema también puede recuperar el save desde backup si el archivo principal queda corrupto.

## Piezas principales

- `SaveManager` como autoload central de perfil, slots, guardado y recuperación.
- `auth.tscn` como editor del perfil local.
- `intro.tscn` como punto de entrada para crear o cargar partidas.
- `archivero.tscn` como resumen del perfil y de la sesión activa.
- `Global` para exportar e importar el progreso jugable.

Internamente, `SaveManager` mantiene una sesión activa proyectada al runtime para no obligar al resto del juego a conocer el formato interno de slots. En disco se escribe un save principal, un archivo temporal y un backup.

## Cómo se valida

La validación automática cubre tanto el formato del save como los flujos más sensibles:

- import headless del proyecto
- smoke test del guardado local
- validaciones de perfil, avatar y recarga desde disco
- contrato de señales de `SaveManager`
- migración desde saves legacy
- flujo de Archivero, Intro y guardado rápido dentro de nivel

Todo eso corre en el job `validate` de CI. El job `build-web` depende de que esa validación termine bien.

## Alcance actual

La persistencia sigue siendo local al dispositivo. No hay sincronización entre equipos ni cuentas remotas.