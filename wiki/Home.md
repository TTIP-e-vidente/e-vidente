# 🎮 E-VIDENTE Docs

Bienvenido a la documentación técnica de E-VIDENTE.

> 🎓 Juego educativo sobre alimentación con 4 recorridos jugables y modo preguntas.

---

## 🚀 Rápido: Busca Lo Que Necesitas

| Necesito... | Voy a... |
|---|---|
| 📖 Entender la arquitectura | [Architecture.md](Architecture.md) |
| 🆕 Setup local del proyecto | [Getting-Started.md](Getting-Started.md) |
| 🔍 Ver qué cambió recientemente | [CHANGELOG.md](CHANGELOG.md) o [Bitacora.md](Bitacora.md) |
| 💾 Debuggear guardado local | [Persistencia-Local.md](Persistencia-Local.md) |
| 🤔 Entender decisiones arquitectónicas | [adr/](adr/) |
| 🔧 Entender CI/Deploy | [CI.md](CI.md) |
| 📊 Ver tabla "dónde tocar qué" | [Architecture.md - Qué tocar](Architecture.md#-qué-tocar-según-qué-quieras-cambiar) |

---

## 📚 Documentación Principal

### 1️⃣ [Architecture.md](Architecture.md) - La Base
- Estructura del proyecto visualizada
- Diagrama Mermaid del flujo
- Tabla "Dónde tocar qué" por feature
- Sistemas principales explicados
- Links a ADR y CHANGELOG

**Para**: Nuevos devs, onboarding, entender la estructura.

### 2️⃣ [Getting-Started.md](Getting-Started.md) - Setup
- Requerimientos (Godot 4.6.2)
- Instalación local
- Cómo correr el proyecto
- Cómo correr tests

**Para**: Primera vez en el proyecto.

### 3️⃣ [Bitacora.md](Bitacora.md) - Resúmenes Ejecutivos
- Últimos cambios en 3 líneas
- Categorizado por [AUDIO], [UI], [GAMEPLAY], etc.
- Links a PRs y CHANGELOG

**Para**: Visión rápida de qué cambió.

### 4️⃣ [CHANGELOG.md](CHANGELOG.md) - Detalles Técnicos
- Todos los cambios por versión/sprint
- Métricas (líneas, archivos)
- APIs nuevas
- Breaking changes

**Para**: Cuando necesitas detalles completos.

### 5️⃣ [adr/](adr/) - Decisiones
Carpeta con Architecture Decision Records.  
**1 archivo = 1 decisión importante**

- [ADR-001-MusicManager.md](adr/ADR-001-MusicManager.md) - Por qué música centralizada
- Formato: Problema → Alternativas → Decisión → Impacto

**Para**: Entender "por qué" algo se hizo así.

### 6️⃣ [Persistencia-Local.md](Persistencia-Local.md) - Save System
Deep dive del sistema de guardado.

**Para**: Trabajando con persistencia.

### 7️⃣ [CI.md](CI.md) - GitHub Actions
Pipelines de validación.

**Para**: Contributing a main, entendiendo checks.

---

## 🎯 Según Tu Rol

### 👶 Soy Nuevo en el Proyecto
1. Lee este archivo (Home.md)
2. Lee [Architecture.md](Architecture.md) - mira el Mermaid
3. Lee [Getting-Started.md](Getting-Started.md)
4. Corre el proyecto localmente
5. Lee el código en este orden:
   - `interface/evidente.gd` (arranque)
   - `niveles/GameSceneRouter.gd` (navegación)
   - `interface/SaveManager.gd` (persistencia)

### 🔧 Voy a Trabajar en Código
1. Lee [Architecture.md - Qué tocar](Architecture.md#-qué-tocar-según-qué-quieras-cambiar) tabla
2. Busca tu cambio ahí
3. Sigue el link al ADR si lo hay
4. Lee el archivo específico
5. Corre tests: ver [Getting-Started.md](Getting-Started.md#testing)

### 📖 Voy a Agregar una Feature Completamente Nueva
1. Lee [Architecture.md](Architecture.md) completo
2. Lee [adr/](adr/) para entender patrones
3. Crea tu propio ADR explicando:
   - Problema
   - Alternativas consideradas
   - Tu decisión
   - Impacto
4. Agrégalo a [adr/](adr/)

### 🚀 Voy a Mergear a Main
1. Verifica que [CI.md](CI.md) pase
2. Si tocas `project/`, actualiza [Bitacora.md](Bitacora.md)
3. Mira que [CHANGELOG.md](CHANGELOG.md) sea consistente
4. Merge cuando CI sea verde

---

## 📊 Estado del Proyecto

- ✅ **Godot**: 4.6.2
- ✅ **Tracks**: Celiaquia, Veganismo, Mixto, Cetogénica
- ✅ **Persistencia**: Multi-sesión local
- ✅ **Racha**: Sistema diario implementado
- ✅ **Mapa**: Mapa visual de Celiaquia con estados
- ✅ **Preguntas**: Quiz integrado en el mapa
- ✅ **Música**: Loop automático en sesiones prolongadas
- ✅ **CI**: Validación de estructura, tests, export

---

## 🔄 Flujo de Cambios

```
1. Crea rama (bug/nombre o feature/nombre)
   ↓
2. Hace cambios + testa localmente
   ↓
3. Si toca proyecto, actualiza Bitacora + CHANGELOG
   ↓
4. Abre PR
   ↓
5. CI corre automáticamente
   ↓
6. Si CI ✅ y review ✅, mergea
   ↓
7. Branch se auto-elimina
```

**Docs convenciones**:
- Cambios chicos y reviewables
- Nombres explícitos en código
- Comentarios solo para lógica compleja
- Una nota en Bitácora si cambia flujo visible

---

## 🔗 Links Clave

- **GitHub Repo**: https://github.com/TTIP-e-vidente/e-vidente
- **Godot Download**: https://godotengine.org/download/windows/
- **Godot Docs**: https://docs.godotengine.org/en/stable/
- **GDScript Guide**: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/

---

## 💡 Tips

- Usa `Ctrl+F` en Architecture.md para buscar un sistema
- El Mermaid diagram es clickeable en GitHub
- CHANGELOG está indexado por versión y categoría
- ADR te explica por qué, no solo qué
- Si no encuentras algo, busca en la tabla "Qué tocar"
