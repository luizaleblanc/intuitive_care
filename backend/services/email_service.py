import html
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Any, Dict

import requests

from backend.config import Config


class EmailService:
    """Envia o link de redefinição de senha conforme MAIL_MODO (smtp | console | resend | brevo)."""

    @staticmethod
    def _html_reset(nome: str, link: str) -> str:
        nome_seguro = html.escape(nome)
        link_seguro = html.escape(link, quote=True)
        return f"""\
<div style="margin:0;padding:32px 16px;background:#F2F4F3;font-family:Arial,sans-serif;color:#0F172A">
  <div style="max-width:520px;margin:0 auto;background:#FFFFFF;border-radius:16px;overflow:hidden">
    <div style="background:#113E32;padding:24px 32px;color:#FFFFFF;font-size:18px;font-weight:700">
      Intuitive <span style="color:#4AD295">Care</span>
    </div>
    <div style="padding:32px;font-size:15px;line-height:1.6">
      <p style="margin-top:0">Olá, <strong>{nome_seguro}</strong>.</p>
      <p>Recebemos um pedido para redefinir a senha da sua conta.</p>
      <p style="margin:28px 0">
        <a href="{link_seguro}" style="background:#4AD295;color:#113E32;padding:14px 28px;border-radius:999px;font-weight:700;text-decoration:none">Redefinir senha</a>
      </p>
      <p style="color:#64748B;font-size:13px;margin-bottom:0">
        O link vale por {Config.RESET_TOKEN_EXPIRA_MIN} minutos e só pode ser usado uma vez.
        Se você não fez esse pedido, ignore este e-mail.
      </p>
    </div>
  </div>
</div>"""

    @classmethod
    def enviar_reset_senha(cls, para: str, nome: str, link: str) -> Dict[str, Any]:
        modo = Config.MAIL_MODO.lower()
        assunto = "Intuitive Care - Redefinição de senha"
        corpo_html = cls._html_reset(nome, link)
        corpo_texto = (
            f"Olá, {nome}.\n\nPara redefinir sua senha, acesse:\n{link}\n\n"
            f"O link vale por {Config.RESET_TOKEN_EXPIRA_MIN} minutos e só pode ser usado uma vez."
        )

        if modo == "smtp":
            msg = MIMEMultipart("alternative")
            msg["Subject"] = assunto
            msg["From"] = Config.MAIL_FROM
            msg["To"] = para
            msg.attach(MIMEText(corpo_texto, "plain", "utf-8"))
            msg.attach(MIMEText(corpo_html, "html", "utf-8"))
            with smtplib.SMTP(Config.MAIL_HOST, Config.MAIL_PORT, timeout=10) as server:
                server.ehlo()
                # O Mailpit local não usa TLS; credenciais nunca trafegam sem ele.
                if server.has_extn("starttls"):
                    server.starttls()
                    server.ehlo()
                    if Config.MAIL_USER:
                        server.login(Config.MAIL_USER, Config.MAIL_PASSWORD)
                elif Config.MAIL_USER:
                    raise RuntimeError("Servidor SMTP sem STARTTLS: credenciais não enviadas.")
                server.sendmail(Config.MAIL_FROM, [para], msg.as_string())
            return {"provider": "smtp", "delivered": True}

        if modo == "resend" and Config.RESEND_API_KEY:
            response = requests.post(
                "https://api.resend.com/emails",
                headers={"Authorization": f"Bearer {Config.RESEND_API_KEY}"},
                json={"from": Config.MAIL_FROM, "to": [para], "subject": assunto,
                      "html": corpo_html, "text": corpo_texto},
                timeout=10,
            )
            response.raise_for_status()
            return {"provider": "resend", "delivered": True}

        if modo == "brevo" and Config.BREVO_API_KEY:
            response = requests.post(
                "https://api.brevo.com/v3/smtp/email",
                headers={"api-key": Config.BREVO_API_KEY},
                json={"sender": {"name": "Intuitive Care", "email": Config.MAIL_FROM},
                      "to": [{"email": para, "name": nome}], "subject": assunto,
                      "htmlContent": corpo_html, "textContent": corpo_texto},
                timeout=10,
            )
            response.raise_for_status()
            return {"provider": "brevo", "delivered": True}

        # Modo console: o link só aparece no log fora de produção.
        if Config.APP_ENV != "production":
            print(f"[EMAIL][console] Para: {para} | Link: {link}", flush=True)
        return {"provider": "console", "delivered": False}
