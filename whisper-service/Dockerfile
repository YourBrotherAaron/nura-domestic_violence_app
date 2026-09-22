# Whisper transcription service (Flask + faster-whisper).
# Build context is the whisper-service/ directory.
FROM python:3.11-slim

# ffmpeg is required for faster-whisper to decode audio files.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
# NOTE: app.py imports flask_cors, which is missing from requirements.txt, so we
# add it here. gunicorn gives us a more robust server than Flask's dev server.
RUN pip install --no-cache-dir -r requirements.txt flask-cors gunicorn

COPY . .

# faster-whisper downloads its model on first use; the compose file mounts a
# named volume at this cache path so the ~1.5GB model is downloaded only once.
ENV HF_HOME=/models
ENV XDG_CACHE_HOME=/models

EXPOSE 5000

# 1 worker, long timeout: transcription is CPU-heavy and can take minutes.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "--timeout", "600", "app:app"]
