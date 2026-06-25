# User Stories — Entrega 4

Historias de usuario: **verificación OTP, bienvenida, consentimiento, rachas y operación**.

[Guía rápida](Entrega-4-Guia-Rapida) · [Resumen](Entrega-4) · [Evidencia](Entrega-4-Evidencia) · [Mails](Entrega-4-Mails)

---

## Resumen

| US | Historia | Actor | Template / sistema |
|----|----------|-------|-------------------|
| [US-01](#us-01--verificar-mi-mail-con-un-código) | Verificar mail OTP | Jugador | `email_verification` |
| [US-02](#us-02--recibir-bienvenida-tras-verificar-el-mail) | Bienvenida post-OTP | Jugador nuevo | `welcome` |
| [US-03](#us-03--elegir-si-quiero-recordatorios-por-mail) | Opt-in recordatorios | Jugador | `email_notifications_enabled` |
| [US-04](#us-04--aviso-por-mail-cuando-mi-racha-está-en-riesgo) | Racha en riesgo | Jugador activo | `streak_at_risk` |
| [US-05](#us-05--enterarme-por-mail-si-perdí-la-racha) | Racha perdida | Jugador inactivo | `streak_lost` |
| [US-06](#us-06--enterarme-si-cambiaron-mi-mail) | Aviso cambio mail | Jugador | `mail_changed` |
| [US-07](#us-07--operar-y-auditar-envíos-equipo) | Ops y auditoría | Equipo dev | jobs + `/dev/email` |

---

## US-01 — Verificar mi mail con un código

**Actor/es:** Jugador nuevo o quien cambió su mail  
**Funcionalidad:** Recibir un código OTP por correo y confirmarlo en el juego para activar la cuenta.  
**Valor que aporta:** Garantiza que el mail es real antes de enviar bienvenida o recordatorios de racha.

### Criterios de aceptación

- Dado registro con mail válido, cuando el alta es exitosa, entonces el backend puede enviar `email_verification` con código de 6 dígitos.
- Dado el código en pantalla de verificación Godot, cuando el jugador confirma con `POST /player/verify-email/confirm`, entonces `mail_verified_at` queda persistido.
- Dado código expirado o incorrecto, cuando intenta confirmar, entonces recibe error claro sin revelar si el mail existe.
- Dado demasiados intentos fallidos, cuando supera el límite, entonces se bloquea temporalmente el reenvío.

### Tickets relacionados

- UNQ-90 — Registro de usuario
- UNQ-27 — Perfil de usuario

**Cómo se valida:** `npm run smoke:email-verification` · fila `email_deliveries` con `template_key=email_verification` · UI `EmailVerification.tscn`.

---

## US-02 — Recibir bienvenida tras verificar el mail

**Actor/es:** Jugador con mail verificado  
**Funcionalidad:** Correo de bienvenida que confirma que la cuenta está activa y lista para jugar.  
**Valor que aporta:** Cierre positivo del onboarding; refuerza confianza sin bloquear el registro si el envío falla.

### Criterios de aceptación

- Dado OTP confirmado, cuando la verificación es exitosa, entonces se encola `welcome` de forma asíncrona (outbox).
- Dado registro **sin** verificar, cuando solo se creó la cuenta, entonces **no** se envía bienvenida.
- Dado `EMAIL_ENABLED=false` o Brevo caído, cuando se verifica, entonces la cuenta queda activa igual y el envío se omite o queda `failed` con retry.
- Dado welcome ya enviado, cuando se reintenta, entonces no se duplica (`dedupe_key = welcome`).

### Tickets relacionados

- UNQ-64 (circuito mails)
- UNQ-90 — Registro

**Cómo se valida:** verificar OTP → `email_deliveries` con `template_key=welcome` y `status=sent` · preview dev · copy en [Entrega-4-Mails](Entrega-4-Mails).

---

## US-03 — Elegir si quiero recordatorios por mail

**Actor/es:** Jugador  
**Funcionalidad:** Activar o desactivar recordatorios de racha al registrarse y desde el perfil.  
**Valor que aporta:** Consentimiento explícito; cumplimiento de buenas prácticas y menor riesgo de spam.

### Criterios de aceptación

- Dado el formulario de registro, cuando marca o desmarca la casilla, entonces `accept_email_notifications` persiste en `users.email_notifications_enabled`.
- Dado sesión activa, cuando edita perfil y cambia la preferencia, entonces `PATCH /player/me` actualiza el flag.
- Dado `email_notifications_enabled = false`, cuando corre el job de rachas, entonces no recibe `streak_at_risk` ni `streak_lost`.
- Dado mail **no verificado**, cuando intenta activar recordatorios, entonces la UI guía a verificar primero.

### Tickets relacionados

- UNQ-64
- UNQ-27 — Perfil de usuario

---

## US-04 — Aviso por mail cuando mi racha está en riesgo

**Actor/es:** Jugador con racha activa, mail verificado y notificaciones habilitadas  
**Funcionalidad:** Recibir un mail si jugó ayer pero hoy aún no hay actividad registrada en el servidor.  
**Valor que aporta:** Recordatorio fuera del juego para sostener el hábito diario (objetivo UNQ-64).

### Criterios de aceptación

- Dado racha `current_count > 0` y última actividad ayer (ART), cuando corre el cron del día (19:00 ART), entonces se envía como máximo un `streak_at_risk` por usuario y fecha.
- Dado que el jugador juega después del mail, cuando corre el cron del día siguiente, entonces no recibe otro “en riesgo” por el mismo día.
- Dado mail inválido o fallo de Brevo, cuando falla el envío, entonces queda `failed` y puede reintentarse según política de retry.
- Dado segundo run del job el mismo día, entonces dedupe → `skipped` (sin segundo mail).

### Tickets relacionados

- [UNQ-64](https://tip-unq.atlassian.net/browse/UNQ-64) — Notificaciones email racha en riesgo
- UNQ-83 — Indicador visual de racha (complemento in-game)

---

## US-05 — Enterarme por mail si perdí la racha

**Actor/es:** Jugador con notificaciones habilitadas  
**Funcionalidad:** Recibir aviso cuando pasaron 2+ días sin actividad; la racha se reinicia en backend al correr el job.  
**Valor que aporta:** Cierre claro del ciclo, alineado al mensaje in-game de pérdida.

### Criterios de aceptación

- Dado última actividad hace 2 o más días, cuando corre el cron, entonces se envía `streak_lost` una vez por `dedupe_key` basado en el último día activo.
- Dado inactividad de 2+ días, cuando finaliza el job, entonces `reconcileExpiredStreaksInDatabase` pone `streaks.current_count = 0` **aunque falle Brevo**.
- Dado el contenido del mail, cuando lo lee el jugador, entonces el tono es empático y ofrece reenganche sin culpa.

### Tickets relacionados

- UNQ-149 — Mensaje de pérdida de racha (in-game)
- UNQ-64

---

## US-06 — Enterarme si cambiaron mi mail

**Actor/es:** Jugador cuyo mail fue actualizado  
**Funcionalidad:** Recibir aviso de seguridad en el **mail anterior** cuando alguien cambia el email de la cuenta.  
**Valor que aporta:** Detección temprana de accesos no autorizados.

### Criterios de aceptación

- Dado cambio de mail en perfil, cuando se confirma el nuevo mail, entonces se envía `mail_changed` al mail anterior.
- Dado el contenido, cuando lo lee, entonces indica el nuevo mail y pasos si no fue él.
- Dado fallo de envío, entonces queda auditado en `email_deliveries` sin bloquear el cambio de mail.

### Tickets relacionados

- UNQ-27 — Perfil de usuario

---

## US-07 — Operar y auditar envíos (equipo)

**Actor/es:** Equipo de desarrollo / operaciones  
**Funcionalidad:** Disparar jobs manualmente, revisar entregas, previsualizar templates y reintentar fallidos sin duplicar.  
**Valor que aporta:** Operación predecible en local y producción.

### Criterios de aceptación

- Dado entorno dev, cuando se usa preview o listado de deliveries, entonces no se requiere enviar mails reales.
- Dado `EMAIL_CRON_SECRET`, cuando se llama a `/internal/jobs/*` sin header válido, entonces responde 401.
- Dado filas `failed` recientes, cuando corre `retry-failed-emails`, entonces reintenta dentro de `EMAIL_RETRY_MAX_ATTEMPTS`.
- Dado `npm run validate:email-flow`, cuando corre con Brevo real, entonces valida el circuito completo en un solo comando.

**Cómo se valida:** `scripts/local/` · `GET /dev/email/deliveries` · `.github/workflows/email-cron.yml` · [Evidencia](Entrega-4-Evidencia).
