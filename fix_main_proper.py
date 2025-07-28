import re

# Read the file
with open('text_extract_api/main.py', 'r') as f:
    content = f.read()

# Add Client import after ollama import
content = content.replace('import ollama', 'import ollama\nfrom ollama import Client')

# Find the place after health check to add ollama client initialization
pattern = r'(health_status\["ollama"\] = error_msg\s+logger\.error\(f"Ollama health check failed: \{str\(e\)\}"\))'
replacement = r'''\1

# Initialize Ollama client with external host
ollama_host = os.getenv('OLLAMA_HOST', 'http://localhost:11434')
ollama_client = Client(host=ollama_host)'''

content = re.sub(pattern, replacement, content)

# Replace ollama.pull and ollama.generate with ollama_client
content = content.replace('ollama.pull(request.model)', 'ollama_client.pull(request.model)')
content = content.replace('ollama.generate(request.model, request.prompt)', 'ollama_client.generate(request.model, request.prompt)')

# Remove the auto-pull logic - replace with comment
content = content.replace('''        if e.status_code == 404:
            print("Error: ", e.error)
            ollama.pull(request.model)''', '            # Model should be available on external endpoint')

# Write back
with open('text_extract_api/main.py', 'w') as f:
    f.write(content)

print("Fixed main.py properly")
