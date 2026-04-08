# Bitacora

Registro breve de cambios y decisiones que conviene no perder.

## Entradas

### 2026-04-06 | guardado parcial niveles/ci-4.6.2
Se agrego guardado parcial por track y capitulo para restaurar alimentos correctos ya colocados en el plato. La UI del guardado rapido paso a una tarjeta contenida dentro de la escena y la suite headless ahora valida quick save para celiquia, veganismo y veganismo_celiaquia. Tambien se alineo la CI y el build web con Godot 4.6.2, incluyendo la imagen Docker correcta `barichello/godot-ci:4.6.2`.

### 2026-04-04 | persistencia local multi-partida
La persistencia dejo de depender de un unico save implicito. El formato ahora soporta varias sesiones por perfil, aunque la UI actual expone continuar la sesion mas reciente desde Intro. Archivero muestra la sesion activa y la suite headless cubre ese flujo visible mas la base interna de slots.

### 2026-04-02 | save-local/ci
Se agregó persistencia local de usuario con registro, avatar, historial y progreso. La CI pasó a importar el proyecto en headless y a correr pruebas de guardado antes del build web.

### 2026-03-31 | ci/docs
Se ordenó la wiki técnica y el workflow de CI. El deploy a GitHub Pages salió del pipeline y el build web quedó como artifact.

