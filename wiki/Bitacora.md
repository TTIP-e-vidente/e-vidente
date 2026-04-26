# Bitacora

Registro breve de cambios y decisiones que conviene no perder.

## Entradas

### 2026-04-23 | racha-y-preguntas-flujo-corto
Se acomodaron dos partes del juego que estaban quedando medio ásperas de usar. Por un lado, la pantalla de racha se simplificó bastante por dentro para que el código sea más fácil de seguir y, del lado visible, pasó a mostrar mensajes más humanos según el día de la racha en lugar de textos tan genéricos. También quedó más claro que la progresión de racha que se ve después de completar un nivel forma parte del flujo de post-partida y no de un sistema aparte.

Por otro lado, el flujo de preguntas se volvió más corto y más lógico para el caso del mapa. Ahora, cuando la pregunta viene como sesión de una sola pregunta, la pantalla da feedback, reproduce un sonido al acertar y vuelve sin mostrar un overlay de puntaje tipo `1/1` que no sumaba nada. También se agregó un guard en un componente `@tool` del perfil para que el editor no intente usar `SaveManager` como placeholder y no aparezca ese error molesto al abrir escenas.

### 2026-04-18 | mapa-celiaquia-feedback-visual
Se implementó el mapa de Celiaquia como escena jugable y, sobre esa base, se agregó feedback visual para que el jugador pueda distinguir de un vistazo qué capítulos ya completó, cuáles tiene disponibles y cuáles todavía están bloqueados. Cada nodo del mapa ahora se pinta según su estado: naranja tierra cuando está completado, translúcido cuando está bloqueado y sin cambio cuando está desbloqueado pero pendiente. Los nodos completados además dejan de responder al click y al hover, así el jugador sabe que ahí ya no hay nada por hacer.

Del lado de la lógica, el modo preguntas no estaba registrando la finalización del capítulo. Se corrigió para que al terminar el quiz se marque el nivel como completado en Global y SaveManager y se desbloquee el siguiente nodo en LevelManager. También se arregló una referencia rota en la escena de preguntas que apuntaba a un script viejo que ya no existía.

Los colores vienen de la paleta del proyecto (`miPaleta.gd`), así que si más adelante se quiere cambiar el tono es cuestión de tocar un solo lugar. Esto queda implementado solo para el mapa de Celiaquia; los otros recorridos todavía no tienen mapa propio.

### 2026-04-15 | animaciones-componentes
Se sumaron animaciones a varios componentes de la interfaz para que la aplicación se sienta más viva y menos estática. Cosas como transiciones al pasar entre pantallas, pequeños rebotes al tocar botones y movimientos sutiles en los elementos del mapa. Nada que cambie la lógica del juego, pero le da otra sensación al usarlo. La idea fue que cada interacción tenga un mínimo de respuesta visual para que el jugador sienta que la app le está respondiendo.

### 2026-04-17 | racha-player
Se agregó un sistema de racha diaria. La idea es simple: cada vez que el jugador completa un nivel, se registra la fecha. Al día siguiente, si vuelve a jugar, la racha sube; si se saltea un día, vuelve a 1; si juega dos veces el mismo día, se mantiene igual.

El algoritmo compara la fecha de la última actividad con la de hoy usando timestamps Unix: si la diferencia es exactamente 1 día suma, si es 0 no cambia, cualquier otra cosa resetea. Guarda el contador actual y el mejor histórico en el estado de progreso existente.

Del lado visual hay tres componentes nuevos: un badge en el HUD que muestra el contador y cambia de color según el estado (sin racha / racha pendiente hoy / racha activa hoy), un sello decorativo dibujado en canvas, y un overlay que aparece al completar un nivel mostrando los últimos 7 días con círculos coloreados.

### 2026-04-14 | gameplay-smoke-cold-start
El smoke de gameplay estaba dando falsos negativos en GitHub Actions cuando corria sobre un checkout limpio sin import previo. El flujo jugable no estaba roto; el problema venia de recursos importados y de carga de UI no critica demasiado fragil para headless en cold start. Se ajusto la validacion para hacer import headless antes del vertical slice y el feedback visual de guardado rapido paso a usar iconos raster ya presentes en el repo para no depender de SVG en runtime.

### 2026-04-14 | ci-split-docs-technical-smoke
Reordenamos la CI para dejarla mas simple y mas facil de leer. La parte obligatoria quedo separada en tres workflows chicos: `Docs / Tracking` para PR, `Technical Health` para push y `Gameplay Smoke` para PR. Tambien sacamos el workflow compartido, para que cada pipeline tenga una responsabilidad clara. El check de documentacion ahora pide un cambio en Markdown mas una entrada en bitacora o changelog, la validacion tecnica quedo enfocada en estructura critica + import headless, y el smoke reutiliza el flujo baseline que ya existia para comprobar que el slice llega a gameplay sin crashear.

### 2026-04-13 | pages-web-deploy
Se dejo el export web separado del gate obligatorio. El preset `index` sigue apuntando a `build/web/`, pero este repo no versiona un workflow dedicado de GitHub Pages. La CI principal sigue cuidando estructura y slice jugable; cualquier publicacion web queda desacoplada hasta que exista ese pipeline real.

### 2026-04-13 | ci-baseline-vertical-slice
Le bajamos bastante el peso a la CI para dejar una base mas confiable en esta etapa. Se mantuvieron los wrappers de push y PR, pero el workflow compartido quedo en solo dos checks obligatorios: `Guardrails` y `Core Validation`. Del gate salieron el diff-aware, el cache de `.godot`, los retries especiales, el export web y la bateria de tests finos de save/UI.

La validacion funcional obligatoria ahora corre siempre la misma suite corta: import headless, validacion del catalogo y un smoke test vertical slice (`Intro -> Selector -> Archivero -> Libro -> Level`). Ese smoke quedo atado a un track baseline explicito para bajar fragilidad y tener una referencia clara de la demo jugable que hoy queremos cuidar.

### 2026-04-08 | quick-save/ci-push-branches
Se endurecio la serializacion del quick save parcial para tolerar mejor estados `mechanic_state` vacios y seguir restaurando desde los campos de compatibilidad. Ademas la CI principal paso a correr en cada push de branch y se forzo la ejecucion de acciones JavaScript con Node 24 para adelantarse a la deprecacion de Node 20.

### 2026-04-06 | guardado parcial niveles/ci-4.6.2
Se agrego guardado parcial por track y capitulo para restaurar alimentos correctos ya colocados en el plato. La UI del guardado rapido paso a una tarjeta contenida dentro de la escena y la suite headless ahora valida quick save para celiquia, veganismo y veganismo_celiaquia. Tambien se alineo la CI y el build web con Godot 4.6.2, incluyendo la imagen Docker correcta `barichello/godot-ci:4.6.2`.

### 2026-04-04 | persistencia local multi-partida
La persistencia dejo de depender de un unico save implicito. El formato ahora soporta varias sesiones por perfil, aunque la UI actual expone continuar la sesion mas reciente desde Intro. Archivero muestra la sesion activa y la suite headless cubre ese flujo visible mas la base interna de slots.

### 2026-04-02 | save-local/ci
Se agregó persistencia local de usuario con registro, avatar, historial y progreso. La CI pasó a importar el proyecto en headless y a correr pruebas de guardado antes del build web.

### 2026-03-31 | ci/docs
Se ordenó la wiki técnica y el workflow de CI. El deploy a GitHub Pages salió del pipeline y el build web quedó como artifact.

