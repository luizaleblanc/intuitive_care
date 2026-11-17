"""Extração dos dados abertos da ANS.

Baixa:
  * Demonstrações contábeis trimestrais (ZIP -> CSV) dos últimos N anos;
  * Cadastro de operadoras ativas (Relatorio_cadop.csv) e canceladas
    (Relatorio_cadop_canceladas.csv -> status "Inativa");
  * Beneficiários por operadora (Beneficiarios_operadora_e_carteira.csv).

Uso:  python etl/scraping.py [--anos 2]
"""
import argparse
import io
import os
import re
import zipfile
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

BASE_URL = "https://dadosabertos.ans.gov.br/FTP/PDA/demonstracoes_contabeis/"
PDA = "https://dadosabertos.ans.gov.br/FTP/PDA/"
ARQUIVOS_CADASTRAIS = {
    "Relatorio_cadop.csv": PDA + "operadoras_de_plano_de_saude_ativas/Relatorio_cadop.csv",
    "Relatorio_cadop_canceladas.csv": PDA + "operadoras_de_plano_de_saude_canceladas/Relatorio_cadop_canceladas.csv",
    "Beneficiarios_operadora_e_carteira.csv": (
        PDA + "beneficiarios_vinculos_tipo_contratacao_vda/Beneficiarios_operadora_e_carteira.csv"
    ),
}
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(BASE_DIR, "data", "raw")
HEADERS = {"User-Agent": "intuitive-care-etl/1.0"}
PADRAO_TRIMESTRE = re.compile(r"([1-4])T(\d{4})", re.IGNORECASE)


def listar_links(url):
    try:
        resp = requests.get(url, timeout=30, headers=HEADERS)
        resp.raise_for_status()
    except requests.RequestException as erro:
        print(f"Falha ao listar {url}: {erro}")
        return []
    soup = BeautifulSoup(resp.text, "html.parser")
    return [a["href"] for a in soup.find_all("a", href=True) if not a["href"].startswith(("?", "/"))]


def baixar_zip(url):
    nome = url.rsplit("/", 1)[-1]
    match = PADRAO_TRIMESTRE.search(nome)
    if match:
        destino = os.path.join(OUTPUT_DIR, f"{match.group(1)}T{match.group(2)}.csv")
        if os.path.exists(destino):
            print(f"Já existe, pulando: {os.path.basename(destino)}")
            return
    print(f"Baixando: {nome}...")
    try:
        resp = requests.get(url, timeout=300, headers=HEADERS)
        resp.raise_for_status()
        with zipfile.ZipFile(io.BytesIO(resp.content)) as zf:
            for membro in zf.namelist():
                if not membro.lower().endswith(".csv"):
                    continue
                # Padroniza o nome para "<T>T<ANO>.csv" (usado pelo processamento).
                m = PADRAO_TRIMESTRE.search(membro) or match
                alvo = f"{m.group(1)}T{m.group(2)}.csv" if m else os.path.basename(membro)
                with zf.open(membro) as origem, open(os.path.join(OUTPUT_DIR, alvo), "wb") as saida:
                    saida.write(origem.read())
                print(f"  -> {alvo}")
    except (requests.RequestException, zipfile.BadZipFile) as erro:
        print(f"Falha em {nome}: {erro}")


def baixar_cadastros():
    """Baixa os arquivos cadastrais (sempre a versão mais recente publicada)."""
    for nome, url in ARQUIVOS_CADASTRAIS.items():
        print(f"Baixando {nome}...")
        destino = os.path.join(OUTPUT_DIR, nome)
        with requests.get(url, timeout=600, headers=HEADERS, stream=True) as resp:
            resp.raise_for_status()
            with open(destino + ".part", "wb") as f:
                for bloco in resp.iter_content(chunk_size=1 << 20):
                    f.write(bloco)
        os.replace(destino + ".part", destino)


def main(qtd_anos=2):
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    baixar_cadastros()

    print(f"Varrendo: {BASE_URL}")
    anos = sorted({a.strip("/") for a in listar_links(BASE_URL) if a.strip("/").isdigit()}, reverse=True)
    for ano in anos[:qtd_anos]:
        url_ano = urljoin(BASE_URL, f"{ano}/")
        for item in sorted(listar_links(url_ano), reverse=True):
            url_item = urljoin(url_ano, item)
            if item.lower().endswith(".zip"):
                baixar_zip(url_item)
            elif item.endswith("/"):
                for z in listar_links(url_item):
                    if z.lower().endswith(".zip"):
                        baixar_zip(urljoin(url_item, z))
    print("\nScraping finalizado.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--anos", type=int, default=2, help="Quantos anos mais recentes baixar")
    main(parser.parse_args().anos)
