import re

# Read the file  
with open('text_extract_api/extract/tasks.py', 'r') as f:
    content = f.read()

# Add Client import and initialization
content = content.replace('import ollama', '''import ollama
from ollama import Client
import os''')

# Add ollama client initialization at the beginning of the task
task_start_pattern = r'(def ocr_task\(\s+self,.*?\):\s+)'
replacement = r'''\1
    # Initialize Ollama client with external endpoint
    ollama_host = os.getenv('OLLAMA_HOST', 'http://localhost:11434')
    ollama_client = Client(host=ollama_host)

'''

content = re.sub(task_start_pattern, replacement, content, flags=re.DOTALL)

# Replace ollama.generate with ollama_client.generate
content = content.replace('llm_resp = ollama.generate(model, prompt + extracted_text, stream=True)', 'llm_resp = ollama_client.generate(model, prompt + extracted_text, stream=True)')

# Write back
with open('text_extract_api/extract/tasks.py', 'w') as f:
    f.write(content)

print("Fixed tasks.py")
