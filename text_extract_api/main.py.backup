import os
import pathlib
import sys
import time
import logging
import traceback
from typing import Optional

import ollama
import redis
from celery.result import AsyncResult
from fastapi import FastAPI, Form, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

from text_extract_api.celery_app import app as celery_app
from text_extract_api.extract.strategies.strategy import Strategy
from text_extract_api.extract.tasks import ocr_task
from text_extract_api.files.file_formats.file_format import FileFormat, FileField
from text_extract_api.files.storage_manager import StorageManager

# Define base path as text_extract_api - required for keeping absolute namespaces
sys.path.insert(0, str(pathlib.Path(__file__).parent.resolve()))

def storage_profile_exists(profile_name: str) -> bool:
    profile_path = os.path.abspath(
        os.path.join(os.getenv('STORAGE_PROFILE_PATH', './storage_profiles'), f'{profile_name}.yaml'))
    if not os.path.isfile(profile_path) and profile_path.startswith('..'):
        # backward compability for ../storage_manager in .env
        sub_profile_path = os.path.normpath(os.path.join('.', profile_path))
        return os.path.isfile(sub_profile_path)
    return True

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your frontend domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Connect to Redis
redis_url = os.getenv('REDIS_CACHE_URL')
if not redis_url:
    logger.error("REDIS_CACHE_URL environment variable is not set!")
    raise ValueError("REDIS_CACHE_URL environment variable must be set")
redis_client = redis.StrictRedis.from_url(redis_url)

# Log startup configuration
logger.info("=== Text Extract API Starting ===")
logger.info(f"Redis Cache URL: {redis_url}")
logger.info(f"Celery Broker URL: {os.getenv('CELERY_BROKER_URL', 'Not Set')}")
logger.info(f"Celery Result Backend: {os.getenv('CELERY_RESULT_BACKEND', 'Not Set')}")
logger.info(f"Ollama Host: {os.getenv('OLLAMA_HOST', 'Not Set')}")
logger.info(f"App Environment: {os.getenv('APP_ENV', 'Not Set')}")
logger.info(f"Storage Profile Path: {os.getenv('STORAGE_PROFILE_PATH', 'Not Set')}")
logger.info("=================================")

@app.get("/")
async def root():
    """Root endpoint to check if the API is running"""
    return {"message": "Text Extract API is running", "status": "healthy"}

@app.get("/health")
async def health_check():
    """Health check endpoint to verify all services are working"""
    logger.info("Health check requested")
    health_status = {
        "api": "healthy",
        "redis": "unknown",
        "ollama": "unknown",
        "celery": "unknown"
    }
    
    # Check Redis connection
    try:
        redis_client.ping()
        health_status["redis"] = "healthy"
        logger.info("Redis health check: healthy")
    except Exception as e:
        error_msg = f"unhealthy: {str(e)}"
        health_status["redis"] = error_msg
        logger.error(f"Redis health check failed: {str(e)}")
    
    # Check Ollama connection
    try:
        ollama_host = os.getenv('OLLAMA_HOST', 'http://ollama:11434')
        import requests
        response = requests.get(f"{ollama_host}/api/version", timeout=5)
        if response.status_code == 200:
            health_status["ollama"] = "healthy"
            logger.info("Ollama health check: healthy")
        else:
            error_msg = f"unhealthy: status {response.status_code}"
            health_status["ollama"] = error_msg
            logger.error(f"Ollama health check failed: {error_msg}")
    except Exception as e:
        error_msg = f"unhealthy: {str(e)}"
        health_status["ollama"] = error_msg
        logger.error(f"Ollama health check failed: {str(e)}")
    
    # Check Celery workers
    try:
        inspect = celery_app.control.inspect()
        active_workers = inspect.active()
        if active_workers:
            health_status["celery"] = "healthy"
            logger.info(f"Celery health check: healthy, active workers: {list(active_workers.keys())}")
        else:
            error_msg = "unhealthy: no active workers"
            health_status["celery"] = error_msg
            logger.warning("Celery health check: no active workers found")
    except Exception as e:
        error_msg = f"unhealthy: {str(e)}"
        health_status["celery"] = error_msg
        logger.error(f"Celery health check failed: {str(e)}")
        logger.error(f"Celery error traceback: {traceback.format_exc()}")
    
    overall_healthy = all(status == "healthy" for status in health_status.values())
    
    logger.info(f"Overall health status: {'healthy' if overall_healthy else 'degraded'}")
    
    return {
        "status": "healthy" if overall_healthy else "degraded",
        "services": health_status
    }

@app.post("/ocr")
async def ocr_endpoint(
        strategy: str = Form(...),
        prompt: str = Form(None),
        model: str = Form(...),
        file: UploadFile = File(...),
        ocr_cache: bool = Form(...),
        storage_profile: str = Form('default'),
        storage_filename: str = Form(None),
        language: str = Form('en')
):
    """
    Endpoint to extract text from an uploaded PDF, Image or Office file using different OCR strategies.
    Supports both synchronous and asynchronous processing.
    """
    try:
        logger.info(f"OCR request received - strategy: {strategy}, model: {model}, file: {file.filename}, ocr_cache: {ocr_cache}")
        
        # Validate input
        try:
            OcrFormRequest(strategy=strategy, prompt=prompt, model=model, ocr_cache=ocr_cache,
                           storage_profile=storage_profile, storage_filename=storage_filename, language=language)
        except ValueError as e:
            logger.error(f"Validation error: {str(e)}")
            raise HTTPException(status_code=400, detail=str(e))

        filename = storage_filename if storage_filename else file.filename
        file_binary = await file.read()
        file_format = FileFormat.from_binary(file_binary, filename, file.content_type)

        logger.info(f"Processing Document {file_format.filename} with strategy: {strategy}, ocr_cache: {ocr_cache}, model: {model}, storage_profile: {storage_profile}, storage_filename: {storage_filename}, language: {language}, will be saved as: {filename}")

        # Test Redis connection before creating task
        try:
            redis_client.ping()
            logger.info("Redis connection successful")
        except Exception as redis_error:
            logger.error(f"Redis connection failed: {str(redis_error)}")
            raise HTTPException(status_code=500, detail=f"Redis connection failed: {str(redis_error)}")

        # Test Celery connection
        try:
            inspect = celery_app.control.inspect()
            active_workers = inspect.active()
            if not active_workers:
                logger.warning("No active Celery workers found")
            else:
                logger.info(f"Active Celery workers: {list(active_workers.keys())}")
        except Exception as celery_error:
            logger.error(f"Celery connection failed: {str(celery_error)}")
            raise HTTPException(status_code=500, detail=f"Celery connection failed: {str(celery_error)}")

        # Asynchronous processing using Celery
        try:
            task = ocr_task.apply_async(
                args=[file_format.binary, strategy, file_format.filename, file_format.hash, ocr_cache, prompt, model, language,
                      storage_profile, storage_filename])
            logger.info(f"Task created successfully with ID: {task.id}")
            return {"task_id": task.id}
        except Exception as task_error:
            logger.error(f"Failed to create Celery task: {str(task_error)}")
            logger.error(f"Traceback: {traceback.format_exc()}")
            raise HTTPException(status_code=500, detail=f"Failed to create task: {str(task_error)}")

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in OCR endpoint: {str(e)}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


# this is an alias for /ocr - to keep the backward compatibility
@app.post("/ocr/upload")
async def ocr_upload_endpoint(
        strategy: str = Form(...),
        prompt: str = Form(None),
        model: str = Form(None),
        file: UploadFile = File(...),
        ocr_cache: bool = Form(...),
        storage_profile: str = Form('default'),
        storage_filename: str = Form(None),
        language: str = Form('en')
):
    """
    Alias endpoint to extract text from an uploaded PDF/Office/Image file using different OCR strategies.
    Supports both synchronous and asynchronous processing.
    """
    logger.info(f"OCR upload request received via /ocr/upload endpoint")
    return await ocr_endpoint(strategy, prompt, model, file, ocr_cache, storage_profile, storage_filename, language)


class OllamaGenerateRequest(BaseModel):
    model: str
    prompt: str


class OllamaPullRequest(BaseModel):
    model: str


class OcrRequest(BaseModel):
    strategy: str = Field(..., description="OCR strategy to use")
    prompt: Optional[str] = Field(None, description="Prompt for the Ollama model")
    model: Optional[str] = Field(None, description="Model to use for the Ollama endpoint")
    file: FileField = Field(..., description="Base64 encoded document file")
    ocr_cache: bool = Field(..., description="Enable OCR result caching")
    storage_profile: Optional[str] = Field('default', description="Storage profile to use")
    storage_filename: Optional[str] = Field(None, description="Storage filename to use")
    language: Optional[str] = Field('en', description="Language to use for OCR")

    @field_validator('strategy')
    def validate_strategy(cls, v):
        Strategy.get_strategy(v)
        return v

    @field_validator('storage_profile')
    def validate_storage_profile(cls, v):
        if not storage_profile_exists(v):
            raise ValueError(f"Storage profile '{v}' does not exist.")
        return v


class OcrFormRequest(BaseModel):
    strategy: str = Field(..., description="OCR strategy to use")
    prompt: Optional[str] = Field(None, description="Prompt for the Ollama model")
    model: Optional[str] = Field(None, description="Model to use for the Ollama endpoint")
    ocr_cache: bool = Field(..., description="Enable OCR result caching")
    storage_profile: Optional[str] = Field('default', description="Storage profile to use")
    storage_filename: Optional[str] = Field(None, description="Storage filename to use")
    language: Optional[str] = Field('en', description="Language to use for OCR")

    @field_validator('strategy')
    def validate_strategy(cls, v):
        Strategy.get_strategy(v)
        return v

    @field_validator('storage_profile')
    def validate_storage_profile(cls, v):
        if not storage_profile_exists(v):
            raise ValueError(f"Storage profile '{v}' does not exist.")
        return v


@app.post("/ocr/request")
async def ocr_request_endpoint(request: OcrRequest):
    """
    Endpoint to extract text from an uploaded PDF/Office/Image file using different OCR strategies.
    Supports both synchronous and asynchronous processing.
    """
    # Validate input
    request_data = request.model_dump()
    try:
        OcrRequest(**request_data)
        file = FileFormat.from_base64(request.file, request.storage_filename)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    print(
        f"Processing {file.mime_type} with strategy: {request.strategy}, ocr_cache: {request.ocr_cache}, model: {request.model}, storage_profile: {request.storage_profile}, storage_filename: {request.storage_filename}, language: {request.language}")

    # Asynchronous processing using Celery
    task = ocr_task.apply_async(
        args=[file.binary, request.strategy, file.filename, file.hash, request.ocr_cache, request.prompt,
              request.model, request.language, request.storage_profile, request.storage_filename])
    return {"task_id": task.id}


@app.get("/ocr/result/{task_id}")
async def ocr_status(task_id: str):
    """
    Endpoint to get the status of an OCR task using task_id.
    """
    task = AsyncResult(task_id, app=celery_app)

    if task.state == 'PENDING':
        return {"state": task.state, "status": "Task is pending..."}
    elif task.state == 'PROGRESS':
        task_info = task.info
        if task_info.get('start_time'):
            task_info['elapsed_time'] = time.time() - int(task_info.get('start_time'))
        return {"state": task.state, "status": task.info.get("status"), "info": task_info}
    elif task.state == 'SUCCESS':
        return {"state": task.state, "status": "Task completed successfully.", "result": task.result}
    else:
        return {"state": task.state, "status": str(task.info)}


@app.post("/ocr/clear_cache")
async def clear_ocr_cache():
    """
    Endpoint to clear the OCR result cache in Redis.
    """
    redis_client.flushdb()
    return {"status": "OCR cache cleared"}


@app.get("/storage/list")
async def list_files(storage_profile: str = 'default'):
    """
    Endpoint to list files using the selected storage profile.
    """
    storage_manager = StorageManager(storage_profile)
    files = storage_manager.list()
    return {"files": files}


@app.get("/storage/load")
async def load_file(file_name: str, storage_profile: str = 'default'):
    """
    Endpoint to load a file using the selected storage profile.
    """
    storage_manager = StorageManager(storage_profile)
    content = storage_manager.load(file_name)
    return {"content": content}


@app.delete("/storage/delete")
async def delete_file(file_name: str, storage_profile: str = 'default'):
    """
    Endpoint to delete a file using the selected storage profile.
    """
    storage_manager = StorageManager(storage_profile)
    storage_manager.delete(file_name)
    return {"status": f"File {file_name} deleted successfully"}


@app.post("/llm/pull")
async def pull_llama(request: OllamaPullRequest):
    """
    Endpoint to pull the latest Llama model from the Ollama API.
    """
    print("Pulling " + request.model)
    try:
        response = ollama.pull(request.model)
    except ollama.ResponseError as e:
        print('Error:', e.error)
        raise HTTPException(status_code=500, detail="Failed to pull Llama model from Ollama API")

    return {"status": response.get("status", "Model pulled successfully")}


@app.post("/llm/generate")
async def generate_llama(request: OllamaGenerateRequest):
    """
    Endpoint to generate text using Llama 3.1 model (and other models) via the Ollama API.
    """
    print(request)
    if not request.prompt:
        raise HTTPException(status_code=400, detail="No prompt provided")

    try:
        response = ollama.generate(request.model, request.prompt)
    except ollama.ResponseError as e:
        print('Error:', e.error)
        if e.status_code == 404:
            print("Error: ", e.error)
            ollama.pull(request.model)

        raise HTTPException(status_code=500, detail="Failed to generate text with Ollama API")

    generated_text = response.get("response", "")
    return {"generated_text": generated_text}
