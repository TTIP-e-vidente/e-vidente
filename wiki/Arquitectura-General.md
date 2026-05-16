# Cómo Funciona E-VIDENTE

Te mostramos visualmente cómo está armado el proyecto, dónde vive cada cosa importante, y cómo todo se conecta.


> Si necesitás saber qué cambió últimamente, mirá [Bitacora.md](Bitacora.md).

---

## El Flujo en 2 Minutos

Así funciona el juego desde que lo abrís:

1. Primero ves el splash (la pantalla de bienvenida con el logo animado)
2. Después el menú principal
3. Elegís qué querés hacer: jugar, ver como jugar, salir
4. Si jugás, apareceran una lista de restricciones alimenticias, la cual deberas elegir alguna y entras a un mapa donde existen partidas disponibles para jugar
5. Al terminar, se guarda todo el progreso en el disco y podras observar la suma de experiencia y la activacion de la racha

---

## Dónde Vive Cada Cosa

Versión corta para ubicarte rápido:

| Área | Componentes principales | Para qué sirve |
|---|---|---|
| Entrada y Menú | `interface/evidente.gd`, `interface/intro.gd`, `niveles/selector.gd` | Arranque y navegación inicial |
| Progreso y Guardado | `interface/SaveManager.gd`, `niveles/global.gd`, `interface/save_local/*` | Guardar, recuperar y consultar avance |
| Gameplay | `niveles/nivel_1/Level.gd`, `niveles/manager_level.gd`, `niveles/mechanics/*` | Flujo jugable y lógica de mecánicas |
| Preguntas | `preguntas/pregunta.gd`, `preguntas/QuestionJsonLoader.gd` | Modalidad `quiz_choice` |
| Contenido de nodos | `contenido/nodos/*.json`, `sistemas/contenido/CargadorDeContenidoDeNodo.gd` | Contenido de nivel y nodos jugables por JSON |
| Mapa | `mapas/MapScene.gd`, `mapas/LevelNode.gd`, `mapas/MapNodeData.gd` | Navegación visual por capítulos |
| Audio | `managers/MusicManager.gd` | Música de fondo y continuidad |
| UI de progreso | `interface/components/Racha.tscn`, `interface/components/ProgressManagerRacha.gd` | Feedback de racha y estado |

---

## Los 6 Sistemas Clave

### Audio - Música Centralizada

**Dónde**: `managers/MusicManager.gd`
**Qué hace**: Un solo gestor que maneja toda la música del juego. Cuando termina una canción, la reinicia automáticamente. Sin silencios incómodos en sesiones largas.

**Lo importante**:
- Música se reinicia sola
- Controlás volumen desde un lugar
- Transiciones suaves

[Resumen del cambio](Bitacora.md#lo-que-pasó-recientemente)

---

### Persistencia - Dónde Guardamos Todo

**Dónde**: `interface/SaveManager.gd`
**Qué hace**: Punto único por donde pasa TODO lo que guardamos. Perfil, progreso, historial.

**Lo importante**:
- Un solo lugar para guardar

[Deep dive del guardado](Persistencia-Local.md)

---

### Navegación - El Control de Tráfico

**Dónde**: `niveles/GameSceneRouter.gd`
**Qué hace**: Hub central que maneja TODOS los cambios entre pantallas. Todo pasa por aquí.

**Lo importante**:
- Un solo lugar para entender la navegación
- Más fácil debuggear si algo falla
- Distribuye el contexto entre pantallas

---

### Racha Diaria

**Dónde**: `niveles/progress/GameStreakTracker.gd`
**Qué hace**: Lógica de la racha. Si jugás hoy sube +1. Si pasó más de un día, se reinicia.

**Lo importante**:
- Usa timestamps Unix para precisión
- Lógica simple pero poderosa
- Fácil de testear

**La regla**:
```
días_pasados = (hoy - última_fecha) / 86400
if días_pasados == 1: racha += 1
if días_pasados == 0: racha se mantiene
if días_pasados > 1: racha = 1
```

---

### Alimentos - Propiedades Centralizadas

**Dónde**: `items/*.tres`
**Qué hace**: Cada alimento es un archivo con sus propiedades. Gluten sí/no, vegano sí/no, etc.

**Lo importante**:
- Una sola fuente de verdad por alimento
- Fácil agregar más
- La lógica los lee dinámicamente

**Qué guardan**:
- Condiciones (restricciones)
- Tracks permitidos
- Nombre, descripción, imagen

---

### Paleta de Colores - Un Solo Lugar

**Dónde**: `colours/miPaleta.gd`
**Qué hace**: Todos los colores de la app en un archivo. Cambias acá y cambian en todo.

**Lo importante**:
- Consistencia en todo
- Si necesitás naranja, buscás 1 solo lugar
- DRY (Don't Repeat Yourself)

**Cómo se usa**:
```gdscript
var color = miPaleta.naranja_tierra
self.modulate = color
```

---

## Otros Docs

| Doc | Qué Es | Cuándo |
|---|---|---|
| [Home.md](Home.md) | Índice | Primero |
| [Como-Empezar.md](Como-Empezar.md) | Setup | Primera vez |
| [Modelo-Entidad-Relacion.md](Modelo-Entidad-Relacion.md) | MER lógico editable | Entrega TTIP |
| [Persistencia-Local.md](Persistencia-Local.md) | Deep dive | Trabajando con saves |
| [CI.md](CI.md) | Validaciones | Cuando falla un check |
| [Bitacora.md](Bitacora.md) | Historial | Buscando "cuándo cambió X" |

---
