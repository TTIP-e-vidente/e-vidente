# 🎮 E-VIDENTE Docs

Bienvenido. Acá encontrás todo lo que necesitás saber del proyecto.

> 🎓 **E-VIDENTE** es un juego educativo sobre alimentación. Tenés 4 recorridos jugables (celiaquia, veganismo, mixto, keto) 

---
## Lo Que Hay en Cada Doc

### [Architecture.md](Architecture.md)
Este es el tour visual del proyecto. Te mostramos cómo fluye todo (splash → menú → gameplay), dónde vive cada archivo importante, y una tabla que dice "si necesitás cambiar X, tocá este archivo".

**Ideal para**: Entender la estructura, saber dónde está cada cosa.

### [Getting-Started.md](Getting-Started.md)
Paso a paso para tener el proyecto corriendo en tu PC. Qué necesitás instalar, cómo abrir todo, cómo correr tests.

**Ideal para**: Primera vez que tocás el proyecto.

### [Bitacora.md](Bitacora.md)
Cambios recientes resumidos en 3 líneas. Todo categorizado (🎵 Audio, 🎮 Gameplay, etc.) así encontrás rápido.

**Ideal para**: Saber qué cambió recientemente sin tener que leer todo.

### [CI.md](CI.md)
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

## Tips Para Navegar la Wiki

- **Búsqueda**: `Ctrl+F` en Architecture.md si necesitás encontrar un archivo o sistema rápido
- **Bitácora**: Ahí está el resumen cronológico de cambios del equipo
