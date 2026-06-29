# Bitácora — índice

Diario del proyecto: **qué problema había, qué hicimos, impacto y archivos**. Complementa [Entregas](Entregas.md).

Cada etapa tiene su **propio archivo** para que esto pueda crecer sin un solo `.md` gigante. Dentro de cada archivo: **más nuevo arriba**.

Rutas `project/` en entradas viejas = hoy `juego/`.

## Por etapa

| Etapa | Archivo | Resumen TTIP |
|-------|---------|--------------|
| Antes del POC | [Bitacora-Pre-POC](Bitacora-Pre-POC) | Idea, equipo, arranque |
| POC | [Bitacora-POC](Bitacora-POC) | Prueba de concepto jugable |
| Entrega 1 | [Bitacora-Entrega-1](Bitacora-Entrega-1) | Demo local |
| Entrega 2 | [Bitacora-Entrega-2](Bitacora-Entrega-2) | Polish celiaquía |
| Entrega 3 | [Bitacora-Entrega-3](Bitacora-Entrega-3) | Backend, CI, mapa |
| **Entrega 4** (actual) | [Bitacora-Entrega-4](Bitacora-Entrega-4) | Emails, OTP, rachas |

## Dónde escribir hoy

**Entrada nueva →** [Bitacora-Entrega-4](Bitacora-Entrega-4) (arriba del todo).

**Pre-POC / POC / E1** se reconstruyeron desde `git log` (mar–may 2026). Si falta detalle de un hito, ampliá la entrada en el archivo de esa etapa.

## Plantilla

```markdown
### `AAAA-MM-DD` — Título corto
<kbd>Tag1</kbd> <kbd>Tag2</kbd>

Contexto en 1–2 oraciones.

**Qué problema resolvió**
- ...

**Qué se implementó** (o **Qué se diseñó**)
- ...

**Impacto para el jugador** (o **para el equipo**)
- ...

**Evidencia técnica**
- `rutas/`, commits, PRs
```

## CI

Los PR que tocan código deben actualizar algún `wiki/Bitacora*.md` o changelog (ver [CI](CI)).
