from flask import Flask, jsonify
from flask_cors import CORS
import mysql.connector

app = Flask(__name__)
CORS(app)  

db_config = {
    'user': 'root',
    'password': 'Luizaferraz123*', 
    'host': 'localhost',
    'database': 'intuitive_care'
}

def get_db_connection():
    return mysql.connector.connect(**db_config)

@app.route('/')
def home():
    return "<h1>API Intuitive Care Online!</h1><p>Acesse <a href='/top10'>/top10</a> para ver os dados.</p>"

@app.route('/top10', methods=['GET'])
def get_top_10():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True) 
        
        query = """
        SELECT 
            o.reg_ans, 
            o.razao_social, 
            o.uf, 
            SUM(d.valor_despesa) as total_despesas
        FROM operadoras o
        JOIN despesas d ON o.reg_ans = d.reg_ans
        GROUP BY o.reg_ans, o.razao_social, o.uf
        ORDER BY total_despesas DESC
        LIMIT 10;
        """
        
        cursor.execute(query)
        resultados = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return jsonify(resultados)
        
    except Exception as e:
        return jsonify({"erro": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=5000)