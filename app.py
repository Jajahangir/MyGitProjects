from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def home():
    return "<h1>Ура! Мой Flask-сайт работает в облаке благодаря CI/CD пайплайну!</h1>"

if __name__ == '__main__':
    # Настройки портов важны для облака, берем порт из окружения или ставим 5000 по дефолту
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)
