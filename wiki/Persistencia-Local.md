# Persistencia local

La persistencia local guarda el perfil, el progreso y el punto de reanudación sin depender de un backend ni de servicios externos.

## Qué guarda

- Un perfil local por dispositivo, con nombre, edad, mail y avatar.
- La partida local actual y su punto exacto de reanudación.
- Progreso por recorrido: celiaquia, veganismo, veganismo + celiaquia y keto.
- Historial reciente de eventos de guardado y avance.
- Metadata de escritura para saber cuándo se guardó y desde dónde se recuperó el save.

## Cómo se usa hoy

El flujo visible se apoya en una única continuidad local retomable.

Hoy `Intro` no reanuda de forma directa. `Jugar` abre `selector.tscn`, que separa el modo recetas del modo preguntas. Dentro del flujo de recetas, `Archivero` muestra el perfil local, el resumen del avance, el estado del último guardado y el botón visible de retomar.

No hay selector de slots ni múltiples guardados expuestos en la UI. Internamente sí existe soporte para sesiones, pero esa complejidad no se expone como feature visible.

El guardado manual sigue disponible dentro del nivel, y el sistema puede recuperar el save desde backup si el archivo principal queda corrupto.

## Piezas principales

- `SaveManager` como autoload central del perfil local, la partida activa, el guardado y la recuperación.
- `auth.tscn` como editor del perfil local.
- `intro.tscn` como menú principal visible.
- `selector.tscn` como separación entre recetas y preguntas.
- `archivero.tscn` como resumen del perfil, el avance, el estado del guardado y el acceso visible a retomar.
- `Global` para exportar e importar el progreso jugable.

Internamente, `SaveManager` proyecta la partida activa sobre el runtime y mantiene en disco un save principal, un archivo temporal y un backup.

## Cómo se valida

La validación automática cubre tanto el formato del save como los flujos más sensibles:

- import headless del proyecto
- smoke test del guardado local
- validaciones de perfil, avatar y recarga desde disco
- contrato de señales de `SaveManager`
- migración desde saves legacy
- flujo de Intro, Selector, Archivero y guardado rápido dentro de nivel

Todo eso corre en el job `validate` de CI. El job `build-web` depende de que esa validación termine bien.

## Alcance actual

La persistencia sigue siendo local al dispositivo. No hay sincronización entre equipos ni cuentas remotas.