# CapRover App Configuration for Text Extract API

## Environment Variables to Set in CapRover

When deploying this application to CapRover, you'll need to set the following environment variables in your app settings:

### Required Environment Variables:
```
cap_redis_url=redis://srv-captain--text-extract-api-redis:6379/0
cap_redis_cache_url=redis://srv-captain--text-extract-api-redis:6379/1
cap_ollama_host=http://srv-captain--text-extract-api-ollama:11434
cap_list_files_url=https://your-app-name.your-domain.com/storage/list
cap_load_file_url=https://your-app-name.your-domain.com/storage/load
cap_delete_file_url=https://your-app-name.your-domain.com/storage/delete
```

### Optional Environment Variables:
```
cap_remote_api_url=
```

## Deployment Steps:

1. **Create the app in CapRover:**
   - Go to your CapRover dashboard
   - Click "Apps" and then "Create New App"
   - Enter your app name (e.g., "text-extract-api")
   - Enable "Has Persistent Data" if you want to persist uploaded files

2. **Set Environment Variables:**
   - In your app settings, go to "App Configs"
   - Add the environment variables listed above
   - Replace "your-app-name" and "your-domain.com" with your actual values

3. **Deploy the app:**
   - Upload your project files or connect to your Git repository
   - CapRover will automatically build and deploy using the captain-definition file

4. **Configure HTTPS (Optional but Recommended):**
   - Go to "HTTP Settings" in your app
   - Enable HTTPS and force redirect if desired

5. **Monitor the deployment:**
   - Check the app logs to ensure all services start correctly
   - The Ollama service will take some time to download models on first run

## Important Notes:

- **Storage**: The app uses persistent volumes for storage, uploads, Redis data, and Ollama models
- **Memory Requirements**: Ollama and the ML models require significant RAM (recommended: 4GB+ for basic models)
- **First Startup**: Initial deployment will take longer as it downloads LLM models (llama3.1, llama3.2-vision, minicpm-v)
- **Health Checks**: Ollama service includes health checks to ensure it's ready before other services start

## Accessing Your App:

After deployment, your API will be available at:
- Main API: `https://your-app-name.your-domain.com`
- API Documentation: `https://your-app-name.your-domain.com/docs`

## Scaling:

You can scale the Celery workers by adjusting the replica count in CapRover if needed for heavy processing workloads.
