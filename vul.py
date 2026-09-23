import yaml
import subprocess
from flask import Flask, request, render_template_string

app = Flask(__name__)

# 1. Insecure YAML loading (SAST Finding)
# Using yaml.load with the vulnerable PyYAML 3.12 is highly dangerous.
@app.route('/upload-config')
def upload_config():
    user_config = request.args.get('config')
    # FAIL: yaml.load() can execute arbitrary code in older PyYAML versions
    data = yaml.load(user_config) 
    return str(data)

# 2. Server-Side Template Injection (SSTI)
# Using Jinja2 2.10 without proper escaping.
@app.route('/hello')
def hello():
    name = request.args.get('name', 'Guest')
    # FAIL: Directly rendering user input in a template string
    template = f"<h1>Hello {name}!</h1>"
    return render_template_string(template)

# 3. Insecure Command Execution
@app.route('/network-test')
def network_test():
    target_ip = request.args.get('ip')
    # FAIL: Shell=True with user-provided string is a classic Command Injection
    cmd = f"ping -c 1 {target_ip}"
    result = subprocess.check_output(cmd, shell=True)
    return result

if __name__ == "__main__":
    # FAIL: Debug mode should never be True in production
    app.run(debug=True, host="0.0.0.0")