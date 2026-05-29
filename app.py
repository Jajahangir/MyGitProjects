from flask import Flask, render_template_string
import os
import platform
from datetime import datetime

app = Flask(__name__)

# Красивый HTML-шаблон прямо в коде
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>DevOps Dashboard</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #1e1e2e; color: #cdd6f4; padding: 40px; text-align: center; }
        .card { background-color: #313244; padding: 30px; border-radius: 15px; box-shadow: 0 10px 20px rgba(0,0,0,0.3); display: inline-block; text-align: left; margin-top: 20px; }
        h1 { color: #a6e3a1; }
        .info { font-size: 18px; margin: 10px 0; }
        .badge { background-color: #89b4fa; color: #11111b; padding: 5px 10px; border-radius: 5px; font-weight: bold; }
    </style>
</head>
<body>
    <h1>🚀 Мой второй CI/CD конвейер работает!</h1>
    <p>Это приложение развернуто полностью самостоятельно.</p>
    
    <div class="card">
        <div class="info"><strong>ОС сервера:</strong> <span class="badge">{{ os_info }}</span></div>
        <div class="info"><strong>Версия Python:</strong> <span class="badge">{{ py_version }}</span></div>
        <div class="info"><strong>Время деплоя (серверное):</strong> <span class="badge">{{ current_time }}</span></div>
    </div>
</body>
</html>
"""

@app.route('/')
def index():
    context = {
        "os_info": f"{platform.system()} {platform.release()}",
        "py_version": platform.python_version(),
        "current_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    }
    return render_template_string(HTML_TEMPLATE, **context)

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)
