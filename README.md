# E-VIDENTE

Puzzle educativo sobre restricciones alimentarias (celiaquía, veganismo, etc.). Armás platos, inspeccionás ingredientes, recibís feedback y avanzás en un mapa.

Público: 10–60 años. Single-player. Estilo cuaderno a mano.

**Estado y roadmap:** [ESTADO-ACTUAL.md](ESTADO-ACTUAL.md)

## Stack

- `juego/` — Godot 4.6
- `BACKEND/` — Express + PostgreSQL (opcional)
- `wiki/` — documentación

## Arranque rápido

```sh
# Solo juego: abrir juego/project.godot en Godot 4.6 y F5

# Backend (opcional)
cd BACKEND
cp .env.example .env
docker compose up -d   # apagar: docker compose down
```

API y migraciones: [BACKEND/README.md](BACKEND/README.md).

## Persistencia

- **Local (default):** perfil, progreso, archivero — sin cuenta.
- **Con cuenta:** lo mismo + sync si el API está arriba. Sin red, sigue el save local.

## Contenido y mapa

Todo el track celiaquía vive en JSON: [juego/contenido/README.md](juego/contenido/README.md).  
Flujo de runtime congelado para la demo: [juego/README.md](juego/README.md).

## Equipo

Agustin Di Santo · Margarita Cortizas
