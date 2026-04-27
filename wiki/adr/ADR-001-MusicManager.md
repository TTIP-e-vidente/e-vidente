# ADR-001: MusicManager Autoload Centralizado

**Estado**: ✅ Aprobado  
**Fecha**: 2026-04-27  
**Autor**: @Agusdiisanto  
**Impacto**: Audio, UX  

---

## Problema

Durante sesiones prolongadas, cuando los jugadores permanecían mucho tiempo en una pantalla, la música de fondo terminaba y no se reiniciaba, generando **silencios inesperados y jarring** que rompían la inmersión.

**Síntomas observados**:
- Música se corta después de ~3-4 minutos
- Ocurría en menú, mapa, niveles y cualquier escena
- Sin feedback visual al usuario
- Afectaba experiencia de sesiones largas

---

## Alternativas Consideradas

### 1. Loop en AudioStreamPlayer de cada escena ❌
- **Ventaja**: Fácil de implementar
- **Desventaja**: 
  - Duplicación de código
  - Inconsistencia entre escenas
  - Difícil de mantener
  - Cada escena con su propia lógica = bugs inconsistentes

### 2. Autoload Global con Detector de Fin ✅ (ELEGIDA)
- **Ventaja**:
  - Punto único de control
  - Lógica centralizada
  - Fácil de mantener y evolucionar
  - Escalable para nuevas features (transiciones, mezcla, etc)
- **Desventaja**: Requiere refactoring de 7 escenas

### 3. Playlist Infinita ❌
- **Ventaja**: Nativa de Godot
- **Desventaja**: 
  - Requiere rebuild de todos los assets
  - No soluciona transiciones entre escenas
  - Cambios significativos en pipeline

---

## Decisión

**Crear autoload `MusicManager` que**:

1. Reproduce música centralizada desde cualquier escena
2. Detecta automáticamente fin de pista (últimos 0.1 segundos)
3. Reinicia sin interrupciones audibles o duplicación
4. Expone API clara para control de volumen y transiciones
5. Es agnóstico al contenido de audio

**Implementación**:
- `managers/MusicManager.gd` como autoload global
- Registrado en `project.godot`
- 7 escenas refactorizadas para usar `MusicManager.reproducir_musica()`
- Eliminación de referencias directas a `$Background`

---

## Impacto

### Código
- ✅ 10 líneas promedio por escena → 2 líneas (reducción 80%)
- ✅ MusicManager: 164 líneas, altamente reutilizable
- ✅ Eliminación de `_exit_tree()` audio cleanup en cada escena

### Experiencia de Usuario
- ✅ **Música continua** en sesiones prolongadas
- ✅ **Sin silencios inesperados**
- ✅ **Sin solapamiento o duplicación**
- ✅ **Volumen consistente**
- ✅ **Transiciones suaves** entre escenas

### Arquitectura
- ✅ Punto único de cambio para lógica de audio
- ✅ Escalable para nuevas features (crossfade, playlist, etc)
- ✅ Separación clara de responsabilidades
- ✅ Testeable sin escenas

---

## Detalles de Implementación

### API Pública

```gdscript
# Reproducir con loop automático
MusicManager.reproducir_musica("res://path/audio.mp3")

# Detener con transición gradual
MusicManager.detener_musica(con_transicion: bool = true)

# Control de volumen (0.0 a 1.0 lineal)
MusicManager.establecer_volumen(0.8)

# Pausar/Reanudar
MusicManager.pausar_musica()
MusicManager.reanudar_musica()

# Queries
if MusicManager.esta_reproduciendo():
    var cancion = MusicManager.obtener_musica_actual()
```

### Lógica de Loop

En `_process()`:
1. Verifica si la música está reproduciéndose
2. Obtiene duración total y posición actual
3. Si `posicion >= (duracion - 0.1)`, reinicia automáticamente
4. Sin pausa perceptible al usuario

---

## Alternativas Futuras

### Corto Plazo
- [ ] Crossfade entre tracks (transición suave 1s)
- [ ] Sistema de mezcla (múltiples canales simultáneos)
- [ ] Fade in/out en cambios de escena

### Mediano Plazo
- [ ] Playlist con orden definido
- [ ] Variaciones dinámicas (día/noche, emocional)
- [ ] Audio adaptativo según gameplay

### Largo Plazo
- [ ] Sistema de música generativa
- [ ] Integration con state machine de emociones
- [ ] Soundscape ambiental (múltiples capas)

---

## Criterios de Aceptación Met ✅

- ✅ La música no se detiene en sesiones prolongadas
- ✅ Al finalizar la pista, vuelve a reproducirse automáticamente
- ✅ No hay silencios inesperados
- ✅ Funciona en todas las pantallas (menú, mapa, gameplay, etc)
- ✅ La música no se duplica ni se superpone
- ✅ El volumen configurado se mantiene correctamente
- ✅ Las transiciones de audio entre escenas funcionan sin cortes

---

## Referencias

- **PR**: #17 - Music Loop in Prolonged Sessions
- **Commit**: 279beea - MusicManager autoload implementation
- **Bitácora**: [2026-04-27 | musica-loop-sesiones-prolongadas](../Bitacora.md)
- **Architecture**: [Sistema de Audio](../Architecture.md#-audio)

---

## Retroalimentación

Si hay cambios o ajustes necesarios en futuras sesiones, este ADR debería actualizarse para reflejar:
- Nuevas alternativas consideradas
- Cambios en la implementación
- Nuevas features del sistema
