# 📋 Bitácora

Cambios importantes que anotamos para no perder de vista.

> Para decisiones grandes de arquitectura, mirá [adr/](adr/).

---

## Navegación Central por Etapas

Si querés contar la evolución del proyecto sin perderte, usá este índice:

- [Pre-POC (archivo histórico)](Pre-POC.md)
- [Entrega 1 (etapa actual)](#entrega-1)
- [Otras etapas (detalle técnico)](#otras-etapas)

Esta estructura está pensada para exposición: el histórico previo vive en Pre-POC y la Bitácora queda enfocada en entregas y mejoras del trabajo actual.

---

## Lo Que Pasó Recientemente

### [📦 CONTENIDO] 2026-05-05 | Partida por nodo — nodos con múltiples juegos internos

Se implementó el soporte para que cada nodo del mapa represente una "partida" compuesta por uno o varios juegos internos (por ejemplo: arrastre + pregunta). El objetivo es definir el comportamiento desde JSON y mantener el flujo de juego limpio y reutilizable.

Qué se implementó:
- `PlanDePartidaDeNodo`: arma la lista de `juegos` para un nodo (modo, `json_path`, dificultad, título, etc.) y aplica reglas de selección y alternancia.
- `PlayableNodeRouter` + `Global`: orquestan la sesión jugable y la `partida_de_nodo` activa; `Global` expone APIs para consultar y avanzar la partida (`iniciar_partida_de_nodo`, `obtener_juego_actual_de_partida`, `avanzar_partida_de_nodo`, `finalizar_partida_de_nodo`, `hay_siguiente_juego_de_partida`).
- `ManagerLevel`: ahora puede inicializar el runtime desde JSON de tipo `drag_drop` y construye un `active_run_data` mínimo (payload, `positive_count`, `negative_count`, `category`) para que el nivel consuma metadatos cuando procede del contenido.
- Documentación: nueva página explicativa en [wiki/Partida-por-nodo.md](wiki/Partida-por-nodo.md) con flujo, archivos clave y pasos de verificación manual.

Impacto y siguientes pasos:
- Permite definir nodos con múltiples juegos directamente desde los JSON en `project/contenido/nodos`.
- El flujo mínimo Splash → Intro → Selector → Mapa → Gameplay queda soportado desde contenido JSON; recomendamos ejecutar la validación headless (CI) para verificar la integración completa.
- No se modificaron contratos JSON ni la UI visual; el soporte es compatible con adaptadores legacy (`NodeContentLegacy` / `NodeContentLoader`).

---

### [📦 CONTENIDO] 2026-04-29 | Contenido desacoplado de nodos (JSON)

Logramos separar por completo el contenido de los desafíos de la lógica del mapa. Ahora, los nodos funcionan de forma dinámica mediante archivos JSON independientes, lo que nos permite sumar niveles y temáticas sin tocar una sola línea de código. Ya dejamos integrados los primeros 9 desafíos de celiaquía (quizzes y actividades de arrastrar)

### [🎵 AUDIO] 2026-04-27 | Música loop en sesiones prolongadas
Gestor centralizado `MusicManager` que reinicia automáticamente la música al terminar. 
Actualiza 7 escenas y centraliza control de volumen y transiciones. Sin silencios en sesiones prolongadas.

---

## Organizado por Categoría

### 🎵 Audio
- **2026-04-27** - **Música en Loop** - Reproducción continua en sesiones prolongadas.

### 🎨 UI & Animaciones
- **2026-04-23** - **Racha y Preguntas** - Flujo más corto y más claro.
- **2026-04-15** - **Componentes Animados** - Transiciones y rebotes para mejorar la respuesta visual.

### 🎮 Gameplay & Mapa
- **2026-04-18** - **Mapa Celiaquia** - Feedback visual de estados.
- **2026-04-17** - **Racha Diaria** - Sistema de rachas.

### 💾 Persistencia
- **2026-04-06** - **Quick Save** - Guardado parcial por nivel.
- **2026-04-04** - **Multi-Partida** - Sistema multi-sesión.
- **2026-04-02** - **Save Local** - Persistencia inicial.

### 🔧 Infraestructura
- **2026-04-29** - **Contenido JSON desacoplado** - Nodos jugables cargan contenido desde JSON. Soporte quiz_choice y drag_drop. Errores controlados.
- **2026-04-14** - **CI Split** - Workflows organizados.
- **2026-04-02** - **CI Setup** - GitHub Actions inicial.

---

## Historial Completo

### Nota

Todo el historial anterior al POC se movió a [Pre-POC.md](Pre-POC.md) para mantener esta bitácora enfocada en la etapa actual.

### Entrega 1

#### 2026-04-02 | save-local/ci
Se agregó persistencia local de usuario con registro, avatar, historial y progreso. La CI pasó a importar el proyecto en headless y a correr pruebas de guardado antes del build web.

#### 2026-04-04 | persistencia local multi-partida
La persistencia dejó de depender de un único save implícito. El formato ahora soporta varias sesiones por perfil, aunque la UI actual expone continuar la sesión más reciente desde Intro. Archivero muestra la sesión activa y la suite headless cubre ese flujo visible más la base interna de slots.

#### 2026-04-06 | guardado parcial niveles/ci-4.6.2
Se agregó guardado parcial por track y capítulo para restaurar alimentos correctos ya colocados en el plato. La UI del guardado rápido pasó a una tarjeta contenida dentro de la escena y la suite headless ahora valida quick save para celiquía, veganismo y veganismo-celiaquía. También se alineó la CI y el build web con Godot 4.6.2, incluyendo la imagen Docker correcta `barichello/godot-ci:4.6.2`.

#### 2026-04-08 | quick-save/ci-push-branches
Se endureció la serialización del quick save parcial para tolerar mejor estados `mechanic_state` vacíos y seguir restaurando desde los campos de compatibilidad. Además la CI principal pasó a correr en cada push de branch y se forzó la ejecución de acciones JavaScript con Node 24 para adelantarse a la deprecación de Node 20.

### Otras etapas

El detalle de **Entrega 2** y **Mejoras posteriores** se puede mantener en esta misma bitácora cuando lo necesiten, pero por ahora la dejamos enfocada en lo que corresponde a Entrega 1.

