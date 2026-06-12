# Vistas interactivas · E-VIDENTE

Las páginas HTML de diagramas y presentación **se abren desde la wiki con un clic**. No hace falta clonar el repo ni descargar archivos `.html`.

> Tras publicar cambios con `publish-wiki.ps1`, el visor puede tardar ~1 minuto en refrescar ([raw.githack.com](https://raw.githack.com/)).

---

## Entrega 3

| Vista | Para qué | Abrir |
|-------|----------|-------|
| **Presentación** | Sprint y diagramas | [▶ Pantalla completa](https://raw.githack.com/TTIP-e-vidente/e-vidente.wiki/master/Entrega-3-Presentacion.html) · [Índice wiki](Entrega-3-Presentacion) |
| **Flujo E1→E3** | Evolución de persistencia | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente.wiki/master/mer-flujo.html) · [Índice wiki](Mer-Flujo) |
| **Persistencia dual** | Local + PostgreSQL | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente.wiki/master/mer-persistencia-e3.html) · [Índice wiki](Mer-Persistencia-E3) |

Documentación en markdown: [Resumen E3](Entrega-3) · [Evidencia](Entrega-3-Evidencia) · [User Stories](Entrega-3-User-Stories)

---

## MER — diagramas

| Vista | Capa | Abrir |
|-------|------|-------|
| [Hub MER](Mer-Hub) | Índice visual E1→E3 | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente.wiki/master/mer.html) |
| [Dominio E1/E2](Mer-Dominio) | Excalidraw conceptual | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente.wiki/master/mer-dominio.html) |
| [Persistencia E3](Mer-Persistencia-E3) | Tablas + archivos | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente.wiki/master/mer-persistencia-e3.html) |
| [Flujo de datos](Mer-Flujo) | Swimlanes sync | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente.wiki/master/mer-flujo.html) |

Esquema canónico en texto: [MER](MER) · Sync: [Sync-Godot-Postgres](Sync-Godot-Postgres)

---

## Cómo funciona

1. **En la wiki** (esta página): leés contexto y links en markdown.
2. **“Abrir / Pantalla completa”**: carga la vista interactiva vía [raw.githack.com](https://raw.githack.com/) desde el repo `e-vidente.wiki`.
3. **Dentro de la vista**: la barra verde “← Volver a la wiki” te devuelve acá; los links a docs markdown abren la wiki en otra pestaña.

Assets compartidos: `assets/mer-shared.css`, `assets/mer-shared.js` (mantenimiento en un solo lugar).
