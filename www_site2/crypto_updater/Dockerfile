FROM python:3.10-slim
WORKDIR /app
COPY crypto_updater.py .
RUN pip install requests psycopg2-binary
CMD ["python3", "crypto_updater.py"]