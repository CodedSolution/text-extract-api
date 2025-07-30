# Use Python 3.10 slim image for smaller size
FROM python:3.10-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_ENV=production \
    DEBIAN_FRONTEND=noninteractive

# Set working directory
WORKDIR /app

# Install system dependencies required for various libraries including libmagic
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    curl \
    file \
    libffi-dev \
    libglib2.0-0 \
    libgl1-mesa-glx \
    poppler-utils \
    libmagic1 \
    libmagic-dev \
    libpoppler-cpp-dev \
    && rm -rf /var/lib/apt/lists/*

# Configure apt to avoid pipeline issues
RUN echo 'Acquire::http::Pipeline-Depth 0;\nAcquire::http::No-Cache true;\nAcquire::BrokenProxy true;\n' > /etc/apt/apt.conf.d/99fixbadproxy

# Copy pyproject.toml first for better caching
COPY pyproject.toml ./

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip setuptools && \
    pip install --no-cache-dir .

# Copy application code
COPY text_extract_api/ ./text_extract_api/
COPY config/ ./config/
COPY storage_profiles/ ./storage_profiles/

# Create a smart entrypoint script that can handle both single-container and multi-service deployments
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "=== Text Extract API Starting ==="\n\
echo "APP_TYPE: $APP_TYPE"\n\
echo "APP_ENV: $APP_ENV"\n\
echo "CELERY_BROKER_URL: $CELERY_BROKER_URL"\n\
echo "REDIS_CACHE_URL: $REDIS_CACHE_URL"\n\
echo "OLLAMA_HOST: $OLLAMA_HOST"\n\
echo "CAPROVER_DETECTED: $CAPROVER_DETECTED"\n\
echo "================================"\n\
\n\
# Set default values if not provided\n\
export APP_TYPE=${APP_TYPE:-fastapi}\n\
export APP_ENV=${APP_ENV:-production}\n\
\n\
# Smart Redis URL detection for CapRover\n\
if [ -n "$CAPROVER_DETECTED" ] || [ -n "$cap_redis_url" ]; then\n\
    echo "🔍 CapRover environment detected"\n\
    export CELERY_BROKER_URL=${CELERY_BROKER_URL:-redis://srv-captain--extract-text-redis:6379/0}\n\
    export CELERY_RESULT_BACKEND=${CELERY_RESULT_BACKEND:-redis://srv-captain--extract-text-redis:6379/0}\n\
    export REDIS_CACHE_URL=${REDIS_CACHE_URL:-redis://srv-captain--extract-text-redis:6379/1}\n\
else\n\
    echo "🐳 Local Docker environment detected"\n\
    export CELERY_BROKER_URL=${CELERY_BROKER_URL:-redis://host.docker.internal:6379/0}\n\
    export CELERY_RESULT_BACKEND=${CELERY_RESULT_BACKEND:-redis://host.docker.internal:6379/0}\n\
    export REDIS_CACHE_URL=${REDIS_CACHE_URL:-redis://host.docker.internal:6379/1}\n\
fi\n\
\n\
export OLLAMA_HOST=${OLLAMA_HOST:-http://localhost:11434}\n\
export STORAGE_PROFILE_PATH=${STORAGE_PROFILE_PATH:-/app/storage_profiles}\n\
\n\
# Special handling for single-container deployment (Git push to CapRover)\n\
if [ "$APP_ENV" = "production" ] && [ "$APP_TYPE" = "fastapi" ] && [ -z "$CAPROVER_MULTISERVICE" ]; then\n\
    echo "🚀 Single-container mode - starting both FastAPI and background Celery worker"\n\
    \n\
    # Start Celery worker in background\n\
    echo "🔄 Starting background Celery worker..."\n\
    celery -A text_extract_api.celery_app worker \\\n\
        --loglevel=info \\\n\
        --pool=solo \\\n\
        --concurrency=1 \\\n\
        --max-memory-per-child=512000 \\\n\
        --max-tasks-per-child=10 \\\n\
        --prefetch-multiplier=1 \\\n\
        --without-gossip \\\n\
        --without-mingle \\\n\
        --without-heartbeat &\n\
    \n\
    # Wait a moment for Celery to start\n\
    sleep 5\n\
    \n\
    echo "🌐 Starting FastAPI app..."\n\
    exec uvicorn text_extract_api.main:app --host 0.0.0.0 --port 8000 --workers 1\n\
    \n\
elif [ "$APP_ENV" = "production" ]; then\n\
    echo "🚀 Production mode - multi-service deployment"\n\
    \n\
    if [ "$APP_TYPE" = "celery" ]; then\n\
        echo "🔄 Starting dedicated Celery worker..."\n\
        echo "📡 Celery Broker: $CELERY_BROKER_URL"\n\
        echo "🗄️  Redis Cache: $REDIS_CACHE_URL"\n\
        echo "⏳ Waiting 10 seconds for Redis to be ready..."\n\
        sleep 10\n\
        echo "✅ Starting Celery worker with concurrency=2"\n\
        \n\
        exec celery -A text_extract_api.celery_app worker \\\n\
            --loglevel=info \\\n\
            --pool=solo \\\n\
            --concurrency=2 \\\n\
            --max-memory-per-child=512000 \\\n\
            --max-tasks-per-child=10 \\\n\
            --prefetch-multiplier=1 \\\n\
            --without-gossip \\\n\
            --without-mingle \\\n\
            --without-heartbeat\n\
    else\n\
        echo "🌐 Starting FastAPI app in production mode..."\n\
        exec uvicorn text_extract_api.main:app --host 0.0.0.0 --port 8000 --workers 1\n\
    fi\n\
else\n\
    echo "🛠️  Development mode"\n\
    if [ -f "/app/scripts/entrypoint.sh" ]; then\n\
        echo "📋 Using original entrypoint script"\n\
        exec /app/scripts/entrypoint.sh\n\
    else\n\
        echo "⚠️  Original entrypoint not found, using fallback"\n\
        exec uvicorn text_extract_api.main:app --host 0.0.0.0 --port 8000 --reload\n\
    fi\n\
fi' > /app/entrypoint_smart.sh && chmod +x /app/entrypoint_smart.sh

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser -m appuser

# Create necessary directories with proper permissions
RUN mkdir -p /app/storage /app/uploads /app/logs /home/appuser && \
    chown -R appuser:appuser /app /home/appuser

# Switch to non-root user
USER appuser

# Expose the application port
EXPOSE 8000

# Use the smart entrypoint that can handle both single and multi-container deployments
ENTRYPOINT ["/app/entrypoint_smart.sh"]

# Default command (can be overridden)
CMD []
