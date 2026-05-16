# 🚀 Getting Started

> Este documento es el punto de entrada en inglés. El contenido completo está en [Como-Empezar.md](Como-Empezar.md).

---

## Requisitos

- **Godot:** 4.6 o compatible
- **Git:** instalado y configurado
- **Acceso:** permisos en el repositorio (push/PR)

## Clonar y abrir

```bash
git clone https://github.com/TTIP-e-vidente/e-vidente.git
cd e-vidente
# Abrir project/project.godot en Godot Editor
```

## Activar hooks locales

```bash
git config core.hooksPath .githooks
```

Esto activa el hook `commit-msg` que limpia trailers de co-author de Copilot/Autopilot automáticamente antes de cada commit.

## Flujo de trabajo

```
1. git checkout -b feature/nombre
2. [Editar en Godot]
3. git add . && git commit -m "Descripcion clara"
4. git push origin feature/nombre
5. [Abrir PR en GitHub contra dev]
```

## Más detalle

- Directorio completo y workflow extendido → [Como-Empezar.md](Como-Empezar.md)
- Arquitectura del proyecto → [Architecture.md](Architecture.md)
- Últimos cambios → [Bitacora.md](Bitacora.md)
