# Use Python 3.10 slim image for smaller size
FROM python:3.10-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_ENV=production \
    DEBIAN_FRONTEND=noninteractive

# Set working directory
WORKDIR /app

# Install system dependencies required for various libraries
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    curl \
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

# Create a robust entrypoint script directly in Dockerfile (no external scripts needed)
RUN echo '#!/bin/bash\n\
echo "=== Text Extract API Starting ==="\n\
echo "APP_TYPE: $APP_TYPE"\n\
echo "APP_ENV: $APP_ENV"\n\
echo "CELERY_BROKER_URL: $CELERY_BROKER_URL"\n\
echo "REDIS_CACHE_URL: $REDIS_CACHE_URL"\n\
echo "================================"\n\
\n\
if [ "$APP_ENV" = "production" ]; then\n\
    echo "🚀 Production mode - using pre-installed dependencies"\n\
    \n\
    if [ "$APP_TYPE" = "celery" ]; then\n\
        echo "🔄 Starting Celery worker in production mode..."\n\
        echo "📡 Celery Broker: $CELERY_BROKER_URL"\n\
        echo "🗄️  Redis Cache: $REDIS_CACHE_URL"\n\
        echo "⏳ Waiting 5 seconds for Redis to be ready..."\n\
        sleep 5\n\
        echo "✅ Starting Celery worker with concurrency=2"\n\
        exec celery -A text_extract_api.celery_app worker --loglevel=info --pool=solo --concurrency=2\n\
    else\n\
        echo "🌐 Starting FastAPI app in production mode..."\n\
        exec uvicorn text_extract_api.main:app --host 0.0.0.0 --port 8000\n\
    fi\n\
else\n\
    echo "🛠️  Development mode"\n\
    # For development, try original entrypoint if it exists, otherwise fallback\n\
    if [ -f "/app/scripts/entrypoint.sh" ]; then\n\
        echo "📋 Using original entrypoint script"\n\
        exec /app/scripts/entrypoint.sh\n\
    else\n\
        echo "⚠️  Original entrypoint not found, using fallback"\n\
        exec uvicorn text_extract_api.main:app --host 0.0.0.0 --port 8000 --reload\n\
    fi\n\
fi' > /app/entrypoint_robust.sh && chmod +x /app/entrypoint_robust.sh

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Create necessary directories with proper permissions
RUN mkdir -p /app/storage /app/uploads /app/logs && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose the application port
EXPOSE 8000

# Use the robust self-contained entrypoint
ENTRYPOINT ["/app/entrypoint_robust.sh"]

# Default command (can be overridden)
CMD []
