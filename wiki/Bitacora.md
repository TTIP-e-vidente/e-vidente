# Bitacora

Registro breve de cambios y decisiones que conviene no perder.

## Entradas

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

