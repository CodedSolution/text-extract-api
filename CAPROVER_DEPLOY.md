# CapRover App Configuration for Text Extract API (Docling-Only Optimized Version)

## Environment Variables to Set in CapRover

When deploying this optimized application to CapRover, you'll need to set the following environment variables in your app settings:

### Required Template Variables:
```
cap_redis_url=redis://srv-captain--text-extract-api-redis:6379/0
cap_redis_cache_url=redis://srv-captain--text-extract-api-redis:6379/1
```

### Optional Template Variables:
```
cap_remote_api_url=
```

**Note**: This optimized version removes Ollama dependencies for faster deployment and lower resource usage.

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

- **Storage**: The app uses persistent volumes for storage, uploads, and Redis data
- **Memory Requirements**: Optimized version requires minimal RAM (recommended: 1-2GB)
- **Fast Startup**: Deployment takes 2-3 minutes (no model downloads required)
- **Docling Strategy**: Uses Docling for PDF text extraction - no AI models needed locally

## Accessing Your App:

After deployment, your API will be available at:
- Main API: `https://your-app-name.your-domain.com`
- API Documentation: `https://your-app-name.your-domain.com/docs`

## Scaling:

You can scale the Celery workers by adjusting the replica count in CapRover if needed for heavy processing workloads.
