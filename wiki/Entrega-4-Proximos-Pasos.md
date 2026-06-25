# Próximos pasos — post Entrega 4

Opciones y tareas para la siguiente iteración. Estado actual: [ESTADO-ACTUAL.md](../ESTADO-ACTUAL.md).

---

## Cierre operativo de E4 (corto plazo)

| Prioridad | Tarea | Notas |
|-----------|-------|-------|
| Alta | Subir capturas a [Evidencia E4](Entrega-4-Evidencia) | Bandeja + `email_deliveries` + UI Godot |
| Alta | Deploy backend público | Prerequisito para cron en GH Actions |
| Media | Activar `EMAIL_ENABLED=true` en prod | Dominio verificado en Brevo (SPF/DKIM) |
| Media | Configurar secrets `BACKEND_BASE_URL` + `EMAIL_CRON_SECRET` | Workflow `email-cron.yml` |
| Baja | Registrar Task Scheduler local | Solo si demo offline recurrente |

---

## Entrega 5 — candidatos de alcance

```
                    ┌─────────────────────────────┐
                    │   Post E4 — ¿por dónde?     │
                    └──────────────┬──────────────┘
           ┌───────────────────────┼───────────────────────┐
           ▼                       ▼                       ▼
   ┌───────────────┐      ┌───────────────┐      ┌─────────────────┐
   │  Opción A     │      │  Opción B     │      │  Opción C       │
   │  Producción   │      │  Auth mail    │      │  Contenido      │
   │  + deploy     │      │  recuperación │      │  vegan/keto     │
   └───────────────┘      └───────────────┘      └─────────────────┘
```

### Opción A — Producción y observabilidad

- Backend en cloud con CI/CD de deploy.
- Monitoreo de `email_deliveries.failed` + alertas Brevo.
- Dashboard simple de métricas de racha vs mails enviados.

### Opción B — Auth por mail (complemento natural de E4)

- Recuperación de contraseña con link firmado + TTL.
- Reutiliza módulo email, templates y auditoría existentes.
- Endpoints de reset ya esbozados en E3; falta el mail.

### Opción C — Contenido y packs alimentarios

- Packs JSON vegan / keto / mixto (hoy solo celiaquía completo).
- Leaderboard y logros como sistema unificado.
- Mails de resumen semanal (nuevo template + consentimiento distinto).

---

## Deuda técnica conocida (no bloqueante)

| Ítem | Impacto | Esfuerzo |
|------|---------|----------|
| Una sola `EMAIL_TIMEZONE` (ART) | Jugadores en otras zonas | Medio |
| Editor visual de templates | Copy sin tocar TS | Alto |
| Tests Godot del flujo OTP | Regresión UI | Bajo–medio |
| Validación JSON contenido en CI | Calidad contenido | Medio |

---

## Enlaces útiles

- [Guía rápida E4](Entrega-4-Guia-Rapida) — validación en 5 min
- [BREVO_SETUP](../BACKEND/docs/BREVO_SETUP.md) — activación producción
- [Próximos pasos E1](Entrega-1-Proximos-Pasos) — planificación histórica
