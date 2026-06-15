# Mails — redacción y operación (Entrega 4)

Guía para escribir, revisar y publicar los correos de E-VIDENTE. El código vive en `BACKEND/src/modules/email/templates/`; esta página es la **fuente editorial** que el equipo valida antes de tocar TypeScript.

---

## Voz y tono

| Principio | Cómo se aplica |
|-----------|----------------|
| Cercano, no infantil | Voseo rioplatense; sin exceso de emojis |
| Breve | Un mensaje = una idea; párrafos cortos |
| Honesto | No prometer “confirmar cuenta” si no hay link de verificación |
| Pedagógico | Recordar que se aprende jugando, sin sermonear |
| Respetuoso | Opt-out visible en mails de racha; bienvenida sin presión |

**Marca:** siempre **E-VIDENTE** (mayúsculas en marca, minúsculas en frases normales).

**Cierre estándar (texto plano):** `Equipo E-VIDENTE`

**Footer HTML (fijo en layout):** *E-VIDENTE — aprender jugando sobre restricciones alimentarias.*

---

## Anatomía de cada mail

Cada template define cuatro capas:

1. **Asunto** — lo que decide si abren el mail (máx. ~50 caracteres ideal).
2. **Headline** — titular del bloque verde (HTML).
3. **Subtitle** — una línea de contexto bajo el titular.
4. **Cuerpo** — saludo + mensaje principal + (opcional) opt-out.

Siempre hay versión **texto plano** y **HTML** con el mismo significado.

---

## Copy aprobado (Entrega 4)

### 1. Bienvenida (`welcome`)

**Cuándo:** registro exitoso con mail. **No** requiere checkbox de notificaciones. Se encola en `email_deliveries` (outbox) y se envía al procesar la cola (`npm run dev` con `EMAIL_PROCESS_ON_STARTUP`, o `npm run email:run-local`).

| Campo | Texto |
|-------|-------|
| **Asunto** | `¡Listo! Tu cuenta en E-VIDENTE ya está creada` |
| **Headline** | `¡Bienvenido/a a E-VIDENTE!` |
| **Subtitle** | `Tu cuenta está lista para jugar` |

**Cuerpo (propuesta):**

> Hola {nombre},
>
> Creaste tu cuenta correctamente. Ya podés entrar al juego, sumar experiencia y empezar tu racha diaria.
>
> Nos alegra que estés acá. ¡Que disfrutes el camino!

**Qué evitar en UI de registro:** frases como *“te enviamos un mail para confirmar tu cuenta”* si no hay verificación por link.

---

### 2. Racha en riesgo (`streak_at_risk`)

**Cuándo:** jugó **ayer** (fecha ART en Postgres), **hoy no** hay actividad en servidor. Requiere `email_notifications_enabled = true`, mail en cuenta, racha `> 0` en DB, y que haya corrido el **job** (`npm run email:streaks` o `npm run email:run-local`). **No** se dispara solo por abrir Godot.

| Campo | Texto |
|-------|-------|
| **Asunto** | `Tu racha de {N} {día|días} sigue en juego — jugá hoy` |
| **Headline** | `Tu racha sigue en juego` |
| **Subtitle** | `Entrá hoy para mantenerla` |

**Cuerpo (propuesta):**

> Hola {nombre},
>
> Llevás **{N} {día|días}** de racha, pero hoy todavía no registramos que hayas jugado. Entrá y completá una partida para no perderla.
>
> Podés desactivar los recordatorios de racha desde tu cuenta en el juego.

**Tono:** urgencia suave, sin culpa. El número de días es el dato que más motiva.

---

### 3. Racha perdida (`streak_lost`)

**Cuándo:** 2+ días sin actividad en servidor (`last_activity_day <= hoy - 2`). Mismo consentimiento. El job envía el mail y luego **reconcilia** la racha en Postgres (`current_count = 0`); al loguear, Godot sincroniza con el servidor.

| Campo | Texto |
|-------|-------|
| **Asunto** | `Se reinició tu racha — podés arrancar otra cuando quieras` |
| **Headline** | `Tu racha se reinició` |
| **Subtitle** | `Siempre podés volver a empezar` |

**Cuerpo (propuesta):**

> Hola {nombre},
>
> Pasaron varios días sin actividad y tu racha de **{N} {día|días}** volvió a cero. No pasa nada: cada día es una nueva oportunidad para aprender jugando.
>
> Podés desactivar los recordatorios de racha desde tu cuenta en el juego.

**Tono:** empático, sin dramatizar. Alineado al panel in-game `StreakLossMessagePanel`.

---

## Checklist antes de publicar un cambio de copy

- [ ] Asunto claro y distinto por template (no repetir “E-VIDENTE” al inicio si ya hay marca en remitente).
- [ ] `{nombre}` y `{N}` escapados en HTML (`escapeHtml` en código).
- [ ] Texto plano = mismo mensaje que HTML (sin depender solo del diseño).
- [ ] Mails de racha incluyen línea de opt-out.
- [ ] Bienvenida **sin** opt-out de racha (no aplica).
- [ ] Preview en dev: `GET /dev/email/preview?template_key=...&name=Agus&streak_count=7`
- [ ] `npm run test:email` en verde.
- [ ] Revisión en cliente real (Gmail + uno móvil): legibilidad, no carpeta spam.

---

## Cómo implementar un cambio de redacción (paso a paso)

### 1. Editar en wiki primero

Acordar el copy en esta página (o en PR de docs). Evita sorpresas de producto.

### 2. Actualizar el template TypeScript

Archivos:

- `welcome.template.ts`
- `streak-at-risk.template.ts`
- `streak-lost.template.ts`

Patrón:

```typescript
const subject = '...';
const textContent = buildTextLines([...]);
const htmlContent = wrapHtml({
  headline: '...',
  subtitle: '...',
  includeNotificationOptOut: true, // solo rachas
  bodyHtml: [...]
});
```

Textos compartidos (opt-out): `NOTIFICATION_OPT_OUT_TEXT` y `includeNotificationOptOut` en `layout.ts`.

### 3. Verificar sin enviar

```bash
cd BACKEND
npm run dev
# Navegador:
# http://localhost:3000/dev/email/preview?template_key=welcome&name=Agus&mail=agus@test.com
# http://localhost:3000/dev/email/preview?template_key=streak_at_risk&name=Agus&streak_count=7
```

### 4. Probar envío real (dev)

En `.env`: `EMAIL_ENABLED=true` + credenciales Brevo. En Brevo: remitente verified + IP autorizada (o bloqueo API desactivado). Ver `BACKEND/docs/BREVO_SETUP.md`.

```bash
cd BACKEND
docker compose up -d
npm run validate:email-flow          # circuito completo (recomendado)
npm run seed:streak-email-demo -- --run-job   # demo streak_at_risk
npm run smoke:email -- --send        # welcome de prueba (con SMOKE_EMAIL_TO)
```

Auditoría: `GET /dev/email/deliveries?limit=20` (con `npm run dev`).

### 5. Alinear copy en Godot (si aplica)

| Lugar | Qué revisar |
|-------|-------------|
| `juego/API/Login.tscn` | Hint del mail de bienvenida; checkbox *“Quiero recibir recordatorios de racha por mail.”* |
| `juego/interface/auth.tscn` | Toggle *“Recibir recordatorios de racha por correo”* (editar perfil, sesión online) |
| `ProfileOverlayPanel` | Solo lectura: *“Recordatorios mail: Sí/No”* |

---

## Diseño visual (ya implementado)

Tokens en `templates/layout.ts` (`GAME_EMAIL_THEME`):

| Token | Valor | Uso |
|-------|-------|-----|
| Verde primario | `#42785e` | Header, énfasis |
| Crema | `#f4f7f2` | Fondo |
| Marrón acento | `#704533` | Racha perdida |
| Radio card | `28px` | Coherente con paneles del juego |

Tipografía: **Rubik** (Google Fonts). No usar Rubik Spray Paint en mail (compatibilidad con clientes).

---

## Métricas útiles (post-activación)

En Brevo: entregados, rebotes, spam. En Postgres:

```sql
SELECT template_key, status, COUNT(*)
FROM email_deliveries
GROUP BY template_key, status;
```

Correlacionar picos de `failed` con `error_message` y límites de rate de Brevo. Error frecuente en local: `unrecognised IP address` → autorizar IP en Brevo → Seguridad.

---

## Operación — qué esperar (no confundir con el juego)

| Pregunta | Respuesta |
|----------|-----------|
| ¿Me manda mail al abrir Godot? | **No** (salvo welcome pendiente si el backend procesa cola al iniciar). |
| ¿Me avisa “por perder racha” al instante? | **No.** Es batch diario vía job. |
| ¿Qué datos usa el job? | Postgres (`streaks.last_activity_day`), no solo el save local offline. |
| ¿Cómo programo envíos en local? | Task Scheduler: `scripts/local/register-email-tasks-windows.ps1` o manual `npm run email:run-local`. |

**Flujo mínimo para recibir `streak_at_risk` con tu cuenta:**

1. Login + partida **online** (racha en servidor).
2. `last_activity_day` = ayer y hoy sin jugar en DB (o `npm run seed:streak-email-demo`).
3. `npm run email:streaks` (o `email:run-local`).
4. Revisar bandeja + `email_deliveries` con `status=sent`.

---

## Próximos mails (fuera de E4)

| Mail | Notas |
|------|-------|
| Recuperación de contraseña | Link firmado con TTL; ticket futuro |
| Verificación de cuenta | Cambia el copy de registro y el flujo de auth |
| Resumen semanal | Requiere job nuevo + template; distinto consentimiento |
