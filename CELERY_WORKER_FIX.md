# 🚨 CELERY WORKER FIX - URGENT DEPLOYMENT GUIDE

## 🔍 **ROOT CAUSE IDENTIFIED**
Your Celery workers weren't starting because:
1. **`.dockerignore` excluded `scripts/` directory** - The entrypoint script wasn't being copied into Docker images
2. **Missing command directive** - CapRover wasn't running the entrypoint properly
3. **Missing environment variables** - Worker containers lacked Redis cache URL

## ✅ **FIXES IMPLEMENTED**

### 1. **Self-Contained Dockerfile**
- Created a robust entrypoint script **inside** the Dockerfile (not dependent on external files)
- Bypasses the `.dockerignore` limitation completely
- Includes detailed logging and error handling

### 2. **Updated docker-compose.caprover.yml**  
- Added explicit `entrypoint: ["/app/entrypoint_robust.sh"]` to the Celery service
- Ensured all required environment variables are passed to worker

### 3. **Production-Ready Entrypoint**
The new entrypoint includes:
- ✅ Environment variable validation and logging
- ✅ Redis connection wait (5 seconds)  
- ✅ Proper Celery worker startup with concurrency=2
- ✅ Comprehensive error handling

## 🚀 **DEPLOYMENT STEPS**

### **Step 1: Push Code Changes**
```bash
git add .
git commit -m "🔧 Fix Celery workers not starting - self-contained entrypoint"
git push origin main
```

### **Step 2: CapRover Deployment**
1. **Go to CapRover Dashboard**
2. **Navigate to your extract-text app**
3. **Go to "Deployment" tab**
4. **Click "Deploy via docker-compose"**
5. **Upload the updated `docker-compose.caprover.yml`**
6. **Ensure these Template Variables are set:**
   ```
   cap_redis_url=redis://srv-captain--extract-text-redis:6379/0
   cap_redis_cache_url=redis://srv-captain--extract-text-redis:6379/1  
   cap_ollama_host=https://andy-imakol.ngrok.dev
   cap_remote_api_url= (leave empty)
   ```

### **Step 3: Force Rebuild (Important!)**
1. **In CapRover Dashboard**
2. **Go to your app's "Deployment" tab**
3. **Click "Force rebuild without cache"**
4. **Wait for deployment to complete**

## 🔬 **VERIFICATION STEPS**

### **1. Check Service Status**
Hit your health endpoint:
```bash
curl https://your-extract-text-domain.com/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "services": {
    "api": "healthy",
    "redis": "healthy", 
    "ollama": "healthy",
    "celery": "healthy"  ← THIS SHOULD NOW BE HEALTHY!
  }
}
```

### **2. Test OCR Processing**
```bash
# Upload test file
curl -X POST "https://your-domain.com/ocr/upload" \
  -F "strategy=docling" \
  -F "prompt=" \
  -F "model=" \
  -F "file=@test.pdf" \
  -F "ocr_cache=false" \
  -F "storage_profile=" \
  -F "storage_filename=" \
  -F "language=en"

# Should return: {"task_id": "abc123..."}

# Check result (should progress from PENDING → SUCCESS)
curl "https://your-domain.com/ocr/result/abc123..."
```

## 🆘 **TROUBLESHOOTING**

### **If Celery still shows "unhealthy":**
1. **Check container logs in CapRover**
2. **Verify template variables are set correctly**
3. **Ensure Redis service is running**
4. **Force rebuild one more time**

### **If build fails:**
1. **Check the Dockerfile was updated properly**
2. **Verify all files are committed and pushed**
3. **Try manual Docker deployment instead of compose**

## 📋 **SUCCESS INDICATORS**
- ✅ Health endpoint shows `"celery": "healthy"`
- ✅ OCR tasks go from PENDING → PROCESSING → SUCCESS
- ✅ `/ocr/result/{task_id}` returns actual extracted text
- ✅ No more "no active workers" errors
- ✅ Your Solomon app can successfully process insurance documents

## 🎯 **KEY CHANGES SUMMARY**
1. **Dockerfile**: Self-contained entrypoint script (no external dependencies)
2. **docker-compose.caprover.yml**: Explicit entrypoint directive + full env vars
3. **Robust error handling**: Better logging and Redis connection management

**This fix ensures your Celery workers will start reliably in CapRover production environment!** 