#!/bin/bash

# CapRover-specific cleanup script for text-extract-api
# This script should be run on the CapRover server to clean up app-specific resources

set -e

echo "🐳 CapRover Ollama Cleanup Script"
echo "=================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get app name from command line or use default
CAPROVER_APP_NAME=${1:-"extract-text"}
DRY_RUN=${2:-false}

echo -e "${BLUE}ℹ️  CapRover App Name: $CAPROVER_APP_NAME${NC}"
echo -e "${BLUE}ℹ️  Dry Run: $DRY_RUN${NC}"
echo ""

# Function to execute or simulate command
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

# 1. Stop the CapRover app first
echo -e "${BLUE}📋 Step 1: Stopping CapRover app...${NC}"
execute_command "docker stop srv-captain--$CAPROVER_APP_NAME 2>/dev/null || true" "Stop main app container"
execute_command "docker stop srv-captain--$CAPROVER_APP_NAME-celery 2>/dev/null || true" "Stop celery container"
execute_command "docker stop srv-captain--$CAPROVER_APP_NAME-ollama 2>/dev/null || true" "Stop ollama container"

# 2. Find and remove CapRover app containers
echo -e "${BLUE}📋 Step 2: Removing CapRover app containers...${NC}"
CAPROVER_CONTAINERS=$(docker ps -a --filter "name=srv-captain--$CAPROVER_APP_NAME" --format "{{.Names}}" 2>/dev/null || true)

if [ -n "$CAPROVER_CONTAINERS" ]; then
    echo -e "${YELLOW}🔍 Found CapRover containers:${NC}"
    echo "$CAPROVER_CONTAINERS"
    echo ""
    
    for container in $CAPROVER_CONTAINERS; do
        if [[ "$container" == *"ollama"* ]]; then
            execute_command "docker rm '$container' 2>/dev/null || true" "Remove CapRover container: $container"
        else
            echo -e "${BLUE}ℹ️  Keeping non-ollama container: $container${NC}"
        fi
    done
else
    echo -e "${GREEN}✅ No CapRover containers found${NC}"
    echo ""
fi

# 3. Find and remove CapRover app volumes
echo -e "${BLUE}📋 Step 3: Removing CapRover app volumes...${NC}"
CAPROVER_VOLUMES=$(docker volume ls --filter "name=captain--$CAPROVER_APP_NAME" --format "{{.Name}}" 2>/dev/null || true)

if [ -n "$CAPROVER_VOLUMES" ]; then
    echo -e "${YELLOW}🔍 Found CapRover volumes:${NC}"
    echo "$CAPROVER_VOLUMES"
    echo ""
    
    for volume in $CAPROVER_VOLUMES; do
        if [[ "$volume" == *"ollama"* ]]; then
            # Check volume size
            VOLUME_SIZE=$(docker system df -v 2>/dev/null | grep "$volume" | awk '{print $3}' || echo "unknown")
            execute_command "docker volume rm '$volume'" "Remove CapRover volume: $volume (Size: $VOLUME_SIZE)"
        else
            echo -e "${BLUE}ℹ️  Keeping non-ollama volume: $volume${NC}"
        fi
    done
else
    echo -e "${GREEN}✅ No CapRover volumes found${NC}"
    echo ""
fi

# 4. Clean up CapRover app images (ollama related only)
echo -e "${BLUE}📋 Step 4: Cleaning up Ollama images...${NC}"
OLLAMA_IMAGES=$(docker images --filter "reference=ollama/*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)

if [ -n "$OLLAMA_IMAGES" ]; then
    echo -e "${YELLOW}🔍 Found Ollama images:${NC}"
    echo "$OLLAMA_IMAGES"
    echo ""
    
    for image in $OLLAMA_IMAGES; do
        execute_command "docker rmi '$image' 2>/dev/null || true" "Remove Ollama image: $image"
    done
else
    echo -e "${GREEN}✅ No Ollama images found${NC}"
    echo ""
fi

# 5. Clean up dangling resources
echo -e "${BLUE}📋 Step 5: Cleaning up dangling resources...${NC}"
execute_command "docker container prune -f" "Remove stopped containers"
execute_command "docker volume prune -f" "Remove unused volumes"
execute_command "docker image prune -f" "Remove dangling images"

# 6. Show current disk usage
echo -e "${BLUE}📋 Step 6: Current system status...${NC}"
if [ "$DRY_RUN" = "false" ]; then
    echo -e "${GREEN}Disk usage:${NC}"
    df -h / | head -2
    echo ""
    
    echo -e "${GREEN}Docker system usage:${NC}"
    docker system df
    echo ""
    
    echo -e "${GREEN}Remaining CapRover containers for $CAPROVER_APP_NAME:${NC}"
    docker ps -a --filter "name=srv-captain--$CAPROVER_APP_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" || echo "No containers found"
    echo ""
    
    echo -e "${GREEN}Remaining CapRover volumes for $CAPROVER_APP_NAME:${NC}"
    docker volume ls --filter "name=captain--$CAPROVER_APP_NAME" --format "table {{.Name}}\t{{.Size}}" || echo "No volumes found"
else
    echo -e "${YELLOW}[DRY RUN] Would show system status${NC}"
fi

echo ""
echo "============================================================"
if [ "$DRY_RUN" = "true" ]; then
    echo -e "${YELLOW}🔍 DRY RUN COMPLETED - No changes were made${NC}"
    echo -e "${YELLOW}To actually perform cleanup, run: $0 $CAPROVER_APP_NAME false${NC}"
else
    echo -e "${GREEN}✅ CAPROVER CLEANUP COMPLETED${NC}"
    echo -e "${GREEN}🚀 Ready to redeploy optimized version in CapRover!${NC}"
fi

echo ""
echo -e "${BLUE}📊 What was cleaned:${NC}"
echo "• Stopped CapRover app containers"
echo "• Removed Ollama-related containers and volumes"
echo "• Cleaned up Ollama Docker images"
echo "• Freed up disk space from old models"
echo ""
echo -e "${BLUE}💡 Next steps:${NC}"
echo "1. Deploy your updated code in CapRover Dashboard"
echo "2. The new deployment will be much faster (no models to download)"
echo "3. Monitor the deployment logs for success"
echo ""
echo -e "${GREEN}Your CapRover server is ready for optimized deployment! 🎉${NC}" 