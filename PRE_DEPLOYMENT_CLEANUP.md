# Pre-Deployment Cleanup Guide

This guide provides scripts and instructions to clean up existing Ollama models and resources before deploying the optimized docling-only version of text-extract-api.

## 🎯 Why Clean Up?

The optimized version **no longer needs AI models**, so cleaning up existing Ollama resources will:
- ✅ **Free 8-15GB disk space** (from downloaded models)
- ✅ **Prevent conflicts** with old configurations
- ✅ **Ensure clean deployment** without legacy resources
- ✅ **Faster deployment** (no old containers to manage)

## 📋 Available Scripts

### 1. General Server Cleanup (`scripts/pre_deployment_cleanup.sh`)
For general Linux servers or development environments.

### 2. CapRover-Specific Cleanup (`scripts/caprover_cleanup.sh`)
For CapRover deployments with app-specific resource cleanup.

## 🚀 Usage Instructions

### For CapRover Deployments

#### Step 1: SSH to Your CapRover Server
```bash
ssh your-caprover-server
```

#### Step 2: Download the Cleanup Script
```bash
# Option A: If you have the repo on server
cd /path/to/your/text-extract-api
chmod +x scripts/caprover_cleanup.sh

# Option B: Download script directly
curl -O https://your-repo/scripts/caprover_cleanup.sh
chmod +x caprover_cleanup.sh
```

#### Step 3: Run Dry Run First (Recommended)
```bash
# Check what would be cleaned (replace 'extract-text' with your actual CapRover app name)
./scripts/caprover_cleanup.sh extract-text true
```

#### Step 4: Execute Actual Cleanup
```bash
# Perform actual cleanup
./scripts/caprover_cleanup.sh extract-text false
```

#### Step 5: Deploy Updated Code
1. Go to **CapRover Dashboard** → Your App
2. Deploy the updated code (git push or upload)
3. Monitor deployment logs

### For General Servers

#### Step 1: SSH to Your Server
```bash
ssh your-server
```

#### Step 2: Run the Cleanup Script
```bash
# Dry run first
./scripts/pre_deployment_cleanup.sh text-extract-api true

# Actual cleanup
./scripts/pre_deployment_cleanup.sh text-extract-api false
```

## 📊 What Gets Cleaned Up

### 🗑️ Ollama Models
- `llama3.1`, `llama3.2-vision`, `minicpm-v`
- Any other locally downloaded Ollama models

### 🐳 Docker Resources
- Ollama containers (running or stopped)
- Ollama Docker images
- Ollama data volumes (where models are stored)
- App-specific Ollama containers

### 💾 Disk Space
- Model files (~8-15GB typically)
- Container layers
- Unused Docker resources

## 🔧 Script Parameters

### CapRover Cleanup Script
```bash
./scripts/caprover_cleanup.sh [APP_NAME] [DRY_RUN]
```

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `APP_NAME` | Your CapRover app name | `extract-text` | `my-text-api` |
| `DRY_RUN` | Show what would be done | `false` | `true` |

### General Cleanup Script
```bash
./scripts/pre_deployment_cleanup.sh [APP_NAME] [DRY_RUN]
```

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `APP_NAME` | Your application name | `text-extract-api` | `my-app` |
| `DRY_RUN` | Show what would be done | `false` | `true` |

## 📝 Example Output

```bash
🧹 Starting pre-deployment cleanup for text-extract-api...
============================================================

📋 Step 1: Checking for Ollama models...
✅ Ollama CLI found, checking for models...
🔍 Found Ollama models:
llama3.1:latest
llama3.2-vision:latest
minicpm-v:latest

Executing: Remove Ollama model: llama3.1:latest
Executing: Remove Ollama model: llama3.2-vision:latest
Executing: Remove Ollama model: minicpm-v:latest

📋 Step 2: Checking for Ollama containers...
🔍 Found Ollama containers:
extract-text-ollama

Executing: Stop container: extract-text-ollama
Executing: Remove container: extract-text-ollama

📋 Step 3: Checking for Ollama volumes...
🔍 Found Ollama volumes:
captain--extract-text-ollama-data

Executing: Remove volume: captain--extract-text-ollama-data (Size: 12.3GB)

✅ CLEANUP COMPLETED SUCCESSFULLY
🚀 Ready for optimized docling-only deployment!
```

## ⚠️ Important Notes

### Before Running Cleanup:
1. **Backup important data** (though these scripts only target Ollama resources)
2. **Stop your application** if it's currently running
3. **Run dry run first** to see what will be affected
4. **Ensure you have the optimized code ready** to deploy

### After Cleanup:
1. **Deploy immediately** - Don't leave the app in a broken state
2. **Monitor deployment logs** for any issues
3. **Test the API** to ensure docling strategy works
4. **Verify disk space** has been freed up

## 🚨 Troubleshooting

### "Permission denied" errors
```bash
# Make scripts executable
chmod +x scripts/pre_deployment_cleanup.sh
chmod +x scripts/caprover_cleanup.sh
```

### "Docker command not found"
```bash
# Ensure Docker is installed and accessible
docker --version
sudo usermod -aG docker $USER  # Add user to docker group
```

### "No such container" errors
These are normal - the script tries to stop containers that may not exist.

### CapRover app name issues
```bash
# List all CapRover containers to find correct app name
docker ps -a | grep srv-captain
```

### Verification commands
```bash
# Check remaining Ollama resources
docker ps -a | grep ollama
docker volume ls | grep ollama
docker images | grep ollama

# Check disk space freed
df -h
docker system df
```

## 🎉 Success Verification

After cleanup and redeployment, verify:

### 1. **No Ollama Resources**
```bash
docker ps -a | grep ollama        # Should return nothing
docker volume ls | grep ollama    # Should return nothing
ollama list                       # Should show no models
```

### 2. **Application Works**
```bash
curl --location 'https://your-app.domain.com/ocr/upload' \
--form 'strategy="docling"' \
--form 'file=@"test.pdf"'
```

### 3. **Faster Deployment**
- Deployment should complete in 2-3 minutes (vs 20+ minutes before)
- No "Pulling models" messages in logs
- Lower memory usage in container stats

## 📞 Support

If you encounter issues:
1. **Check the deployment logs** in CapRover Dashboard
2. **Verify environment variables** are correctly set
3. **Ensure docling strategy** is properly configured
4. **Test with a simple PDF** file first

The cleanup ensures a clean slate for your optimized deployment! 🚀 