# 修复 extract-text 服务 Celery Workers 问题

## 问题描述
extract-text 服务的 Celery worker 进程没有运行，导致OCR任务一直处于 PENDING 状态。

## 解决步骤

### 1. 登录到 extract-text 服务器
```bash
# SSH到您的extract-text服务器
ssh user@your-extract-text-server
```

### 2. 检查当前状态
```bash
# 检查extract-text应用状态
ps aux | grep extract-text
ps aux | grep celery

# 检查Redis状态
redis-cli ping

# 检查端口占用
netstat -tlnp | grep 8000
```

### 3. 启动 Celery Workers

#### 方法 A: 如果有 docker-compose
```bash
# 进入extract-text项目目录
cd /path/to/extract-text

# 重启服务，确保包含worker
docker-compose up -d

# 检查worker状态
docker-compose ps
docker-compose logs celery-worker
```

#### 方法 B: 手动启动 Celery
```bash
# 进入extract-text项目目录
cd /path/to/extract-text

# 启动Celery worker (后台运行)
celery -A app worker --loglevel=info --detach

# 或者使用screen/tmux
screen -S celery-worker
celery -A app worker --loglevel=info
# 按 Ctrl+A, D 断开screen
```

#### 方法 C: 使用 systemd 服务
```bash
# 创建systemd服务文件
sudo nano /etc/systemd/system/extract-text-worker.service

# 服务文件内容:
[Unit]
Description=Extract Text Celery Worker
After=network.target

[Service]
Type=forking
User=your-user
Group=your-group
WorkingDirectory=/path/to/extract-text
Environment=PATH=/path/to/extract-text/venv/bin
ExecStart=/path/to/extract-text/venv/bin/celery -A app worker --loglevel=info --detach
ExecStop=/bin/kill -s TERM $MAINPID
Restart=always

[Install]
WantedBy=multi-user.target

# 启动服务
sudo systemctl daemon-reload
sudo systemctl enable extract-text-worker
sudo systemctl start extract-text-worker
sudo systemctl status extract-text-worker
```

### 4. 验证修复
```bash
# 检查健康状态
curl https://extract-text.dev.api.codedtech.tech/health

# 应该显示:
# "celery": "healthy"

# 测试上传和处理
curl -X POST https://extract-text.dev.api.codedtech.tech/ocr/upload \
  -F "file=@test.pdf" \
  -F "strategy=docling"
```

### 5. 监控和维护
```bash
# 监控worker日志
tail -f /var/log/extract-text-worker.log

# 检查worker进程
ps aux | grep celery

# 重启worker (如果需要)
sudo systemctl restart extract-text-worker
```

## 常见问题

### Q: Worker启动失败
```bash
# 检查错误信息
journalctl -u extract-text-worker -f

# 常见问题:
# 1. Redis连接问题 - 检查Redis配置
# 2. 权限问题 - 检查文件权限
# 3. 环境变量问题 - 检查.env文件
```

### Q: Worker运行但任务不处理
```bash
# 检查队列状态
redis-cli
KEYS *
LLEN celery  # 检查队列长度

# 重启Redis
sudo systemctl restart redis
```

### Q: 模型配置问题
确认extract-text配置文件中的AI模型设置：
- 如果使用外部API，确保网络连接正常
- 如果使用本地模型，确保模型文件存在且路径正确

## 预防措施

1. **监控脚本**: 创建健康检查脚本
2. **自动重启**: 配置systemd自动重启
3. **日志轮转**: 配置日志轮转避免磁盘满
4. **资源监控**: 监控CPU/内存使用情况