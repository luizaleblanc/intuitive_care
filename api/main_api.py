import os
from flask import Flask, jsonify, request
from flask_cors import CORS
import mysql.connector

app = Flask(__name__)
CORS(app)

db_config = {
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASSWORD', 'root'),
    'host': os.getenv('DB_HOST', 'db'),
    'port': os.getenv('DB_PORT', '3306'),
    'database': os.getenv('DB_NAME', 'intuitive_care')
}

def get_db_connection():
    return mysql.connector.connect(**db_config)

@app.route('/api/operadoras', methods=['GET'])
def get_operadoras():
    try:
        page = int(request.args.get('page', 1))
        limit = int(request.args.get('limit', 10))
        search = request.args.get('search', '')
        offset = (page - 1) * limit

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        query_base = "FROM operadoras WHERE razao_social LIKE %s OR cnpj LIKE %s"
        search_param = f"%{search}%"
        
        cursor.execute(f"SELECT COUNT(*) as total {query_base}", (search_param, search_param))
        total_records = cursor.fetchone()['total']

        sql = f"SELECT * {query_base} LIMIT %s OFFSET %s"
        cursor.execute(sql, (search_param, search_param, limit, offset))
        results = cursor.fetchall()

        cursor.close()
        conn.close()

        return jsonify({
            'data': results,
            'total': total_records,
            'page': page,
            'limit': limit,
            'total_pages': (total_records + limit - 1) // limit
        })

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/api/operadoras/<cnpj>', methods=['GET'])
def get_operadora_details(cnpj):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT * FROM operadoras WHERE cnpj = %s", (cnpj,))
        operadora = cursor.fetchone()

        if not operadora:
            return jsonify({"erro": "Operadora não encontrada"}), 404

        cursor.close()
        conn.close()
        return jsonify(operadora)

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/api/operadoras/<cnpj>/despesas', methods=['GET'])
def get_operadora_despesas(cnpj):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT reg_ans FROM operadoras WHERE cnpj = %s", (cnpj,))
        op = cursor.fetchone()
        
        if not op:
             return jsonify([]), 404

        sql = """
            SELECT ano, trimestre, valor_despesa 
            FROM despesas 
            WHERE reg_ans = %s 
            ORDER BY ano DESC, trimestre DESC
        """
        cursor.execute(sql, (op['reg_ans'],))
        results = cursor.fetchall()

        cursor.close()
        conn.close()
        return jsonify(results)

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/api/estatisticas', methods=['GET'])
def get_estatisticas():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("""
            SELECT o.uf, SUM(d.valor_despesa) as total
            FROM operadoras o
            JOIN despesas d ON o.reg_ans = d.reg_ans
            GROUP BY o.uf
            ORDER BY total DESC
            LIMIT 5
        """)
        top_ufs = cursor.fetchall()

        cursor.execute("SELECT SUM(valor_despesa) as total_geral FROM despesas")
        total_geral = cursor.fetchone()['total_geral']

        cursor.close()
        conn.close()

        return jsonify({
            'top_ufs': top_ufs,
            'total_geral': total_geral
        })

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)