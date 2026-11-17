from typing import Any, Dict

from backend.repositories.despesa_repository import DespesaRepository


class EstatisticaService:
    """Regras analíticas e indicadores consolidados calculados no backend."""

    @staticmethod
    def obter_dashboard() -> Dict[str, Any]:
        stats = DespesaRepository.get_dashboard_statistics()
        serie = stats.get("serie_trimestral", [])

        crescimento_percentual = 0.0
        if len(serie) >= 2 and serie[0]["total"] > 0:
            inicio = serie[0]["total"]
            fim = serie[-1]["total"]
            crescimento_percentual = round(((fim - inicio) / inicio) * 100, 2)

        stats["crescimento_periodo_pct"] = crescimento_percentual
        return stats
