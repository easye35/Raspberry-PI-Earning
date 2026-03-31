FROM python:3.11-slim

WORKDIR /app
COPY . .

RUN pip install flask docker psutil flask-cors

CMD ["python", "app.py"]
