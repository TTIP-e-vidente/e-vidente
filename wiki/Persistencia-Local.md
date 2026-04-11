# Persistencia local

La persistencia local guarda perfil, progreso y el punto de reanudacion sin depender de un backend ni de servicios externos.

## Qué guarda

- Un perfil local por dispositivo, con nombre, edad, mail y avatar.
- La partida local actual y su punto exacto de reanudacion.
- Progreso por recorrido: celiaquia, veganismo, veganismo + celiaquia y keto.
- Historial reciente de eventos de guardado y avance.
- Metadata de escritura para saber cuándo se guardó y desde dónde se recuperó el save.

## Cómo se usa hoy

El flujo visible trabaja con una unica partida local retomable.

Desde Intro, el acceso a Jugar toma una decision directa: si hay una partida retomable, la reanuda; si no, abre Archivero. No hay selector de slots, multiples guardados expuestos en la UI ni un menu intermedio para elegir partidas.

Archivero muestra el perfil local, el resumen del avance y el estado del ultimo guardado. El guardado manual sigue disponible y el sistema tambien puede recuperar el save desde backup si el archivo principal queda corrupto.

## Piezas principales

- `SaveManager` como autoload central del perfil local, la partida activa, el guardado y la recuperacion.
- `auth.tscn` como editor del perfil local.
- `intro.tscn` como punto de entrada para retomar la ultima partida o abrir Archivero cuando todavia no hay avance guardado.
- `archivero.tscn` como resumen del perfil, el avance y el estado del guardado.
- `Global` para exportar e importar el progreso jugable.

Internamente, `SaveManager` proyecta la partida activa al runtime y en disco escribe un save principal, un archivo temporal y un backup.

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