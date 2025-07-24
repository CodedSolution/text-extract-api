import pathlib
import sys
import os

from celery import Celery
from dotenv import load_dotenv

sys.path.insert(0, str(pathlib.Path(__file__).parent.resolve()))

load_dotenv(".env.localhost")

import multiprocessing

multiprocessing.set_start_method("spawn", force=True)

app = Celery(
    "text_extract_api",
    broker="redis://redis:6379/0",
    backend="redis://redis:6379/0"
)

# Get configuration values from environment or use defaults
task_time_limit = int(os.getenv('TASK_TIME_LIMIT', 1800))  # 30 minutes default
task_soft_time_limit = int(os.getenv('TASK_SOFT_TIME_LIMIT', 1500))  # 25 minutes default
result_expires = int(os.getenv('RESULT_EXPIRES', 3600))  # 1 hour default
worker_max_memory = int(os.getenv('CELERY_WORKER_MAX_MEMORY_PER_CHILD', 512000))  # 512MB default
worker_max_tasks = int(os.getenv('CELERY_WORKER_MAX_TASKS_PER_CHILD', 10))  # 10 tasks default
worker_prefetch = int(os.getenv('CELERY_WORKER_PREFETCH_MULTIPLIER', 1))  # 1 task default

app.config_from_object({
    "worker_max_memory_per_child": worker_max_memory,
    "worker_max_tasks_per_child": worker_max_tasks,
    "task_time_limit": task_time_limit,
    "task_soft_time_limit": task_soft_time_limit,
    "result_expires": result_expires,
    "task_acks_late": True,
    "worker_prefetch_multiplier": worker_prefetch,
    "task_reject_on_worker_lost": True,
})

app.autodiscover_tasks(["text_extract_api.extract"], 'tasks', True)
