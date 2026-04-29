# 🎮 E-VIDENTE Docs

Hey, bienvenido. Acá encontrás todo lo que necesitás saber del proyecto.

> 🎓 **E-VIDENTE** es un juego educativo sobre alimentación. Tenés 4 recorridos jugables (celiaquia, veganismo, mixto, keto) y un modo preguntas para reforzar.

---

## Buscás algo específico?

| Necesito... | Andá a... |
|---|---|
| 🎬 Ver cómo funciona el proyecto | [Architecture.md](Architecture.md) - El tour visual |
| 🆕 Levantar el proyecto en tu PC | [Getting-Started.md](Getting-Started.md) |
| 🔍 Saber qué cambió en los últimos días | [Bitacora.md](Bitacora.md) - Resúmenes cortos |
| 🗂️ Ver histórico anterior al POC | [Pre-POC.md](Pre-POC.md) |
| 💾 Entender cómo funciona el guardado | [Persistencia-Local.md](Persistencia-Local.md) |
| 🧩 Cargar nodos desde JSON | [Contenido-JSON-Nodos.md](Contenido-JSON-Nodos.md) |
| 🤔 Entender por qué se hizo algo así (solo cambios grandes) | [adr/](adr/) - Decisiones de alto impacto |
| 🔧 Saber de CI y deploy | [CI.md](CI.md) |
| 🎯 Necesito cambiar algo, ¿por dónde empiezo? | [Architecture.md](Architecture.md#-qué-tocar-según-qué-quieras-cambiar) - La tabla de "toco esto" |

---

## Si Lo Vas a Mostrar en Clase

Si querés presentar el proyecto sin que nadie se pierda, usá esta ruta corta:

1. Abrí [Architecture.md](Architecture.md) y mostrá primero el diagrama principal.
2. Bajá a la sección de sistemas clave para explicar audio, guardado, navegación y racha.
3. Cerrá con [Bitacora.md](Bitacora.md) para mostrar qué se mejoró recientemente.

Con ese recorrido, en 5 minutos se entiende qué hace el juego y cómo está organizado.

---

## Lo Que Hay en Cada Doc

### 🎬 [Architecture.md](Architecture.md)
Este es el tour visual del proyecto. Te mostramos cómo fluye todo (splash → menú → gameplay), dónde vive cada archivo importante, y una tabla que dice "si necesitás cambiar X, tocá este archivo".

**Ideal para**: Entender la estructura, saber dónde está cada cosa.

### 📥 [Getting-Started.md](Getting-Started.md)
Paso a paso para tener el proyecto corriendo en tu PC. Qué necesitás instalar, cómo abrir todo, cómo correr tests.

**Ideal para**: Primera vez que tocás el proyecto.

### 📝 [Bitacora.md](Bitacora.md)
Cambios recientes resumidos en 3 líneas. Todo categorizado (🎵 Audio, 🎮 Gameplay, etc.) así encontrás rápido.

**Ideal para**: Saber qué cambió recientemente sin tener que leer todo.

### 🗂️ [Pre-POC.md](Pre-POC.md)
Archivo histórico con todo lo que pasó antes del POC.

**Ideal para**: Mostrar contexto inicial sin mezclarlo con la etapa actual.

### 🤔 [adr/](adr/) - Por Qué Se Hizo Así
Carpeta con las decisiones importantes del proyecto. Para cada decisión importante hay un archivo que explica:
- El problema que teníamos
- Qué alternativas consideramos
- Qué elegimos y por qué
- Qué cambió en el proyecto por eso

**Ideal para**: Entender el "por qué" detrás de cambios grandes (no hace falta para ajustes chicos).

### 💾 [Persistencia-Local.md](Persistencia-Local.md)
Todo sobre cómo guardamos el progreso del jugador en el disco. Qué guardamos, cómo lo guardamos, cómo lo recuperamos.

**Ideal para**: Trabajando con guardado de partidas.

### ⚙️ [CI.md](CI.md)
Cómo están configuradas nuestras validaciones automáticas en GitHub. Qué cosas se chequean cada vez que subimos cambios.

**Ideal para**: Entender por qué pasan o fallan los checks.

---

## Según Qué Estés Haciendo

### Soy Nuevo Acá
1. Leé este archivo
2. Mirá el diagrama en [Architecture.md](Architecture.md)
3. Seguí los pasos en [Getting-Started.md](Getting-Started.md)
4. Levantá el proyecto en tu PC
5. Leé el código en este orden:
   - `interface/evidente.gd` - Cómo arranca todo
   - `niveles/GameSceneRouter.gd` - Cómo navegamos entre pantallas
   - `interface/SaveManager.gd` - Cómo se guarda todo

### Voy a Cambiar Algo en el Código
1. Abrí la tabla en [Architecture.md](Architecture.md#-qué-tocar-según-qué-quieras-cambiar)
2. Buscá lo que querés cambiar
3. La tabla te dice en qué archivo tocar
4. Si es una parte grande del sistema y hay un ADR, leélo para entender por qué se hizo así
5. Corre los tests antes de hacer PR: ver [Getting-Started.md](Getting-Started.md#testing)

### Voy a Agregar una Feature Completamente Nueva
1. Leé [Architecture.md](Architecture.md) completo para entender cómo encaja
2. Mirá los [adr/](adr/) para ver cómo documentamos decisiones grandes
3. Si la feature cambia arquitectura, escribí un ADR explicando:
   - El problema que estás resolviendo
   - Qué alternativas consideraste
   - Qué elegiste y por qué
   - Cómo cambia el proyecto
4. Si no cambia arquitectura, alcanza con [Bitacora.md](Bitacora.md)

### Estoy Por Mergear a Main
1. Verificá que los checks en [CI.md](CI.md) pasen (acá está qué se chequea)
2. Si tocaste algo en `project/`, actualizá [Bitacora.md](Bitacora.md) con lo que cambiaste
3. Revisá que la entrada en [Bitacora.md](Bitacora.md) esté clara y breve
4. Mergeá cuando todo esté verde

---

## Qué Hay Hoy en el Proyecto

- ✅ **Godot 4.6.2** - La versión que estamos usando
- ✅ **4 Tracks Jugables** - Celiaquia, Veganismo, Mixto, Cetogénica
- ✅ **Guardado Local** - Podés retomar donde dejaste
- ✅ **Sistema de Racha** - +1 cada día que jugás
- ✅ **Mapa Visual** - En Celiaquia ya se ve todo
- ✅ **Quiz Integrado** - Las preguntas están en el mapa
- ✅ **Música** - Se reinicia automáticamente en sesiones largas
- ✅ **Automatización** - Los checks se corren solos en cada actualización

---

## Cómo Metemos Cambios al Proyecto

**El flujo es así**:

1. Creás una rama nueva con un nombre descriptivo (bug/musica-loop o feature/racha-visual)
2. Hacés tus cambios y los testeas en tu PC
3. Si tocaste algo importante en `project/`, anotalo en [Bitacora.md](Bitacora.md)
4. Abrís un PR
5. Los checks automáticos corren (si fallan, los arreglás)
6. Una vez que todo está verde, mergeás
7. GitHub elimina la rama automáticamente

**Reglas que nos cuidamos**:
- Los cambios tienen que ser fáciles de entender
- Los nombres de variables y funciones explícitos (no abreviaturas raras)
- Comentarios solo cuando la lógica es difícil
- Bitácora se actualiza si cambió algo que el jugador ve

---

## Links Útiles

- **GitHub Repo**: https://github.com/TTIP-e-vidente/e-vidente
- **Godot Download**: https://godotengine.org/download/windows/
- **Godot Docs**: https://docs.godotengine.org/en/stable/
- **GDScript Guide**: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/

---

## Tips Para Navegar la Wiki

- **Búsqueda**: `Ctrl+F` en Architecture.md si necesitás encontrar un archivo o sistema rápido
- **Mermaid**: El diagrama en Architecture.md es clickeable en GitHub (prueba hacer click en una caja)
- **Bitácora**: Ahí está el resumen cronológico de cambios del equipo
- **ADR**: Ahí te explicamos el "por qué" de las cosas, no solo el "qué"
- **Tabla de cambios**: Si no sabés por dónde empezar, la tabla en Architecture.md te lo dice
