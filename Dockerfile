FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY health_watchdog.py .
COPY rollback_engine.py .
COPY telegram_alerter.py .

CMD ["python", "health_watchdog.py"]