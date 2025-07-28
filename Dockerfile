FROM python:3.10-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_ENV=production \
    DEBIAN_FRONTEND=noninteractive

# Create app directory and storage symlink for backward compatibility
RUN mkdir -p /app/storage && ln -s /storage /app/storage

# Configure apt to avoid pipeline issues
RUN echo 'Acquire::http::Pipeline-Depth 0;\nAcquire::http::No-Cache true;\nAcquire::BrokenProxy true;\n' > /etc/apt/apt.conf.d/99fixbadproxy

# Install system dependencies
RUN apt-get clean && rm -rf /var/lib/apt/lists/* \
    && apt-get update --fix-missing \
    && apt-get install -y \
        libglib2.0-0 \
        libglib2.0-dev \
        libgl1-mesa-glx \
        poppler-utils \
        libmagic1 \
        libmagic-dev \
        libpoppler-cpp-dev \
        curl \
        && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy only pyproject.toml first for better Docker layer caching
COPY pyproject.toml ./

# Install Python dependencies (this layer will be cached if pyproject.toml doesn't change)
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir .

# Copy the rest of the application code
COPY . .

# Make scripts executable
RUN chmod +x /app/scripts/entrypoint.sh

# Create non-root user for security
RUN useradd -m -u 1001 appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Set default entrypoint
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
