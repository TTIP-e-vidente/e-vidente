# Persistencia local

La persistencia local guarda perfil, progreso y la sesion activa sin depender de un backend ni de servicios externos.

## Qué guarda

- Un perfil local por dispositivo, con nombre, edad, mail y avatar.
- La sesion activa, con soporte interno para separar partidas por perfil.
- Progreso por recorrido.
- El punto exacto desde el que conviene retomar.
- Historial reciente de eventos de guardado y avance.
- Metadata de escritura para saber cuándo se guardó y desde dónde se recuperó el save.

## Cómo se usa hoy

El juego trabaja con un perfil local único y hoy expone una sesion activa para continuar desde Intro.

Desde Intro se puede retomar la ultima sesion guardada o entrar al selector de modos. Internamente el formato de save ya separa sesiones, pero esa seleccion multiple todavia no forma parte del flujo visible para la jugadora o el jugador.

Archivero muestra el perfil local, el resumen de la sesion activa y el estado del ultimo guardado. El guardado manual sigue disponible y el sistema tambien puede recuperar el save desde backup si el archivo principal queda corrupto.

## Piezas principales

- `SaveManager` como autoload central de perfil, sesion activa, slots internos, guardado y recuperacion.
- `auth.tscn` como editor del perfil local.
- `intro.tscn` como punto de entrada para continuar la ultima sesion o ir al selector de modos.
- `archivero.tscn` como resumen del perfil y de la sesion activa.
- `Global` para exportar e importar el progreso jugable.

Internamente, `SaveManager` mantiene una sesion activa proyectada al runtime para no obligar al resto del juego a conocer el formato interno de slots. En disco se escribe un save principal, un archivo temporal y un backup.

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