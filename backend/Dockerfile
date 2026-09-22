# Nura backend (FastAPI) container image.
# Build context is the backend/ directory.
FROM python:3.11-slim

# System deps: build tools are a safety net for any package without a prebuilt
# wheel on this platform. Removed from the final layer to keep the image small.
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc libffi-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first (better layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY . .

# Make boto3/botocore use path-style S3 addressing, which MinIO requires when
# reached by service name (e.g. http://minio:9000). This is set via an AWS config
# file so we do NOT have to modify the application's storage.py.
RUN mkdir -p /app/.aws \
    && printf '[default]\ns3 =\n    addressing_style = path\n' > /app/.aws/config
ENV AWS_CONFIG_FILE=/app/.aws/config

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
