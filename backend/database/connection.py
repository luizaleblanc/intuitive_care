import os
from contextlib import contextmanager
from typing import Any, Dict, Generator, Optional, Union

from sqlalchemy import create_engine, event, text
from sqlalchemy.engine import URL, Connection, Engine, make_url
from sqlalchemy.pool import NullPool, StaticPool

from backend.config import Config

_engine: Optional[Engine] = None
_engine_url: Optional[Union[str, URL]] = None


def argumentos_conexao(url: Union[str, URL]) -> Dict[str, Any]:
    """O TiDB Cloud exige TLS com verificação do certificado."""
    host = make_url(url).host or ""
    if host.endswith(".tidbcloud.com"):
        import certifi

        return {"ssl": {"ca": certifi.where()}}
    return {}


def get_engine(database_url: Optional[Union[str, URL]] = None) -> Engine:
    """Retorna uma instância singleton de SQLAlchemy Engine configurada."""
    global _engine, _engine_url
    target_url = database_url or Config.get_database_url()

    if _engine is not None and _engine_url == target_url:
        return _engine

    connect_args = argumentos_conexao(target_url)
    pool_kwargs: Dict[str, Any] = {"pool_pre_ping": True}
    if os.getenv("VERCEL"):
        # Funções serverless não devem manter conexões abertas entre execuções.
        pool_kwargs = {"poolclass": NullPool}

    if str(target_url).startswith("sqlite"):
        connect_args["check_same_thread"] = False
        if ":memory:" in str(target_url):
            pool_kwargs = {"poolclass": StaticPool}

    engine = create_engine(target_url, connect_args=connect_args, future=True, **pool_kwargs)

    if str(target_url).startswith("sqlite"):
        @event.listens_for(engine, "connect")
        def _enable_sqlite_fks(dbapi_connection, _connection_record):
            cursor = dbapi_connection.cursor()
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.close()

    _engine = engine
    _engine_url = target_url
    return _engine


def reset_engine() -> None:
    """Descarta o engine atual (útil em testes automatizados)."""
    global _engine, _engine_url
    if _engine is not None:
        _engine.dispose()
    _engine = None
    _engine_url = None


@contextmanager
def get_connection(database_url: Optional[Union[str, URL]] = None) -> Generator[Connection, None, None]:
    """Gerenciador de contexto transacional para acesso ao banco."""
    engine = get_engine(database_url)
    with engine.begin() as conn:
        yield conn


def check_database_health(database_url: Optional[Union[str, URL]] = None) -> bool:
    """Executa uma consulta simples para validar conectividade com o SGBD."""
    try:
        engine = get_engine(database_url)
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
