import html
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import parseaddr
from pathlib import Path
from string import Template
from typing import Any, Dict

import requests

from backend.config import Config

TEMPLATE_RESET = Path(__file__).resolve().parent.parent / "templates" / "email" / "reset_senha.html"


class EmailService:
    """Envia o link de redefinição de senha conforme MAIL_MODO (smtp | console | resend | brevo)."""

    @staticmethod
    def _html_reset(nome: str, link: str) -> str:
        return Template(TEMPLATE_RESET.read_text(encoding="utf-8")).substitute(
            nome=html.escape(nome),
            link=html.escape(link, quote=True),
            validade=Config.RESET_TOKEN_EXPIRA_MIN,
        )

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
                server.sendmail(parseaddr(Config.MAIL_FROM)[1], [para], msg.as_string())
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
