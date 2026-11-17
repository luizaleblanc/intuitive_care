import smtplib
from email.mime.text import MIMEText
from typing import Any, Dict

import requests

from backend.config import Config


class EmailService:
    """Serviço de envio de e-mails para recuperação de senha via API REST (Resend/Brevo) ou SMTP."""

    @staticmethod
    def send_password_recovery_email(to_email: str, user_name: str, recovery_code: str) -> Dict[str, Any]:
        provider = Config.EMAIL_PROVIDER.lower()
        subject = "Intuitive Care - Código de Recuperação de Senha"
        html_body = (
            f"<p>Olá, <strong>{user_name}</strong>,</p>"
            f"<p>Recebemos uma solicitação de recuperação de senha para a sua conta no "
            f"<strong>Intuitive Care</strong>.</p>"
            f"<p>Seu código de verificação é: <strong style='font-size:18px'>{recovery_code}</strong></p>"
            f"<p>Este código expira em {Config.RESET_CODE_EXPIRATION_MINUTES} minutos.</p>"
        )
        text_body = (
            f"Olá, {user_name}.\n\n"
            f"Seu código de recuperação de senha no Intuitive Care é: {recovery_code}\n"
            f"Validade: {Config.RESET_CODE_EXPIRATION_MINUTES} minutos."
        )

        if provider == "resend" and Config.RESEND_API_KEY:
            response = requests.post(
                "https://api.resend.com/emails",
                headers={
                    "Authorization": f"Bearer {Config.RESEND_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "from": Config.EMAIL_FROM,
                    "to": [to_email],
                    "subject": subject,
                    "html": html_body,
                    "text": text_body,
                },
                timeout=10,
            )
            response.raise_for_status()
            return {"provider": "resend", "delivered": True, "external_id": response.json().get("id")}

        if provider == "brevo" and Config.BREVO_API_KEY:
            response = requests.post(
                "https://api.brevo.com/v3/smtp/email",
                headers={
                    "api-key": Config.BREVO_API_KEY,
                    "Content-Type": "application/json",
                },
                json={
                    "sender": {"name": "Intuitive Care", "email": Config.EMAIL_FROM},
                    "to": [{"email": to_email, "name": user_name}],
                    "subject": subject,
                    "htmlContent": html_body,
                    "textContent": text_body,
                },
                timeout=10,
            )
            response.raise_for_status()
            return {"provider": "brevo", "delivered": True, "external_id": response.json().get("messageId")}

        if provider == "smtp" and Config.SMTP_HOST:
            msg = MIMEText(text_body, "plain", "utf-8")
            msg["Subject"] = subject
            msg["From"] = Config.EMAIL_FROM
            msg["To"] = to_email
            with smtplib.SMTP(Config.SMTP_HOST, Config.SMTP_PORT, timeout=10) as server:
                server.starttls()
                if Config.SMTP_USER and Config.SMTP_PASSWORD:
                    server.login(Config.SMTP_USER, Config.SMTP_PASSWORD)
                server.sendmail(Config.EMAIL_FROM, [to_email], msg.as_string())
            return {"provider": "smtp", "delivered": True}

        # Fallback seguro para ambientes acadêmicos locais sem credenciais SMTP/API configuradas
        print(f"[EMAIL_SERVICE][MODO_DEV] Para: {to_email} | Código de Recuperação: {recovery_code}")
        return {
            "provider": "simulated_api",
            "delivered": True,
            "preview_code": recovery_code if Config.APP_ENV in ("development", "test") else None,
        }
