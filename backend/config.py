import os

_RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _carregar_env():
    """Carrega variáveis de `.env` (raiz do projeto e backend/) sem sobrescrever as já definidas."""
    for caminho in (os.path.join(_RAIZ, ".env"), os.path.join(_RAIZ, "backend", ".env")):
        if not os.path.exists(caminho):
            continue
        with open(caminho, encoding="utf-8") as arquivo:
            for linha in arquivo:
                linha = linha.strip()
                if not linha or linha.startswith("#") or "=" not in linha:
                    continue
                chave, valor = linha.split("=", 1)
                os.environ.setdefault(chave.strip(), valor.strip().strip('"').strip("'"))


_carregar_env()


class Config:
    """Configurações centralizadas da aplicação Flask."""

    APP_ENV = os.getenv("APP_ENV", "development")
    DEBUG = os.getenv("FLASK_DEBUG", "false").lower() == "true"

    # Banco de Dados (MySQL como SGBD padrão; SQLite suportado para testes/demo offline)
    DB_ENGINE = os.getenv("DB_ENGINE", "mysql")
    DB_USER = os.getenv("DB_USER", "root")
    DB_PASSWORD = os.getenv("DB_PASSWORD", "root")
    DB_HOST = os.getenv("DB_HOST", "localhost")
    DB_PORT = os.getenv("DB_PORT", "3306")
    DB_NAME = os.getenv("DB_NAME", "intuitive_care")
    SQLITE_PATH = os.getenv("SQLITE_PATH", os.path.join(os.path.dirname(__file__), "database", "intuitive_care_local.db"))

    # Segurança e Tokens de Sessão
    SECRET_KEY = os.getenv("SECRET_KEY", "intuitive-care-uninassau-secret-key-2026")
    TOKEN_EXPIRATION_HOURS = int(os.getenv("TOKEN_EXPIRATION_HOURS", "12"))
    RESET_CODE_EXPIRATION_MINUTES = int(os.getenv("RESET_CODE_EXPIRATION_MINUTES", "15"))

    # Serviço de E-mail via API externa (Resend / Brevo) ou SMTP
    EMAIL_PROVIDER = os.getenv("EMAIL_PROVIDER", "mock")  # mock | resend | brevo | smtp
    EMAIL_FROM = os.getenv("EMAIL_FROM", "noreply@intuitivecare.local")
    RESEND_API_KEY = os.getenv("RESEND_API_KEY", "")
    BREVO_API_KEY = os.getenv("BREVO_API_KEY", "")
    SMTP_HOST = os.getenv("SMTP_HOST", "")
    SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USER = os.getenv("SMTP_USER", "")
    SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")

    @classmethod
    def get_database_url(cls) -> str:
        explicit_url = os.getenv("DATABASE_URL")
        if explicit_url:
            return explicit_url
        if cls.DB_ENGINE.lower() == "sqlite":
            return f"sqlite:///{cls.SQLITE_PATH}"
        return f"mysql+pymysql://{cls.DB_USER}:{cls.DB_PASSWORD}@{cls.DB_HOST}:{cls.DB_PORT}/{cls.DB_NAME}?charset=utf8mb4"
