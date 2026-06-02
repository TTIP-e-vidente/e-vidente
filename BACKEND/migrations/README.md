# Migraciones

Las migraciones usan SQL plano y se ejecutan en orden alfabetico con:

```sh
npm run migrate
```

El runner registra cada archivo aplicado en `schema_migrations` para evitar repetir migraciones.
