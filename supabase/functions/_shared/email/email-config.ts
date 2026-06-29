export interface EdgeEmailConfig {
  appPlayUrl: string;
}

export function getEmailConfig(): EdgeEmailConfig {
  return {
    appPlayUrl: (Deno.env.get('EMAIL_APP_PLAY_URL') ?? Deno.env.get('APP_PLAY_URL') ?? '').trim(),
  };
}
