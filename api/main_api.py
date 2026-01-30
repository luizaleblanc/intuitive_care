import os
from flask import Flask, jsonify, request
from flask_cors import CORS
import mysql.connector

app = Flask(__name__)
CORS(app)

db_config = {
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASSWORD', 'root'),  
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', '3307'),         
    'database': os.getenv('DB_NAME', 'intuitive_care')
}

def get_db_connection():
    return mysql.connector.connect(**db_config)

@app.route('/top10', methods=['GET'])
def get_top_10():
    try:
        ano_filtro = request.args.get('ano')
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        sql = """
            SELECT 
                o.reg_ans, 
                o.razao_social, 
                SUM(d.valor_despesa) as total_despesas
            FROM operadoras o
            JOIN despesas d ON o.reg_ans = d.reg_ans
        """
        
        params = []
        
        if ano_filtro:
            sql += " WHERE d.ano = %s "
            params.append(ano_filtro)
            
        sql += """
            GROUP BY o.reg_ans, o.razao_social
            ORDER BY total_despesas DESC
            LIMIT 10;
        """
        
        cursor.execute(sql, params)
        resultados = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return jsonify(resultados)
        
    except Exception as e:
        return jsonify({"erro": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=5000)