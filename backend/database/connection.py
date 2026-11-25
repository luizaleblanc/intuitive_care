import os
from contextlib import contextmanager
from typing import Any, Dict, Generator, Optional, Union

from flask import g, has_request_context
from sqlalchemy import create_engine, event, text
from sqlalchemy.engine import URL, Connection, Engine, make_url
from sqlalchemy.pool import StaticPool

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
    pool_kwargs: Dict[str, Any] = {"pool_pre_ping": True, "pool_recycle": 300}
    if os.getenv("VERCEL") and not str(target_url).startswith("sqlite"):
        # Mantém até 1 conexão reutilizável por container quente evitando handshakes TLS repetidos.
        pool_kwargs = {
            "pool_size": 1,
            "max_overflow": 1,
            "pool_recycle": 55,
            "pool_pre_ping": True,
        }

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


def close_request_connection(_exc: Optional[BaseException] = None) -> None:
    """Devolve ao pool a conexão aberta durante a requisição HTTP atual."""
    if not has_request_context():
        return
    conn = g.pop("_db_conn", None)
    g.pop("_db_engine", None)
    if conn is not None:
        try:
            conn.close()
        except Exception:
            pass


def reset_engine() -> None:
    """Descarta o engine atual (útil em testes automatizados)."""
    global _engine, _engine_url
    from backend.database.cache import invalidar_cache

    invalidar_cache()
    close_request_connection()
    if _engine is not None:
        _engine.dispose()
    _engine = None
    _engine_url = None


@contextmanager
def get_connection(database_url: Optional[Union[str, URL]] = None) -> Generator[Connection, None, None]:
    """Gerenciador de contexto transacional com reuso de conexão por requisição HTTP."""
    engine = get_engine(database_url)
    if database_url is None and has_request_context():
        conn: Optional[Connection] = getattr(g, "_db_conn", None)
        if conn is None or getattr(g, "_db_engine", None) is not engine or conn.closed or conn.invalidated:
            close_request_connection()
            conn = engine.connect()
            g._db_conn = conn
            g._db_engine = engine
        try:
            if conn.in_transaction():
                with conn.begin_nested():
                    yield conn
            else:
                with conn.begin():
                    yield conn
        except Exception:
            if conn.closed or conn.invalidated:
                close_request_connection()
            raise
        return

    with engine.begin() as conn:
        yield conn


def check_database_health(database_url: Optional[Union[str, URL]] = None) -> bool:
    """Executa uma consulta simples para validar conectividade com o SGBD."""
    try:
        with get_connection(database_url) as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
