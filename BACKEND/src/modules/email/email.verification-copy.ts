import crypto from 'crypto';
import { emailConfig } from './email.config';
import { escapeHtml } from './templates/html-utils';

interface VerificationCopyPayload {
  c: string;
  e: number;
}

function signingSecret(): string {
  return emailConfig.verificationCopySecret;
}

function normalizeCode(code: string): string {
  return code.replace(/\D/g, '').slice(0, 6);
}

export function createVerificationCopyToken(code: string, expiresAt: Date): string | null {
  const secret = signingSecret();
  if (secret.length === 0) {
    return null;
  }

  const normalizedCode = normalizeCode(code);
  if (normalizedCode.length !== 6) {
    return null;
  }

  const payload = Buffer.from(
    JSON.stringify({
      c: normalizedCode,
      e: Math.floor(expiresAt.getTime() / 1000)
    } satisfies VerificationCopyPayload),
    'utf8'
  ).toString('base64url');

  const signature = crypto.createHmac('sha256', secret).update(payload).digest('base64url');
  return `${payload}.${signature}`;
}

export function parseVerificationCopyToken(token: string): { code: string } | null {
  const secret = signingSecret();
  if (secret.length === 0) {
    return null;
  }

  const [payload, signature] = token.split('.');
  if (!payload || !signature) {
    return null;
  }

  const expectedSignature = crypto.createHmac('sha256', secret).update(payload).digest('base64url');
  const signatureBuffer = Buffer.from(signature);
  const expectedBuffer = Buffer.from(expectedSignature);
  if (
    signatureBuffer.length !== expectedBuffer.length ||
    !crypto.timingSafeEqual(signatureBuffer, expectedBuffer)
  ) {
    return null;
  }

  try {
    const parsed = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as VerificationCopyPayload;
    const code = normalizeCode(parsed.c ?? '');
    const expiresAt = Number(parsed.e);
    if (code.length !== 6 || !Number.isFinite(expiresAt)) {
      return null;
    }
    if (Math.floor(Date.now() / 1000) > expiresAt) {
      return null;
    }
    return { code };
  } catch {
    return null;
  }
}

export function buildVerificationCopyPageUrl(code: string, expiresAt: Date): string | undefined {
  const baseUrl = emailConfig.publicBaseUrl.replace(/\/+$/, '');
  if (baseUrl.length === 0) {
    return undefined;
  }

  const token = createVerificationCopyToken(code, expiresAt);
  if (!token) {
    return undefined;
  }

  return `${baseUrl}/public/email/verification-copy/${encodeURIComponent(token)}`;
}

export function buildVerificationCopyPageHtml(code: string): string {
  const safeCode = escapeHtml(code);
  const safeCodeJson = JSON.stringify(code);

  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Copiar código · E-VIDENTE</title>
    <link href="https://fonts.googleapis.com/css2?family=Rubik:wght@400;500;700;900&display=swap" rel="stylesheet" />
    <style>
      body {
        margin: 0;
        min-height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 24px;
        background: #f4f7f2;
        font-family: 'Rubik', Arial, sans-serif;
        color: #3e382a;
      }
      .card {
        width: 100%;
        max-width: 420px;
        background: #ffffff;
        border: 1px solid #e2e4df;
        border-radius: 20px;
        box-shadow: 0 10px 40px rgba(40, 50, 40, 0.12);
        overflow: hidden;
      }
      .header {
        background: linear-gradient(155deg, #4a8a6a 0%, #42785e 45%, #2d5a45 100%);
        color: #ffffff;
        padding: 24px 24px 20px;
        text-align: center;
      }
      .header h1 {
        margin: 0;
        font-size: 22px;
        font-weight: 900;
      }
      .header p {
        margin: 8px 0 0;
        font-size: 13px;
        color: #c7d6a8;
      }
      .body {
        padding: 28px 24px 24px;
        text-align: center;
      }
      .code {
        display: inline-block;
        margin: 0 0 18px;
        padding: 16px 22px;
        border: 2px solid #f0d96a;
        border-radius: 14px;
        background: #fffbe6;
        font-size: 34px;
        font-weight: 900;
        letter-spacing: 0.24em;
        color: #4a3800;
        font-family: 'Rubik', 'Courier New', monospace;
      }
      button {
        appearance: none;
        border: 2px solid #dbc151;
        background: #42785e;
        color: #ffffff;
        border-radius: 999px;
        padding: 14px 28px;
        font-family: 'Rubik', Arial, sans-serif;
        font-size: 16px;
        font-weight: 700;
        cursor: pointer;
        box-shadow: 0 6px 18px rgba(66, 120, 94, 0.28);
      }
      button:disabled {
        opacity: 0.7;
        cursor: default;
      }
      .hint {
        margin: 14px 0 0;
        font-size: 13px;
        line-height: 1.5;
        color: #5c5347;
      }
      .status {
        min-height: 20px;
        margin-top: 12px;
        font-size: 14px;
        font-weight: 700;
        color: #42785e;
      }
    </style>
  </head>
  <body>
    <div class="card">
      <div class="header">
        <h1>Copiar código</h1>
        <p>E-VIDENTE · verificación de email</p>
      </div>
      <div class="body">
        <div class="code" id="code">${safeCode}</div>
        <button type="button" id="copy-btn">Copiar código</button>
        <p class="hint">Volvé al juego y pegá el código en la pantalla de verificación.</p>
        <div class="status" id="status" aria-live="polite"></div>
      </div>
    </div>
    <script>
      (function () {
        var code = ${safeCodeJson};
        var button = document.getElementById('copy-btn');
        var status = document.getElementById('status');

        async function copyCode() {
          try {
            if (navigator.clipboard && navigator.clipboard.writeText) {
              await navigator.clipboard.writeText(code);
            } else {
              var input = document.createElement('textarea');
              input.value = code;
              input.setAttribute('readonly', '');
              input.style.position = 'absolute';
              input.style.left = '-9999px';
              document.body.appendChild(input);
              input.select();
              document.execCommand('copy');
              document.body.removeChild(input);
            }
            status.textContent = 'Código copiado. Ya podés pegarlo en el juego.';
            button.textContent = 'Copiado';
            button.disabled = true;
          } catch (error) {
            status.textContent = 'No pudimos copiar automáticamente. Seleccioná el código de arriba.';
          }
        }

        button.addEventListener('click', copyCode);
      })();
    </script>
  </body>
</html>`;
}

export function buildVerificationCopyExpiredPageHtml(): string {
  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Código vencido · E-VIDENTE</title>
    <link href="https://fonts.googleapis.com/css2?family=Rubik:wght@400;500;700&display=swap" rel="stylesheet" />
    <style>
      body {
        margin: 0;
        min-height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 24px;
        background: #f4f7f2;
        font-family: 'Rubik', Arial, sans-serif;
        color: #3e382a;
      }
      .card {
        max-width: 420px;
        padding: 28px 24px;
        background: #ffffff;
        border: 1px solid #e2e4df;
        border-radius: 20px;
        text-align: center;
      }
      h1 { margin: 0 0 10px; font-size: 22px; color: #42785e; }
      p { margin: 0; line-height: 1.6; color: #5c5347; }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>Este enlace venció</h1>
      <p>Pedí un código nuevo desde el juego para verificar tu email.</p>
    </div>
  </body>
</html>`;
}
