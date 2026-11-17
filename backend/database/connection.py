from contextlib import contextmanager
from typing import Generator, Optional

from sqlalchemy import create_engine, event, text
from sqlalchemy.engine import Connection, Engine
from sqlalchemy.pool import StaticPool

from backend.config import Config

_engine: Optional[Engine] = None
_engine_url: Optional[str] = None


def get_engine(database_url: Optional[str] = None) -> Engine:
    """Retorna uma instância singleton de SQLAlchemy Engine configurada."""
    global _engine, _engine_url
    target_url = database_url or Config.get_database_url()

    if _engine is not None and _engine_url == target_url:
        return _engine

    connect_args = {}
    pool_kwargs = {"pool_pre_ping": True}

    if target_url.startswith("sqlite"):
        connect_args["check_same_thread"] = False
        if ":memory:" in target_url:
            pool_kwargs = {"poolclass": StaticPool}

    engine = create_engine(target_url, connect_args=connect_args, future=True, **pool_kwargs)

    if target_url.startswith("sqlite"):
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
def get_connection(database_url: Optional[str] = None) -> Generator[Connection, None, None]:
    """Gerenciador de contexto transacional para acesso ao banco."""
    engine = get_engine(database_url)
    with engine.begin() as conn:
        yield conn


def check_database_health(database_url: Optional[str] = None) -> bool:
    """Executa uma consulta simples para validar conectividade com o SGBD."""
    try:
        engine = get_engine(database_url)
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
