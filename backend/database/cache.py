import time
from threading import Lock
from typing import Any, Callable, Dict, Tuple, TypeVar

from backend.config import Config

T = TypeVar("T")

_LOCK = Lock()
_CACHE: Dict[str, Tuple[float, Any]] = {}


def obter_ou_carregar(chave: str, loader: Callable[[], T], ttl: int = 120) -> T:
    """Cache em memória apenas em produção para metadados quase estáticos (TTL curto)."""
    if Config.APP_ENV != "production" or ttl <= 0:
        return loader()

    agora = time.monotonic()
    with _LOCK:
        item = _CACHE.get(chave)
        if item is not None and item[0] > agora:
            return item[1]

    valor = loader()
    with _LOCK:
        _CACHE[chave] = (time.monotonic() + ttl, valor)
    return valor


def invalidar_cache(*prefixos: str) -> None:
    """Remove entradas do cache em memória após mutações ou reset de engine."""
    with _LOCK:
        if not prefixos:
            _CACHE.clear()
            return
        for k in [chave for chave in _CACHE if any(chave.startswith(p) for p in prefixos)]:
            _CACHE.pop(k, None)
