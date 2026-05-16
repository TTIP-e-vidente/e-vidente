# 🎮 E-VIDENTE Docs

Bienvenido. Acá encontrás todo lo que necesitás saber del proyecto.

> 🎓 **E-VIDENTE** es un juego educativo sobre alimentación. Tenés 4 recorridos jugables.

---

## Buscás algo específico?

| Necesito... | Andá a... |
|---|---|
| 🎬 Ver cómo funciona el proyecto | [Architecture.md](Architecture.md) - El tour visual |
| 🆕 Levantar el proyecto en tu PC | [Getting-Started.md](Getting-Started.md) |
| 🔍 Saber qué cambió en los últimos días | [Bitacora.md](Bitacora.md) - Resúmenes cortos |
| 🔧 Saber de CI y deploy | [CI.md](CI.md) |
| 🎯 Necesito cambiar algo, ¿por dónde empiezo? | [Architecture.md](Architecture.md#-qué-tocar-según-qué-quieras-cambiar) - La tabla de "toco esto" |

---

## Navegación por Etapas

Esta guía organiza la wiki por etapas de trabajo TTIP y por documentación técnica transversal.

| Etapa / bloque | Documento principal | Estado |
|---|---|---|
| POC | [Bitacora.md#poc-falta-confirmar](Bitacora.md#poc-falta-confirmar) | Falta confirmar consolidación en página propia |
| Entrega 1 | [02-Entrega-1.md](02-Entrega-1.md) | User stories, casos de uso, avances, decisiones y evidencia |
| Entrega 2 | [Bitacora.md#entrega-2-falta-confirmar](Bitacora.md#entrega-2-falta-confirmar) | Falta confirmar contenido final |
| Próximas entregas | [Bitacora.md#proximas-entregas-falta-confirmar](Bitacora.md#proximas-entregas-falta-confirmar) | Falta confirmar planificación |
| Documentación técnica | [Architecture.md](Architecture.md), [Persistencia-Local.md](Persistencia-Local.md), [Contenido-JSON-Nodos.md](Contenido-JSON-Nodos.md), [CI.md](CI.md), [Getting-Started.md](Getting-Started.md) | Confirmado |

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

### ⚙️ [CI.md](CI.md)
Cómo están configuradas nuestras validaciones automáticas en GitHub. Qué cosas se chequean cada vez que subimos cambios.

**Ideal para**: Entender por qué pasan o fallan los checks.

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