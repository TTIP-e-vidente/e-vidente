# E-VIDENTE

Puzzle educativo sobre restricciones alimentarias (celiaquía, veganismo, etc.). Armás platos, inspeccionás ingredientes, recibís feedback y avanzás en un mapa.

Público: 10–60 años. Single-player. Estilo cuaderno a mano.

**Setup y verificación:** [BACKEND/docs/SUPABASE_QUICKSTART.md](BACKEND/docs/SUPABASE_QUICKSTART.md) · **Entrega actual:** [wiki/Entrega-4.md](wiki/Entrega-4.md)

## Stack

- `juego/` — Godot 4.6
- `BACKEND/` — Express + **Supabase Postgres** (DB, mails OTP y jobs vía Edge Functions)
- `wiki/` — documentación

## Arranque rápido

```sh
# Solo juego (offline): abrir juego/project.godot en Godot 4.6 → F5

# Juego + cuenta + Supabase (único camino de desarrollo)
cd BACKEND
npm install
npm run supabase:init    # primera vez: completar .env.staging
npm run dev              # Express → Supabase + sync Godot config
# Luego Godot F5
```

Guía: [BACKEND/docs/SUPABASE_QUICKSTART.md](BACKEND/docs/SUPABASE_QUICKSTART.md)

Verificación: `npm run integrate:status` · Mails/jobs: Edge Functions + `pg_cron` (no Docker local).

## Persistencia

- **Local (default):** perfil, progreso, archivero — sin cuenta.
- **Con cuenta:** lo mismo + sync si el API está arriba. Sin red, sigue el save local.

## Contenido y mapa

Todo el track celiaquía vive en JSON: [juego/contenido/README.md](juego/contenido/README.md).  
Flujo de runtime congelado para la demo: [juego/README.md](juego/README.md).

## Documentación TTIP

Entregas del proyecto: [wiki/Entregas.md](wiki/Entregas.md) · **E4 (emails):** [Resumen](wiki/Entrega-4.md)

## Equipo

Agustin Di Santo · Margarita Cortizas
