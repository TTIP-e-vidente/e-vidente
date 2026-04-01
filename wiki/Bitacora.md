# 📖 Bitacora

Registro cronologico de decisiones, cambios funcionales y ajustes tecnicos importante.

---

## 📝 Plantilla (copiar y pegar)

```markdown
### YYYY-MM-DD | [tipo]
**Resumen:** Descripcion breve de una linea  
**Impacto:** Que cambia para el equipo o el juego  
**Responsable:** [Nombre]  

**Detalles (opcionales):**
- Punto 1
- Punto 2
```

**Tipos:** `feature` | `fix` | `refactor` | `docs` | `ci` | `design`

---

## 📚 Entradas

### 2026-03-31 | docs
**Resumen:** Se refactoriza wiki: portada mejorada, guias claras, documentacion de CI  
**Impacto:** Onboarding mas rapido, claridad sobre CI pipeline  
**Responsable:** CI/Docs upgrade

### 2026-03-31 | ci
**Resumen:** CI produccion establece 3 jobs: quality (warning), validate (critical), build-web  
**Impacto:** Todas las PRs pasan por validacion de estructura, import Godot y export web  
**Responsable:** Agustin Di Santo

---

## 💡 Tips para mantener activa

- Agregar entrada solo para cambios **significativos** (gameplay, assets nuevos, arquitectura)
- Si es PR pequeno (typo, comentario), puedes omitir
- Revisar Bitacora antes de planificar sprints
- Usar como historico para retrospectivas
