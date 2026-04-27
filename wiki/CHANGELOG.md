# 📜 CHANGELOG

Registro detallado de todos los cambios, PRs y decisiones técnicas.

**Para resúmenes ejecutivos**, ver [Bitácora](Bitacora.md).  
**Para decisiones arquitectónicas**, ver [ADR/](adr/).

---

## [Unreleased]

### 🎵 Audio

#### MusicManager Autoload
- **PR**: #17
- **Fecha**: 2026-04-27
- **Status**: ✅ Merged

**Cambios**:
- ✨ Nuevo: `managers/MusicManager.gd` - Gestor centralizado de música
- ✨ Detección automática de fin de pista (últimos 0.1s)
- ✨ Reinicio transparente sin interrupciones audibles
- ♻️ Refactor: Removidas referencias `$Background` en 7 escenas
- ♻️ Refactor: Eliminadas lógicas duplicadas de audio cleanup
- 📝 Agregada entrada en Bitácora
- 🔗 ADR-001: [MusicManager Centralizado](adr/ADR-001-MusicManager.md)

**API Nueva**:
```gdscript
MusicManager.reproducir_musica(ruta: String)
MusicManager.detener_musica(con_transicion: bool = true)
MusicManager.establecer_volumen(volumen_lineal: float)
MusicManager.pausar_musica() / reanudar_musica()
MusicManager.esta_reproduciendo() -> bool
MusicManager.obtener_musica_actual() -> String
```

**Escenas Actualizadas**:
- `Level.gd` - Niveles de gameplay
- `selector.gd` - Selector de modos
- `intro.gd` - Menú principal
- `libro.gd` - Vista de capítulos
- `Archivero.gd` - Archivero de perfiles
- `evidente.gd` - Splash screen
- `opciones.gd` - Pantalla de opciones

**Métricas**:
- 186 líneas agregadas (MusicManager.gd)
- 38 líneas removidas (código duplicado)
- 0 breaking changes
- 10 archivos modificados

---

## [v0.9.0] - 2026-04-23

### 🎨 UI & Gameplay

#### Racha Diaria y Flujo de Preguntas
- **PR**: #14
- **Fecha**: 2026-04-23

**Cambios**:
- 🎯 Simplificación de pantalla de racha
- 📝 Mensajes contextuales según estado del día
- ⚡ Quiz más fluido en flujo de mapa
- 🎨 Feedback visual inmediato al acertar
- 🔧 Eliminado overlay puntaje redundante `1/1`

**Archivos Modificados**:
- `interface/components/ProgressManagerRacha.gd` - Nueva lógica
- `preguntas/pregunta.gd` - Integración feedback
- `niveles/progress/GameStreakTracker.gd` - Mejoras estado

---

## [v0.8.0] - 2026-04-18

### 🗺️ Mapa & Visual Feedback

#### Mapa de Celiaquia con Estados Visuales
- **PR**: #13
- **Fecha**: 2026-04-18

**Cambios**:
- 🎨 3 estados visuales (completado/bloqueado/desbloqueado)
- 🖼️ Colores desde paleta centralizada `miPaleta.gd`
- ✅ Registro correcto de finalizaciones en Global y SaveManager
- 🔓 Desbloqueo automático de siguiente nodo
- 🔧 Fix: Referencia rota en `pregunta.gd`

**Lógica**:
```
Completado   → naranja tierra, sin click
Bloqueado    → translúcido, sin interacción
Desbloqueado → color normal, clickeable + hover + bounce
```

**Archivos**:
- `mapas/MapScene.gd` - Nueva lógica de estados
- `mapas/LevelNode.gd` - Renderizado visual
- `preguntas/pregunta.gd` - Fix de referencia
- `niveles/global.gd` - Integración de progreso

---

## [v0.7.0] - 2026-04-15

### ✨ Animaciones & Polish

#### Componentes Animados
- **PR**: #12
- **Fecha**: 2026-04-15

**Cambios**:
- 🎬 Transiciones suaves entre pantallas
- 🪀 Rebotes en botones interactivos
- 🌊 Movimientos sutiles en elementos del mapa
- ⏱️ Timing consistente (0.12-0.15s)

**Archivo**:
- `interface/evidente.gd` - Animaciones splash
- `niveles/selector.gd` - Animaciones botones
- Varios `.tscn` - Ajustes de duración

---

## [v0.6.0] - 2026-04-17

### 🏃 Racha Diaria

#### Sistema de Racha Implementado
- **PR**: #15
- **Fecha**: 2026-04-17

**Cambios**:
- 📊 Detector de actividad diaria (timestamps Unix)
- 🎯 Lógica: +1 si diferencia es exactamente 1 día, reset si >1
- 💾 Persistencia de contador + histórico
- 🎨 3 componentes visuales:
  - Badge HUD (color dinámico)
  - Sello decorativo en canvas
  - Overlay de 7 últimos días

**Archivos**:
- `niveles/progress/GameStreakTracker.gd` - Lógica core
- `interface/components/Racha.tscn` - Badge
- `interface/components/ProgressManagerRacha.tscn` - Overlay

**Algoritmo**:
```gdscript
diff_days = (today - last_activity_date) / 86400
if diff_days == 1: streak += 1
elif diff_days == 0: streak unchanged
else: streak = 1
```

---

## [v0.5.0] - 2026-04-14

### 🔧 CI & Smoke Tests

#### Smoke Test Vertical Slice & CI Refactor
- **PR**: #11
- **Fecha**: 2026-04-14

**Cambios**:
- ✅ Smoke gameplay: Intro → Selector → Archivero → Libro → Level
- 🔄 Import headless antes de smoke
- 🎨 Feedback visual guardado usa iconos raster (no SVG)
- 📊 CI split: Docs + Technical Health + Gameplay Smoke
- ⚠️ Eliminado: diff-aware, export web del gate, retries especiales

**Archivos CI**:
- `.github/workflows/docs-tracking.yml` - Nuevas docs
- `.github/workflows/technical-health.yml` - Validación core
- `.github/workflows/gameplay-smoke.yml` - Smoke test

---

## [v0.4.0] - 2026-04-06

### 💾 Quick Save & Godot 4.6.2

#### Guardado Parcial por Nivel & Upgrade Godot
- **PR**: #8
- **Fecha**: 2026-04-06

**Cambios**:
- 💾 Quick save per track/chapter con restauración de alimentos
- 📝 UI tarjeta contenida en escena
- ✅ Suite headless valida quick save (celiaquia, veganismo, mixto)
- 🔄 Upgrade: Godot 4.6.2 + Docker image `barichello/godot-ci:4.6.2`

**Archivos**:
- `interface/SaveManager.gd` - Lógica quick save
- `niveles/nivel_1/Level.gd` - UI integrada
- `tests/level_quick_save_test.gd` - Validación headless

---

## [v0.3.0] - 2026-04-04

### 🎮 Multi-Partida Local

#### Sistema de Persistencia Multi-Sesión
- **PR**: #5
- **Fecha**: 2026-04-04

**Cambios**:
- 📂 Modelo: `profile`, `progress`, `history`, `resume_state`, `save_meta`
- 🔄 Compatibilidad: Normalización de payloads legacy
- 🎮 UI: Resume última sesión desde Intro
- 📊 Archivero: Muestra sesión activa

**Estructura**:
```
interface/save_local/
├── data/ (Normalización legacy)
├── progress/ (Sesiones & historial)
└── persistence/ (I/O a disco)
```

**Archivos**:
- `interface/SaveManager.gd` - Fachada pública
- `interface/Archivero.gd` - Visualización

---

## [v0.2.0] - 2026-04-02

### 🔐 Save Local & CI

#### Persistencia de Usuario + GitHub Actions
- **PR**: #2, #3, #4
- **Fecha**: 2026-04-02

**Cambios**:
- 👤 Perfil de usuario (nombre, email, avatar)
- 📊 Progreso y historial
- 🔑 Registro local seguro
- 🔄 Headless import en CI
- 🧪 Tests de guardado

**Archivos Creados**:
- `interface/SaveManager.gd` - Core persistencia
- `interface/auth.tscn` - Registro
- `.github/workflows/` - CI setup

---

## [v0.1.0] - 2026-03-31

### 🚀 Inicial

#### Project Setup & Wiki
- **PR**: #1
- **Fecha**: 2026-03-31

**Cambios**:
- 📦 Godot 4.6.2 project initialized
- 📚 Wiki técnica estructurada
- 🔧 Configuración base CI/CD
- 📋 Getting Started guide

**Stack**:
- Godot 4.6.2
- GDScript
- GitHub Actions
- Docker CI

---

## Convenciones

### Tags
- `🎵` Audio
- `🎨` UI & Visual
- `🎮` Gameplay & Mechanics
- `💾` Persistencia & Save
- `🔧` Infraestructura & CI
- `🐛` Bug Fixes
- `📚` Documentation
- `♻️` Refactoring
- `✨` Nuevas features
- `⚠️` Breaking changes

### Estatus
- ✅ Merged/Completado
- 🔄 In Progress
- 🚧 Draft/WIP
- ⏸️ On Hold
- ❌ Rejected/Reverted

---

## Índice por Sistema

### Audio
- [v0.9.1] MusicManager (#17)

### UI & Animation
- [v0.7.0] Componentes Animados (#12)
- [v0.6.0] Racha Diaria (#15)
- [v0.5.0] Racha & Preguntas (#14)

### Gameplay
- [v0.8.0] Mapa Celiaquia (#13)

### Persistencia
- [v0.4.0] Quick Save (#8)
- [v0.3.0] Multi-Partida (#5)
- [v0.2.0] Save Local (#2)

### Infraestructura
- [v0.5.0] CI Refactor (#11)
- [v0.2.0] CI Initial (#1)

---

## Links Útiles

- [Bitácora Ejecutiva](Bitacora.md) - Resúmenes de 3 líneas
- [Architecture Decisions](adr/) - Decisiones importantes
- [Architecture Guide](Architecture.md) - Visual del proyecto
- [Getting Started](Getting-Started.md) - Para nuevos devs
