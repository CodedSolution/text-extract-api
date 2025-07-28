# Production Environment Setup for External Ollama

## 🎯 Required CapRover Environment Variables

In CapRover Dashboard → Your App → App Configs → Template Variables, set:

```bash
# REQUIRED - Point to your ngrok endpoint
cap_ollama_host=https://andy-imakol.ngrok.dev

# EXISTING - Keep these as they are
cap_redis_url=redis://srv-captain--extract-text-redis:6379/0
cap_redis_cache_url=redis://srv-captain--extract-text-redis:6379/1
cap_remote_api_url=
```

## ⚠️ CRITICAL: Update Template Variables

**BEFORE deployment, your developer MUST:**
1. Go to CapRover Dashboard
2. Navigate to: Apps → Your App → App Configs → Template Variables  
3. Add: `cap_ollama_host = https://andy-imakol.ngrok.dev`
4. Save changes
5. Then deploy

## 🚨 What Happens Without This:
- ❌ Production will try to connect to localhost:11434
- ❌ Will fail to find models
- ❌ API calls will error out
- ❌ May still try to pull models locally

## ✅ What Happens With This:
- ✅ Production connects to your ngrok endpoint
- ✅ Uses external AI models
- ✅ No local model downloading
- ✅ Fast, lightweight deployment
