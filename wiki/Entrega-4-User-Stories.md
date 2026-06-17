# User Stories — Entrega 4

Historias de usuario de la Entrega 4 (emails y notificaciones por correo).

---

## US-01 — Recibir confirmación de cuenta por mail

**Actor/es:** Jugador nuevo  
**Funcionalidad:** Al registrarse con un mail válido, recibir un correo de bienvenida que confirme que la cuenta fue creada.  
**Valor que aporta:** Refuerza confianza y deja constancia del alta sin bloquear el registro si el envío falla.

### Criterios de aceptación

- Dado que el jugador se registra con mail, cuando el alta es exitosa, entonces el backend encola un mail de bienvenida de forma asíncrona.
- Dado que Brevo no está configurado o `EMAIL_ENABLED=false`, cuando se registra, entonces la cuenta se crea igual y el envío se omite con log.
- Dado que ya se envió bienvenida, cuando se reintenta, entonces no se duplica (`dedupe_key = welcome`).
- Dado el mail enviado, cuando el jugador lo abre, entonces el tono y diseño son coherentes con E-VIDENTE.

### Tickets relacionados

- UNQ-64 (alcance ampliado: bienvenida + rachas)
- UNQ-90 — Registro de usuario

**Cómo se valida:** registro con mail → fila `email_deliveries` con `template_key=welcome` y `status=sent`; preview dev; copy en [Entrega-4-Mails](Entrega-4-Mails).

---

## US-02 — Elegir si quiero recordatorios por mail

**Actor/es:** Jugador  
**Funcionalidad:** Activar o desactivar recordatorios de racha al registrarse y desde el perfil.  
**Valor que aporta:** Consentimiento explícito; cumplimiento de buenas prácticas y menor riesgo de spam.

### Criterios de aceptación

- Dado el formulario de registro, cuando el jugador marca o desmarca la casilla, entonces `accept_email_notifications` persiste en `users.email_notifications_enabled`.
- Dado sesión activa, cuando edita perfil y cambia la preferencia, entonces `PATCH /player/me` actualiza el flag.
- Dado `email_notifications_enabled = false`, cuando corre el job de rachas, entonces no recibe `streak_at_risk` ni `streak_lost`.
- Dado consentimiento desactivado, cuando se registra, entonces igual puede recibir bienvenida si hay mail (transaccional).

### Tickets relacionados

- UNQ-64
- UNQ-27 — Perfil de usuario

---

## US-03 — Aviso por mail cuando mi racha está en riesgo

**Actor/es:** Jugador con racha activa y notificaciones habilitadas  
**Funcionalidad:** Recibir un mail si jugó ayer pero hoy aún no hay actividad registrada.  
**Valor que aporta:** Recordatorio fuera del juego para sostener el hábito diario (objetivo UNQ-64).

### Criterios de aceptación

- Dado racha `current_count > 0` y última actividad ayer, cuando corre el cron del día (19:00 ART), entonces se envía como máximo un `streak_at_risk` por usuario y fecha.
- Dado que el jugador juega después del mail, cuando corre el cron del día siguiente, entonces no recibe otro “en riesgo” por el mismo día.
- Dado mail inválido o fallo de Brevo, cuando falla el envío, entonces queda `failed` y puede reintentarse según política de retry.

### Tickets relacionados

- UNQ-64 — Notificaciones por email para racha diaria en riesgo
- UNQ-83 — Indicador visual de racha (complemento in-game)

---

## US-04 — Enterarme por mail si perdí la racha

**Actor/es:** Jugador con notificaciones habilitadas  
**Funcionalidad:** Recibir aviso cuando pasaron 2+ días sin actividad; la racha se reinicia en backend al correr el job (reconcile), independiente del envío del mail.  
**Valor que aporta:** Cierre claro del ciclo de racha, alineado al mensaje in-game de pérdida.

### Criterios de aceptación

- Dado última actividad hace 2 o más días, cuando corre el cron, entonces se envía `streak_lost` una vez por `dedupe_key` basado en el último día activo.
- Dado inactividad de 2+ días, cuando finaliza el job, entonces `reconcileExpiredStreaksInDatabase` pone `streaks.current_count = 0` (aunque falle Brevo).
- Dado el contenido del mail, cuando lo lee el jugador, entonces el tono es empático y ofrece reenganche sin culpa.

### Tickets relacionados

- UNQ-149 — Mensaje de pérdida de racha (in-game)
- UNQ-64

---

## US-05 — Operar y auditar envíos (equipo)

**Actor/es:** Equipo de desarrollo / operaciones  
**Funcionalidad:** Disparar jobs manualmente, revisar entregas y reintentar fallidos sin duplicar.  
**Valor que aporta:** Operación predecible en local y producción.

### Criterios de aceptación

- Dado entorno dev, cuando se usa preview o listado de deliveries, entonces no se requiere enviar mails reales.
- Dado `EMAIL_CRON_SECRET`, cuando se llama a `/internal/jobs/*` sin header válido, entonces responde 401.
- Dado filas `failed` recientes, cuando corre `retry-failed-emails`, entonces reintenta dentro de `EMAIL_RETRY_MAX_ATTEMPTS`.

**Cómo se valida:** scripts en `scripts/local/`; `GET /dev/email/deliveries`; workflow `email-cron.yml` documentado.
