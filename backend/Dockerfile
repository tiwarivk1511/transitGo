FROM python:3.11-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y \
       chromium \
       chromium-driver \
       libnss3 \
       libatk-bridge2.0-0 \
       libgtk-3-0 \
       libgbm1 \
       libasound2 \
       libx11-xcb1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir \
    -r requirements.txt

RUN playwright install chromium

COPY . .

RUN mkdir -p /data

EXPOSE 8000

CMD [
    "uvicorn",
    "app.main:app",
    "--host",
    "0.0.0.0",
    "--port",
    "8000"
]