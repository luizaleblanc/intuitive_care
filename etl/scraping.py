import os
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import zipfile
import io

BASE_URL = "https://dadosabertos.ans.gov.br/FTP/PDA/demonstracoes_contabeis/"
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(BASE_DIR, "data", "raw")

def get_soup(url):
    try:
        response = requests.get(url, timeout=15)
        response.raise_for_status()
        return BeautifulSoup(response.text, 'html.parser')
    except Exception:
        return None

def listar_links(url):
    soup = get_soup(url)
    if not soup: return []
    return [a.get('href') for a in soup.find_all('a') 
            if a.get('href') and not a.get('href').startswith(('?', '/'))]

def baixar_e_extrair(url_arquivo):
    nome = url_arquivo.split('/')[-1]
    print(f"Baixando: {nome}...")
    try:
        r = requests.get(url_arquivo)
        r.raise_for_status()
        with zipfile.ZipFile(io.BytesIO(r.content)) as z:
            z.extractall(OUTPUT_DIR)
            print("Extraido com sucesso.")
    except Exception as e:
        print(f"Falha: {e}")

def main():
    print(f"Iniciando varredura em: {BASE_URL}")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    anos = sorted([a for a in listar_links(BASE_URL) if a.strip('/').isdigit()], reverse=True)
    if not anos: return

    alvos_encontrados = 0
    
    for ano in anos[:2]: 
        if alvos_encontrados >= 3: break
        
        url_ano = urljoin(BASE_URL, ano)
        print(f"Varrendo Ano: {ano}")
        
        conteudo = listar_links(url_ano)
        trimestres = sorted([t for t in conteudo if 'T' in t], reverse=True)
        
        for tri in trimestres:
            if alvos_encontrados >= 3: break
            
            print(f"Processando: {tri}")
            url_tri = urljoin(url_ano, tri)
            
            if tri.lower().endswith('.zip'):
                baixar_e_extrair(url_tri)
                alvos_encontrados += 1
            else:
                print(f"Entrando na pasta: {tri}")
                zips = [z for z in listar_links(url_tri) if z.lower().endswith('.zip')]
                if zips:
                    for z in zips: 
                        baixar_e_extrair(urljoin(url_tri, z))
                    alvos_encontrados += 1
            
    print("\nScraping finalizado.")

if __name__ == "__main__":
    main()