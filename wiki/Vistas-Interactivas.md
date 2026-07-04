# Vistas interactivas · E-VIDENTE

Las páginas HTML de diagramas **se abren desde la wiki con un clic**. No hace falta clonar el repo ni descargar archivos `.html`.

> Tras publicar cambios, el visor puede tardar ~1 minuto en refrescar ([raw.githack.com](https://raw.githack.com/)). Si ves contenido viejo, agregá `?v=4` a la URL o usá Ctrl+F5.

---

## Entrega 4

| Vista | Para qué | Abrir |
|-------|----------|-------|
| **Persistencia E3+E4** | Tablas email, Supabase Edge, dual Godot | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente/dev/wiki/mer-persistencia-e4.html?v=5) · [Índice wiki](Mer-Persistencia-E4) |

Documentación: [Entrega-4](Entrega-4) · [Evidencia](Entrega-4-Evidencia)

---

## Entrega 3

| Vista | Para qué | Abrir |
|-------|----------|-------|
| **Hub MER** | Índice visual E3 | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente/dev/wiki/mer.html?v=4) · [Índice wiki](Mer-Hub) |
| **Flujo E1→E3** | Evolución de persistencia | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente/dev/wiki/mer-flujo.html?v=4) · [Índice wiki](Mer-Flujo) |
| **Persistencia dual** | Local + PostgreSQL | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente/dev/wiki/mer-persistencia-e3.html?v=4) · [Índice wiki](Mer-Persistencia-E3) |

Documentación en markdown: [Resumen E3](Entrega-3) · [Evidencia](Entrega-3-Evidencia) · [User Stories](Entrega-3-User-Stories)

---

## MER — diagramas

| Vista | Capa | Abrir |
|-------|------|-------|
| [Hub MER](Mer-Hub) | Índice visual E1→E3 | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente/dev/wiki/mer.html?v=4) |
| [Dominio E1/E2](Mer-Dominio) | Excalidraw conceptual | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente/dev/wiki/mer-dominio.html?v=4) |
| [Persistencia E3](Mer-Persistencia-E3) | Tablas + archivos | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente/dev/wiki/mer-persistencia-e3.html?v=4) |
| [Persistencia E4](Mer-Persistencia-E4) | Email + Supabase sobre E3 | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente/dev/wiki/mer-persistencia-e4.html?v=5) |
| [Flujo de datos](Mer-Flujo) | Swimlanes sync | [▶ Abrir](https://raw.githack.com/TTIP-e-vidente/e-vidente/dev/wiki/mer-flujo.html?v=4) |

Esquema canónico en texto: [MER](MER) · Sync: [Sync-Godot-Postgres](Sync-Godot-Postgres)

---

## Cómo funciona

1. **En la wiki** (esta página): leés contexto y links en markdown.
2. **“Abrir / Pantalla completa”**: carga la vista interactiva vía [raw.githack.com](https://raw.githack.com/) desde el repo **público** `e-vidente` (`wiki/` en branch `dev`).
3. **Dentro de la vista**: la barra verde “← Volver a la wiki” te devuelve acá; los links a docs markdown abren la wiki en otra pestaña.

> **¿404 en raw.githack?** El repo `e-vidente.wiki` es privado y raw.githack no puede leerlo. Los HTML se sirven desde `e-vidente/dev/wiki/`. Si falla, abrí el archivo local correspondiente en `wiki/` (por ejemplo `mer.html`) en el navegador.

Assets compartidos: `assets/mer-shared.css`, `assets/mer-shared.js` (mantenimiento en un solo lugar).
