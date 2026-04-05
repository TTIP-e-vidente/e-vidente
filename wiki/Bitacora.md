# Bitacora

Registro breve de cambios y decisiones que conviene no perder.

## Entradas

### 2026-04-04 | persistencia local multi-partida
La persistencia dejó de depender de un único save implícito. Ahora cada perfil local puede tener varias partidas, Intro permite crear o cargar sesiones separadas, Archivero muestra la partida activa y la suite headless cubre ese flujo.

### 2026-04-02 | save-local/ci
Se agregó persistencia local de usuario con registro, avatar, historial y progreso. La CI pasó a importar el proyecto en headless y a correr pruebas de guardado antes del build web.

### 2026-03-31 | ci/docs
Se ordenó la wiki técnica y el workflow de CI. El deploy a GitHub Pages salió del pipeline y el build web quedó como artifact.

