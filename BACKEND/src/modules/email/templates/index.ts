import { EmailMessage, EmailTemplateKey } from '../email.types';
import { buildEmailVerificationEmail } from './email-verification.template';
import { buildMailChangedEmail } from './mail-changed.template';
import { buildStreakAtRiskEmail } from './streak-at-risk.template';
import { buildStreakLostEmail } from './streak-lost.template';
import {
  EmailTemplateDefinition,
  EmailTemplatePreviewParams,
  StreakTemplateContext,
  TemplateContextByKey
} from './types';
import { buildWelcomeEmail } from './welcome.template';

export const EMAIL_TEMPLATE_DEFINITIONS: {
  [K in EmailTemplateKey]: EmailTemplateDefinition<K>;
} = {
  welcome: {
    key: 'welcome',
    title: 'Bienvenida',
    description: 'Confirmación de cuenta creada. Se envía siempre si hay mail (transaccional).',
    sampleContext: () => ({
      name: 'Jugador',
      mail: 'jugador@example.com'
    }),
    build: buildWelcomeEmail
  },
  streak_at_risk: {
    key: 'streak_at_risk',
    title: 'Racha en riesgo',
    description: 'Aviso preventivo: jugó ayer y hoy todavía no registró actividad.',
    sampleContext: () => ({
      name: 'Jugador',
      mail: 'jugador@example.com',
      streakCount: 5
    }),
    build: buildStreakAtRiskEmail
  },
  streak_lost: {
    key: 'streak_lost',
    title: 'Racha perdida',
    description: 'Aviso de racha cortada por inactividad prolongada.',
    sampleContext: () => ({
      name: 'Jugador',
      mail: 'jugador@example.com',
      streakCount: 5
    }),
    build: buildStreakLostEmail
  },
  email_verification: {
    key: 'email_verification',
    title: 'Verificación de email',
    description: 'Código OTP para confirmar que el email pertenece al usuario.',
    sampleContext: () => ({
      name: 'Jugador',
      mail: 'jugador@example.com',
      code: '123456',
      expiresMinutes: 15
    }),
    build: buildEmailVerificationEmail
  },
  mail_changed: {
    key: 'mail_changed',
    title: 'Email cambiado',
    description: 'Notificación de seguridad al mail anterior cuando el usuario actualiza su email.',
    sampleContext: () => ({
      name: 'Jugador',
      oldMail: 'anterior@example.com',
      newMail: 'nuevo@example.com'
    }),
    build: buildMailChangedEmail
  }
};

export function listEmailTemplateMetadata() {
  return (Object.values(EMAIL_TEMPLATE_DEFINITIONS) as EmailTemplateDefinition[]).map(
    (definition) => ({
      key: definition.key,
      title: definition.title,
      description: definition.description,
      sample_params: definition.sampleContext()
    })
  );
}

export function buildEmailMessage<K extends EmailTemplateKey>(
  templateKey: K,
  context: TemplateContextByKey[K]
): EmailMessage {
  return EMAIL_TEMPLATE_DEFINITIONS[templateKey].build(context);
}

export function previewEmailTemplate(
  templateKey: EmailTemplateKey,
  params: EmailTemplatePreviewParams = {}
): EmailMessage {
  if (templateKey === 'welcome') {
    const sample = EMAIL_TEMPLATE_DEFINITIONS.welcome.sampleContext();
    return EMAIL_TEMPLATE_DEFINITIONS.welcome.build({
      name: params.name?.trim() || sample.name,
      mail: params.mail?.trim() || sample.mail
    });
  }

  if (templateKey === 'email_verification') {
    const sample = EMAIL_TEMPLATE_DEFINITIONS.email_verification.sampleContext();
    return EMAIL_TEMPLATE_DEFINITIONS.email_verification.build({
      name: params.name?.trim() || sample.name,
      mail: params.mail?.trim() || sample.mail,
      code: sample.code,
      expiresMinutes: sample.expiresMinutes
    });
  }

  if (templateKey === 'mail_changed') {
    const sample = EMAIL_TEMPLATE_DEFINITIONS.mail_changed.sampleContext();
    return EMAIL_TEMPLATE_DEFINITIONS.mail_changed.build({
      name: params.name?.trim() || sample.name,
      oldMail: sample.oldMail,
      newMail: sample.newMail
    });
  }

  const sample = EMAIL_TEMPLATE_DEFINITIONS[templateKey as 'streak_at_risk' | 'streak_lost'].sampleContext();
  const streakCount = Number.isFinite(params.streak_count)
    ? Math.max(1, Number(params.streak_count))
    : (sample as { streakCount: number }).streakCount;

  const context: StreakTemplateContext = {
    name: params.name?.trim() || (sample as { name: string }).name,
    mail: params.mail?.trim() || (sample as { mail: string }).mail,
    streakCount
  };

  if (templateKey === 'streak_at_risk') {
    return EMAIL_TEMPLATE_DEFINITIONS.streak_at_risk.build(context);
  }

  return EMAIL_TEMPLATE_DEFINITIONS.streak_lost.build(context);
}
