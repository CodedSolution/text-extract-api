# 🚀 **DEPLOYMENT GUIDE - Celery Worker Fix**

## 📋 **Dockerfile 更改总结**

### **主要修复:**

1. **🔧 添加了 libmagic 依赖**
   ```dockerfile
   RUN apt-get update && apt-get install -y \
       gcc \
       g++ \
       curl \
       libmagic1 \        ← 新增
       libmagic-dev \      ← 新增
       && rm -rf /var/lib/apt/lists/*
   ```

2. **🛠️ 自包含的入口脚本**
   - 直接在Dockerfile中创建，不依赖外部文件
   - 绕过`.dockerignore`限制
   - 包含完整的Celery worker配置

3. **⚙️ 增强的Celery配置**
   ```bash
   exec celery -A text_extract_api.celery_app worker \
       --loglevel=info \
       --pool=solo \
       --concurrency=2 \
       --max-memory-per-child=512000 \
       --max-tasks-per-child=10 \
       --prefetch-multiplier=1 \
       --without-gossip \
       --without-mingle \
       --without-heartbeat
   ```

4. **🔍 详细的环境变量处理**
   - 自动设置默认值
   - 完整的日志记录
   - Redis连接等待机制

## 🚀 **部署方式**

### **方式1: 自动部署 (Git Push) - 简单但有限制**
```bash
git add .
git commit -m "🔧 修复Celery workers - 自包含入口点 + libmagic依赖"
git push origin main
```
- ✅ **简单** - 推送后CapRover自动部署
- ❌ **限制** - 只使用`Dockerfile`，忽略`docker-compose.caprover.yml`
- ❌ **结果** - Celery worker可能还是不会启动

### **方式2: 手动部署 (推荐) - 完整功能**
1. **推送代码更改**
   ```bash
   git add .
   git commit -m "🔧 修复Celery workers - 自包含入口点 + libmagic依赖"
   git push origin main
   ```

2. **开发者手动部署**
   - 进入CapRover仪表板
   - 选择extract-text应用
   - 点击"Deployment"标签
   - 选择"Deploy via docker-compose"
   - 上传`docker-compose.caprover.yml`文件

3. **强制重建 (重要!)**
   - 在CapRover中点击"Force rebuild without cache"
   - 等待部署完成

## 🔧 **为什么需要手动部署?**

### **自动部署的问题:**
- CapRover的Git自动部署只使用`Dockerfile`
- 忽略`docker-compose.caprover.yml`文件
- 不会启动Celery worker服务
- 只运行FastAPI应用

### **手动部署的优势:**
- 使用`docker-compose.caprover.yml`配置
- 启动完整的服务栈 (FastAPI + Redis + Celery)
- 正确的环境变量配置
- 服务间依赖关系

## 📊 **验证部署成功**

### **1. 检查健康状态**
```bash
curl https://your-domain.com/health
```

**期望响应:**
```json
{
  "status": "healthy",
  "services": {
    "api": "healthy",
    "redis": "healthy", 
    "ollama": "healthy",
    "celery": "healthy"  ← 关键指标!
  }
}
```

### **2. 测试OCR处理**
```bash
# 上传测试文件
curl -X POST "https://your-domain.com/ocr/upload" \
  -F "strategy=docling" \
  -F "prompt=" \
  -F "model=" \
  -F "file=@test.pdf" \
  -F "ocr_cache=false" \
  -F "storage_profile=" \
  -F "storage_filename=" \
  -F "language=en"

# 应该返回: {"task_id": "abc123..."}

# 检查结果 (应该从PENDING → SUCCESS)
curl "https://your-domain.com/ocr/result/abc123..."
```

## 🆘 **故障排除**

### **如果Celery仍然显示"unhealthy":**
1. **检查容器日志**
   - 在CapRover中查看容器日志
   - 查找错误信息

2. **验证模板变量**
   ```
   cap_redis_url=redis://srv-captain--extract-text-redis:6379/0
   cap_redis_cache_url=redis://srv-captain--extract-text-redis:6379/1
   cap_ollama_host=https://andy-imakol.ngrok.dev
   cap_remote_api_url= (留空)
   ```

3. **确保Redis服务运行**
   - 检查Redis容器状态
   - 验证网络连接

4. **再次强制重建**
   - 清除Docker缓存
   - 重新构建镜像

### **如果构建失败:**
1. **检查Dockerfile是否正确更新**
2. **验证所有文件已提交和推送**
3. **尝试手动Docker部署**

## 📋 **成功指标**
- ✅ 健康端点显示 `"celery": "healthy"`
- ✅ OCR任务从PENDING → PROCESSING → SUCCESS
- ✅ `/ocr/result/{task_id}`返回实际提取的文本
- ✅ 不再有"no active workers"错误
- ✅ 你的Solomon应用可以成功处理保险文档

## 🎯 **关键更改总结**
1. **Dockerfile**: 自包含入口脚本 + libmagic依赖
2. **docker-compose.caprover.yml**: 明确入口点指令 + 完整环境变量
3. **强大的错误处理**: 更好的日志和Redis连接管理

**这个修复确保你的Celery workers在CapRover生产环境中可靠启动!** 