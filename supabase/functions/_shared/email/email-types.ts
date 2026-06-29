export interface EmailMessage {
  to: string;
  toName: string;
  subject: string;
  htmlContent: string;
  textContent: string;
}
