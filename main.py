import os
import requests
from bs4 import BeautifulSoup
import zipfile
from io import BytesIO

class ANSScraper:
    def __init__(self):
        self.base_url = "https://dadosabertos.ans.gov.br/FTP/PDA/demonstracoes_contabeis/"
        self.output_folder = "data/raw"
        self.headers = {"User-Agent": "Mozilla/5.0"}
        os.makedirs(self.output_folder, exist_ok=True)

    def baixar_trimestres(self, qtd_trimestres=3):
        print("Iniciando busca resiliente de dados...")
        try:
            response = requests.get(self.base_url, headers=self.headers)
            soup = BeautifulSoup(response.text, 'html.parser')
            anos = sorted([a['href'] for a in soup.find_all('a') if a['href'].strip('/').isdigit()], reverse=True)
            
            trimestres_baixados = 0
            
            for ano in anos:
                if trimestres_baixados >= qtd_trimestres: break
                
                url_ano = f"{self.base_url}{ano}"
                resp_ano = requests.get(url_ano, headers=self.headers)
                soup_ano = BeautifulSoup(resp_ano.text, 'html.parser')
                
                links_ano = [a['href'] for a in soup_ano.find_all('a') if a['href'] != '../']
                
                for link in sorted(links_ano, reverse=True):
                    if trimestres_baixados >= qtd_trimestres: break
                    
                    url_alvo = f"{url_ano}{link}"
                    
                    if link.endswith('.zip'):
                        self.download_e_extrair(url_alvo)
                        trimestres_baixados += 1
                    
                    elif link.endswith('/'):
                        resp_tri = requests.get(url_alvo, headers=self.headers)
                        soup_tri = BeautifulSoup(resp_tri.text, 'html.parser')
                        zips = [a['href'] for a in soup_tri.find_all('a') if a['href'].endswith('.zip')]
                        
                        for z in zips:
                            self.download_e_extrair(f"{url_alvo}{z}")
                        
                        if zips: trimestres_baixados += 1
                        
        except Exception as e:
            print(f"Erro geral: {e}")

    def download_e_extrair(self, url):
        try:
            print(f"Baixando: {url}")
            res = requests.get(url, headers=self.headers)
            with zipfile.ZipFile(BytesIO(res.content)) as z:
                z.extractall(self.output_folder)
                print(f"Sucesso: {len(z.namelist())} arquivos extraídos.")
        except Exception as e:
            print(f"Falha ao baixar {url}: {e}")

if __name__ == "__main__":
    scraper = ANSScraper()
    scraper.baixar_trimestres(3)