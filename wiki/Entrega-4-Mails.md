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

**Cuándo:** registro exitoso con mail. **No** requiere checkbox de notificaciones.

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

**Cuándo:** jugó ayer, hoy no. Requiere `email_notifications_enabled = true`.

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
> Podés desactivar estos recordatorios desde tu perfil en el juego.

**Tono:** urgencia suave, sin culpa. El número de días es el dato que más motiva.

---

### 3. Racha perdida (`streak_lost`)

**Cuándo:** 2+ días sin actividad. Mismo consentimiento.

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
> Podés desactivar estos recordatorios desde tu perfil en el juego.

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

### 4. Probar envío real (opcional, dev)

En `.env`: `EMAIL_ENABLED=true` + credenciales Brevo. Registrar usuario de prueba o correr job de rachas con datos semilla.

Auditoría: `GET /dev/email/deliveries?limit=20`

### 5. Alinear copy en Godot (si aplica)

| Lugar | Qué revisar |
|-------|-------------|
| `juego/API/Login.tscn` | Hint del mail de bienvenida |
| `CheckBoxEmailNotifications` | “recordatorios de racha” (no “novedades” si no las enviamos) |
| `ProfileOverlayPanel` | Línea “Recordatorios mail: Sí/No” |

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

Correlacionar picos de `failed` con `error_message` y límites de rate de Brevo.

---

## Próximos mails (fuera de E4)

| Mail | Notas |
|------|-------|
| Recuperación de contraseña | Link firmado con TTL; ticket futuro |
| Verificación de cuenta | Cambia el copy de registro y el flujo de auth |
| Resumen semanal | Requiere job nuevo + template; distinto consentimiento |
