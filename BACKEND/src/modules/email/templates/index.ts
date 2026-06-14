import { EmailMessage, EmailTemplateKey } from '../email.types';
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

  const sample = EMAIL_TEMPLATE_DEFINITIONS[templateKey].sampleContext();
  const streakCount = Number.isFinite(params.streak_count)
    ? Math.max(1, Number(params.streak_count))
    : sample.streakCount;

  const context: StreakTemplateContext = {
    name: params.name?.trim() || sample.name,
    mail: params.mail?.trim() || sample.mail,
    streakCount
  };

  if (templateKey === 'streak_at_risk') {
    return EMAIL_TEMPLATE_DEFINITIONS.streak_at_risk.build(context);
  }

  return EMAIL_TEMPLATE_DEFINITIONS.streak_lost.build(context);
}

export { buildWelcomeEmail } from './welcome.template';
export { buildStreakAtRiskEmail } from './streak-at-risk.template';
export { buildStreakLostEmail } from './streak-lost.template';
