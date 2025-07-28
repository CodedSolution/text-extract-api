import re

# Read the file
with open('text_extract_api/main.py', 'r') as f:
    content = f.read()

# Add Client import after ollama import
content = content.replace('import ollama', 'import ollama\nfrom ollama import Client')

# Add ollama client initialization after health check
health_check_pattern = r'(health_status\["ollama"\] = error_msg\s+logger\.error\(f"Ollama health check failed: \{str\(e\)\}"\))'
replacement = r'''\1

# Initialize Ollama client with external host
ollama_host = os.getenv('OLLAMA_HOST', 'http://localhost:11434')
ollama_client = Client(host=ollama_host)'''

content = re.sub(health_check_pattern, replacement, content)

# Replace ollama.pull with ollama_client.pull
content = content.replace('ollama.pull(request.model)', 'ollama_client.pull(request.model)')

# Replace ollama.generate with ollama_client.generate  
content = content.replace('ollama.generate(request.model, request.prompt)', 'ollama_client.generate(request.model, request.prompt)')

# Remove the auto-pull logic
auto_pull_pattern = r'if e\.status_code == 404:\s+print\("Error: ", e\.error\)\s+ollama\.pull\(request\.model\)'
content = re.sub(auto_pull_pattern, '# Model should be available on external endpoint', content)

# Write back
with open('text_extract_api/main.py', 'w') as f:
    f.write(content)

print("Fixed main.py")
