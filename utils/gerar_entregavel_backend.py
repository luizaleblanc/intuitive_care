import os
import zipfile


def gerar_zip_backend():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    backend_dir = os.path.join(base_dir, "backend")
    etl_dir = os.path.join(base_dir, "etl")
    dist_dir = os.path.join(base_dir, "dist")
    os.makedirs(dist_dir, exist_ok=True)

    output_zip = os.path.join(dist_dir, "intuitive_care_backend_e_sql.zip")
    ignore_parts = {"__pycache__", ".pytest_cache", "intuitive_care_local.db"}

    with zipfile.ZipFile(output_zip, "w", zipfile.ZIP_DEFLATED) as zf:
        for folder in (backend_dir, etl_dir):
            for root, dirs, files in os.walk(folder):
                dirs[:] = [d for d in dirs if d not in ignore_parts]
                for file in files:
                    if file in ignore_parts or file.endswith(".pyc"):
                        continue
                    full_path = os.path.join(root, file)
                    rel_path = os.path.relpath(full_path, base_dir)
                    zf.write(full_path, rel_path)

        for extra_file in ("docker-compose.yml", "requirements.txt", "intuitive_care_collection.json"):
            full_extra = os.path.join(base_dir, extra_file)
            if os.path.exists(full_extra):
                zf.write(full_extra, extra_file)

    print(f"Pacote de entrega gerado com sucesso em: {output_zip}")


if __name__ == "__main__":
    gerar_zip_backend()
