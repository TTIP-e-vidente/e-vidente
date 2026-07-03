# Entrega 4 — E-VIDENTE

## Resumen ejecutivo

Mails transaccionales con Brevo, verificación OTP, recordatorios de racha con consentimiento y auditoría en base de datos. El stack productivo corre en **Supabase Edge Functions + Postgres + pg_cron**; Godot solo habla HTTP con el backend y **nunca ve la API key de Brevo**. El save local, el sync de progreso y el dominio del juego (E1/E2) siguen igual — E4 es una capa transversal de comunicación sobre la infraestructura E3.

## Qué se agregó o modificó

- **Proveedor de mail** — integración Brevo (API transaccional), templates HTML versionados en código, interruptor `EMAIL_ENABLED` para dev/CI.
- **Verificación OTP** — código de 6 dígitos al registrarse o cambiar mail; UI en Godot (`EmailVerification`); `mail_verified_at` en Postgres antes de bienvenida o recordatorios.
- **Cinco correos** — `email_verification`, `welcome` (post-OTP), `streak_at_risk`, `streak_lost`, `mail_changed` (aviso al mail anterior).
- **Consentimiento** — opt-in en registro y toggle en perfil (`email_notifications_enabled`); rachas por mail solo con flag activo y mail verificado.
- **Jobs programados** — `pg_cron` en Supabase dispara Edge `internal-job`: racha en riesgo (18:00 ART), racha perdida (00:00 ART), reintentos (08:00 / 20:00 ART).
- **Auditoría** — tabla `email_deliveries` con dedupe, estados, retry y `provider_message_id` de Brevo.
- **Supabase Edge** — `verify-email-request/confirm`, módulo email compartido, secrets Brevo en Edge; reemplaza Express en staging (`api_mode=supabase_edge`).
- **Godot dual local/cloud** — `backend.local.json` con `api_mode` (`supabase_edge` / `auto` / `local`); cache de sesión para flags de mail; `save_data.json` v4 sin cambio de esquema.
- **MER y persistencia** — 2 tablas nuevas (`email_deliveries`, `email_verification_codes`) + columnas en `users`.
- **In-game** — badge de racha en riesgo en HUD, panel `StreakLossMessagePanel` al perder racha (complemento al mail).

## Desafíos técnicos

- Evitar mails duplicados si el cron o el retry corre dos veces (`dedupe_key` + estado `pending` en `email_deliveries`).
- Separar transaccional (OTP, bienvenida, seguridad) de recordatorios de hábito (requieren opt-in explícito).
- No bloquear registro ni gameplay si Brevo falla — outbox async y reconcile de racha independiente del envío.
- Impedir mails a direcciones typo o falsas — OTP obligatorio antes de recordatorios.
- Mantener Godot desacoplado de Brevo y de SQL de mail — solo REST a Edge; auditoría centralizada en servidor.
- Convivir Express (tests locales) y Supabase Edge (staging/juego online) sin duplicar lógica de negocio.
- Zona horaria única ART para candidatos de racha (`EMAIL_TIMEZONE`).

-- 

## Evidencia 
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/0abdaa66-4a29-484a-ab49-d183713c81cc" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/e4f4e8fd-f062-470a-9713-c604f0bbd955" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/6d402a73-416c-4229-9deb-f24782080c81" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/d72f24da-16df-4801-9d25-3f995dc34cb1" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/533097f3-d544-4f00-a7c5-2f4e45d70d41" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/21417d56-d4c5-40c3-b432-10f2fd5bd569" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/47feeaa6-5266-47e1-a492-a5e4173fe467" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/1ddb7746-37f9-4df4-a0b2-bf413271008c" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/e5e93c27-b1d9-421e-a47c-418d0dffe789" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/85c0cfa1-e74f-4484-93dc-90737a360f7e" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/2632f8f1-7a37-4258-86dc-4c149161bad7" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/1e38eccd-c96f-4937-a412-0323735fb8a7" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/7dec1b98-6e18-4911-82cd-d5a596f8a3d2" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/50d7ea6a-e5da-490b-94dc-29d2c9d694f2" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/b8b5ee4a-1d49-4dc6-bae4-dd9d83e7a92a" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/cb9614eb-5ffc-4432-83f3-b90d67a3e1ed" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/38185309-edf7-46d7-8d57-4d8ae4b24a8c" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/c4782556-9d3c-4057-8f21-b31c13b53251" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/351d713a-d58b-499a-a524-496765cbbe88" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/65a6dcec-8175-4cd8-b49c-e20695d436a5" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/9eca7a0b-f029-4ebb-9c6d-ba328780a606" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/103ae9e7-945b-4887-8ad8-5666029d1c0b" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/1b4dc093-5223-4764-9f13-83af09ffdf4a" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/2d2281e2-209a-4be2-b996-05170261d691" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/ab03c394-53ed-4d4b-8b65-7d2dcc665a14" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/416912a7-8c34-4263-8b2a-c3d6c01ced21" />

