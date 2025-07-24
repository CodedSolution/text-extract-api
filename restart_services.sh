#!/bin/bash

# Improved restart script for text-extract-api
echo "🔄 Restarting text-extract-api services..."

# Kill existing processes
echo "⏹️  Stopping existing services..."
pkill -f "uvicorn text_extract_api.main:app" 2>/dev/null
pkill -f "celery.*text_extract_api.celery_app" 2>/dev/null

# Wait for processes to stop
sleep 2

# Clean up Redis queues (optional)
echo "🧹 Clearing Redis queues..."
redis-cli FLUSHDB 2>/dev/null || echo "Redis not accessible, skipping flush"

# Start services with better resource management
echo "🚀 Starting services..."

# Start Celery worker with resource limits
celery -A text_extract_api.celery_app worker \
  --loglevel=info \
  --pool=solo \
  --max-memory-per-child=512000 \
  --max-tasks-per-child=10 \
  --prefetch-multiplier=1 &

# Wait a moment for Celery to start
sleep 3

# Start FastAPI server
uvicorn text_extract_api.main:app \
  --host 0.0.0.0 \
  --port 8000 \
  --reload \
  --workers 1 &

echo "✅ Services started!"
echo "📊 FastAPI: http://localhost:8000"
echo "📚 API Docs: http://localhost:8000/docs"

# Keep script running
wait
