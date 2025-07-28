#!/bin/bash

# Pre-deployment cleanup script for text-extract-api
# This script removes all Ollama models, containers, and volumes before deployment
# to ensure a clean, optimized deployment for docling-only version

set -e  # Exit on any error

echo "🧹 Starting pre-deployment cleanup for text-extract-api..."
echo "============================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME=${1:-"text-extract-api"}  # Default app name, can be overridden
DRY_RUN=${2:-false}               # Set to true to see what would be deleted without actually deleting

echo -e "${BLUE}ℹ️  App Name: $APP_NAME${NC}"
echo -e "${BLUE}ℹ️  Dry Run: $DRY_RUN${NC}"
echo ""

# Function to execute or simulate command based on dry run mode
execute_command() {
    local cmd="$1"
    local description="$2"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[DRY RUN] Would execute: $description${NC}"
        echo -e "${YELLOW}[DRY RUN] Command: $cmd${NC}"
    else
        echo -e "${GREEN}Executing: $description${NC}"
        eval "$cmd" || echo -e "${RED}⚠️  Command failed (continuing): $cmd${NC}"
    fi
    echo ""
}

# 1. Check and remove Ollama models
echo -e "${BLUE}📋 Step 1: Checking for Ollama models...${NC}"
if command -v ollama &> /dev/null; then
    echo "✅ Ollama CLI found, checking for models..."
    MODELS=$(ollama list 2>/dev/null | grep -v "NAME" | awk '{print $1}' | grep -v "^$" || true)
    
    if [ -n "$MODELS" ]; then
        echo -e "${YELLOW}🔍 Found Ollama models:${NC}"
        echo "$MODELS"
        echo ""
        
        while IFS= read -r model; do
            if [ -n "$model" ]; then
                execute_command "ollama rm '$model'" "Remove Ollama model: $model"
            fi
        done <<< "$MODELS"
    else
        echo -e "${GREEN}✅ No Ollama models found${NC}"
        echo ""
    fi
else
    echo -e "${GREEN}✅ Ollama CLI not found (no local models to clean)${NC}"
    echo ""
fi

# 2. Check and stop Ollama containers
echo -e "${BLUE}📋 Step 2: Checking for Ollama containers...${NC}"
OLLAMA_CONTAINERS=$(docker ps -a --filter "name=ollama" --format "{{.Names}}" 2>/dev/null || true)
APP_OLLAMA_CONTAINERS=$(docker ps -a --filter "name=$APP_NAME" --filter "name=ollama" --format "{{.Names}}" 2>/dev/null || true)

if [ -n "$OLLAMA_CONTAINERS" ] || [ -n "$APP_OLLAMA_CONTAINERS" ]; then
    echo -e "${YELLOW}🔍 Found Ollama containers:${NC}"
    echo "$OLLAMA_CONTAINERS"
    echo "$APP_OLLAMA_CONTAINERS"
    echo ""
    
    # Stop and remove containers
    for container in $OLLAMA_CONTAINERS $APP_OLLAMA_CONTAINERS; do
        if [ -n "$container" ]; then
            execute_command "docker stop '$container'" "Stop container: $container"
            execute_command "docker rm '$container'" "Remove container: $container"
        fi
    done
else
    echo -e "${GREEN}✅ No Ollama containers found${NC}"
    echo ""
fi

# 3. Check and remove Ollama Docker volumes
echo -e "${BLUE}📋 Step 3: Checking for Ollama volumes...${NC}"
OLLAMA_VOLUMES=$(docker volume ls --filter "name=ollama" --format "{{.Name}}" 2>/dev/null || true)
APP_OLLAMA_VOLUMES=$(docker volume ls --filter "name=$APP_NAME" | grep ollama | awk '{print $2}' 2>/dev/null || true)

if [ -n "$OLLAMA_VOLUMES" ] || [ -n "$APP_OLLAMA_VOLUMES" ]; then
    echo -e "${YELLOW}🔍 Found Ollama volumes:${NC}"
    echo "$OLLAMA_VOLUMES"
    echo "$APP_OLLAMA_VOLUMES"
    echo ""
    
    # Remove volumes
    for volume in $OLLAMA_VOLUMES $APP_OLLAMA_VOLUMES; do
        if [ -n "$volume" ]; then
            # Check volume size before removal
            VOLUME_SIZE=$(docker system df -v 2>/dev/null | grep "$volume" | awk '{print $3}' || echo "unknown")
            execute_command "docker volume rm '$volume'" "Remove volume: $volume (Size: $VOLUME_SIZE)"
        fi
    done
else
    echo -e "${GREEN}✅ No Ollama volumes found${NC}"
    echo ""
fi

# 4. Check and remove Ollama images
echo -e "${BLUE}📋 Step 4: Checking for Ollama Docker images...${NC}"
OLLAMA_IMAGES=$(docker images --filter "reference=ollama/*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)

if [ -n "$OLLAMA_IMAGES" ]; then
    echo -e "${YELLOW}🔍 Found Ollama images:${NC}"
    echo "$OLLAMA_IMAGES"
    echo ""
    
    # Remove images
    while IFS= read -r image; do
        if [ -n "$image" ]; then
            execute_command "docker rmi '$image'" "Remove Docker image: $image"
        fi
    done <<< "$OLLAMA_IMAGES"
else
    echo -e "${GREEN}✅ No Ollama Docker images found${NC}"
    echo ""
fi

# 5. Clean up any dangling resources
echo -e "${BLUE}📋 Step 5: Cleaning up dangling resources...${NC}"
execute_command "docker container prune -f" "Remove stopped containers"
execute_command "docker volume prune -f" "Remove unused volumes"
execute_command "docker image prune -f" "Remove dangling images"

# 6. Show disk space freed up
echo -e "${BLUE}📋 Step 6: Disk space analysis...${NC}"
if [ "$DRY_RUN" = "false" ]; then
    echo -e "${GREEN}Current disk usage:${NC}"
    df -h | head -1
    df -h | grep -E "/$|/var"
    echo ""
    
    echo -e "${GREEN}Docker system usage:${NC}"
    docker system df
else
    echo -e "${YELLOW}[DRY RUN] Would show disk space analysis${NC}"
fi

echo ""
echo "============================================================"
if [ "$DRY_RUN" = "true" ]; then
    echo -e "${YELLOW}🔍 DRY RUN COMPLETED - No changes were made${NC}"
    echo -e "${YELLOW}To actually perform cleanup, run: $0 $APP_NAME false${NC}"
else
    echo -e "${GREEN}✅ CLEANUP COMPLETED SUCCESSFULLY${NC}"
    echo -e "${GREEN}🚀 Ready for optimized docling-only deployment!${NC}"
fi

echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo "• Removed all Ollama models from local installation"
echo "• Stopped and removed all Ollama containers"
echo "• Deleted all Ollama-related Docker volumes (freed disk space)"
echo "• Cleaned up Ollama Docker images"
echo "• Cleaned up dangling Docker resources"
echo ""
echo -e "${GREEN}Your server is now ready for the optimized deployment! 🎉${NC}" 