# Türkmen Ses API — production cloud ready image.
# DATA_DIR must point to a mounted volume (sqlite + wav files live there).
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DATA_DIR=/data \
    PORT=8000 \
    WEB_CONCURRENCY=2

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY scripts ./scripts
COPY tools ./tools

# non root user, owns the data volume
RUN useradd --create-home --uid 10001 appuser \
    && mkdir -p /data \
    && chown -R appuser:appuser /data /app
USER appuser

EXPOSE 8000
VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request,os;urllib.request.urlopen(f\"http://127.0.0.1:{os.getenv('PORT','8000')}/api/v1/health\",timeout=4)"

# Production: Gunicorn + Uvicorn workers, optimal for cloud (low memory, multiple CPU cores)
CMD ["sh", "-c", "gunicorn app.main:app -w ${WEB_CONCURRENCY:-2} -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:${PORT:-8000} --proxy-protocol --proxy-allow-from '*' --forwarded-allow-ips '*' --access-logfile - --error-logfile -"]
