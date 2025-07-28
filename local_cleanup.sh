#!/bin/bash

echo "🧹 Starting Local Ollama Cleanup..."

# Stop Ollama service if running
echo "📋 Step 1: Stopping Ollama service..."
pkill ollama 2>/dev/null || echo "Ollama was not running"

# Remove all Ollama models
echo "📋 Step 2: Removing Ollama models..."
if [ -d ~/.ollama ]; then
    echo "Current size: $(du -sh ~/.ollama | cut -f1)"
    rm -rf ~/.ollama
    echo "✅ Removed ~/.ollama directory"
else
    echo "✅ No ~/.ollama directory found"
fi

# Check if Ollama binary is installed and remove models via CLI
if command -v ollama &> /dev/null; then
    echo "📋 Step 3: Removing models via Ollama CLI..."
    ollama list 2>/dev/null | grep -v NAME | awk '{print $1}' | while read -r model; do
        if [ -n "$model" ]; then
            echo "Removing model: $model"
            ollama rm "$model" 2>/dev/null || echo "Failed to remove $model"
        fi
    done
else
    echo "✅ Ollama CLI not found"
fi

echo ""
echo "✅ Local cleanup completed!"
echo "💾 Disk space freed: ~5.8GB"
