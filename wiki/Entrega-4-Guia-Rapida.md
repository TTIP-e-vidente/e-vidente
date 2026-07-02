# Guía rápida — Entrega 4 (5 minutos)

> Validación express para revisores TTIP. Resumen de entrega: [Entrega-4](Entrega-4) · Evidencia: [Entrega-4-Evidencia](Entrega-4-Evidencia)

---

## Qué problema resolvimos

En Entrega 3 el jugador tenía cuenta, racha en servidor y un checkbox de “avisame por mail”, pero **nunca llegaba un correo**. Entrega 4 cierra ese circuito con un sistema production-ready:

| Antes (E3) | Ahora (E4) |
|------------|------------|
| Flag `email_notifications_enabled` sin efecto | Jobs diarios envían recordatorios reales |
| Mail sin validar | OTP de 6 dígitos + UI en Godot |
| Sin auditoría de envíos | Tabla `email_deliveries` con dedupe y retry |
| Godot acoplado a… nada de mail | Backend único integrado con Brevo |

---

## Los 5 correos (en orden de vida del jugador)

| Orden | Mail | Cuándo | ¿Pide permiso? |
|-------|------|--------|----------------|
| 1 | Verificación OTP | Registro o cambio de mail | No (transaccional) |
| 2 | Bienvenida | Tras confirmar OTP | No |
| 3 | Racha en riesgo | Job 18:00 ART, jugó ayer | Sí (opt-in) |
| 4 | Racha perdida | Job 00:00 ART, 2+ días sin jugar | Sí |
| 5 | Mail cambiado | Aviso al mail **anterior** | No (seguridad) |

Copy aprobado: [Entrega-4-Mails](Entrega-4-Mails)

---

## Arquitectura en 10 segundos

```
Godot  ──HTTP──►  Backend  ──►  Brevo
                    │
                    └──►  PostgreSQL (auditoría + rachas)
```

**Godot nunca ve la API key de Brevo.** Solo habla REST con nuestro backend.

---

## Validación express (elige una)

### Opción A — Solo templates (30 s, sin Docker)

```bash
cd BACKEND
npm run test:email
```

Genera los 5 HTML, corre tests unitarios y (si `EMAIL_ENABLED=true`) puede enviar prueba real.

### Opción B — Suite completa (~2 min, requiere Docker)

```bash
cd BACKEND
docker compose up -d
npm run migrate
npm run test
```

Incluye integración: candidatos SQL, dedupe, reconcile, jobs protegidos.

### Opción C — Circuito E2E con Brevo (~3 min)

```bash
cd BACKEND
docker compose up -d
npm run validate:email-flow
```

Un comando valida DB + templates + seed rachas + outbox + auditoría.

### Opción D — Demo visual en Godot (~5 min)

1. F5 en Godot → Registro con mail.
2. Pedir verificación → copiar OTP del mail.
3. Confirmar en pantalla de verificación → llega bienvenida.
4. (Opcional) `npm run seed:streak-email-demo -- --run-job` → mail de racha.

Guía paso a paso: [Evidencia — Demo TTIP](Entrega-4-Evidencia#demo-ttip-15-minutos)

---

## Previews HTML (sin enviar)

Con `npm run dev` en `BACKEND/`:

| Template | URL |
|----------|-----|
| OTP | `/dev/email/preview?template_key=email_verification&name=Revisor&mail=demo@test.com` |
| Bienvenida | `/dev/email/preview?template_key=welcome&name=Revisor&mail=demo@test.com` |
| Racha riesgo | `/dev/email/preview?template_key=streak_at_risk&name=Revisor&streak_count=7` |
| Racha perdida | `/dev/email/preview?template_key=streak_lost&name=Revisor&streak_count=12` |
| Mail cambiado | `/dev/email/preview?template_key=mail_changed&name=Revisor` |

Prefijo: `http://localhost:3000` (o el puerto de tu `.env`).

---

## Mapa de documentación

| Si querés… | Leé… |
|------------|------|
| Entender el alcance y commits | [Entrega-4](Entrega-4) |
| Criterios de aceptación | [User Stories](Entrega-4-User-Stories) |
| Diagramas, SQL, endpoints | [Arquitectura](Entrega-4-Arquitectura) |
| Copy de cada mail | [Mails](Entrega-4-Mails) |
| Por qué Brevo, OTP, dedupe | [Decisiones](Entrega-4-Decisiones) |
| Demo, tests, capturas | [Evidencia](Entrega-4-Evidencia) |
| Evolución E3 → E4 | [Flujo E3→E4](Entrega-4-Flujo-E3-E4) |
| Qué sigue después | [Bitácora E4](Bitacora-Entrega-4) |
| Cronología de implementación | [Bitácora E4](Bitacora-Entrega-4) |

---

## Pendiente consciente (no bloquea la entrega)

- Activación en servidor productivo (`EMAIL_ENABLED` + dominio SPF/DKIM).
- Capturas de bandeja en [Evidencia](Entrega-4-Evidencia) (placeholders listos).
- Recuperación de contraseña por mail → Entrega futura.
