# Cierre tecnico Backend PoC - E-VIDENTE

## Objetivo

El backend PoC valida una base tecnica para persistencia y API sin reemplazar todavia la persistencia local del juego. El alcance cubre:

- PostgreSQL local con Docker.
- Migraciones SQL.
- Auth JWT minima.
- Endpoints autenticados de jugador.
- Modelo canonico de persistencia.
- Tests de integracion con PostgreSQL real.
- Documentacion tecnica del backend.

## Historias cubiertas

- PostgreSQL local con Docker.
- Conexion funcional con PostgreSQL.
- Modelo inicial de jugador.
- Auth minima.
- Endpoints autenticados de progreso.
- Hardening minimo.

## Comandos de validacion

```sh
cd BACKEND
docker compose up -d
npm run migrate
npm run build
npm test
npm run smoke:api
```

## Estado de Godot

- Godot no fue modificado por la PoC backend.
- La persistencia local sigue intacta.
- El backend no reemplaza todavia `SaveManager`.
- Godot todavia no consume endpoints del backend.

## Riesgos conocidos

- Existen tablas duplicadas heredadas de la PoC.
- No se eliminan todavia.
- El modelo canonico esta documentado en `BACKEND/docs/CANONICAL_MODEL.md`.
- La limpieza fisica queda para una migracion futura controlada.

## Proximo paso recomendado

Preparar el contrato futuro Godot <-> Backend sin implementarlo todavia.
