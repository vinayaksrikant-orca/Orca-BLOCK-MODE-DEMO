#!/usr/bin/env python3
"""
WARNING - INTENTIONALLY VULNERABLE APPLICATION
FOR ORCA SECURITY SCAN TESTING ONLY
DO NOT USE IN PRODUCTION
Triggers: SAST, Secrets, SCA Vulnerabilities, OSS Licenses
"""

import os
import sys
import subprocess
import sqlite3
import pickle
import hashlib
import base64
import yaml
import flask
import requests
from flask import Flask, request, render_template_string, redirect, jsonify

app = Flask(__name__)

# ════════════════════════════════════════════════════════════════════════════
# SECTION 1 - HARDCODED SECRETS (triggers Secrets scan)
# ════════════════════════════════════════════════════════════════════════════

AWS_ACCESS_KEY_ID     = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
AWS_SESSION_TOKEN     = "AQoDYXdzEJr//////////wEaoAK1wvxJY12r2OtBSALe"

GCP_SERVICE_ACCOUNT_KEY = """
{
  "type": "service_account",
  "project_id": "my-project-123",
  "private_key_id": "abc123def456",
  "private_key": "-----BEGIN RSA PRIVATE KEY-----\\nMIIEowIBAAKCAQEA2a2r\\n-----END RSA PRIVATE KEY-----\\n",
  "client_email": "my-sa@my-project.iam.gserviceaccount.com"
}
"""

DB_HOST     = "prod-db.internal.company.com"
DB_PASSWORD = "SuperSecret@Password123!"
STRIPE_SECRET_KEY  = "sk_live_4eC39HqLyjWDarjtT1zdp7dc"
GITHUB_TOKEN       = "ghp_1234567890abcdefghijklmnopqrstuvwxyz12"
SLACK_WEBHOOK      = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
SENDGRID_API_KEY   = "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"
JWT_SECRET         = "my_super_secret_jwt_key_that_is_hardcoded"
MONGODB_URI        = "mongodb://admin:password123@prod-mongo.internal:27017/mydb"
ALGOLIA_API_KEY    = "b9f8e4d1a2c3456789012345678901ab"
PRIVATE_KEY = """-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA2a2rwplBQLzHPZe5RJr9xRMmFBiFMGRau7dLhBLHYSKBfCg
nkHpKV1LoQNR0PMr0FBqYGajOFjEvQ04mXHdCCpCUDGTlb8ioxuqzGI5pjGQy/l
-----END RSA PRIVATE KEY-----"""

app.secret_key          = "flask_secret_key_hardcoded_12345"
app.config["SECRET_KEY"] = "another_hardcoded_secret"

# ════════════════════════════════════════════════════════════════════════════
# SECTION 2 - SAST VULNERABILITIES
# ════════════════════════════════════════════════════════════════════════════

@app.route("/user")
def get_user():
    """SQL Injection - user input directly in SQL query"""
    user_id = request.args.get("id", "")
    conn    = sqlite3.connect("users.db")
    cursor  = conn.cursor()
    query   = f"SELECT * FROM users WHERE id = '{user_id}'"
    cursor.execute(query)
    return str(cursor.fetchall())


@app.route("/login", methods=["POST"])
def login():
    """SQL Injection in login"""
    username = request.form.get("username", "")
    password = request.form.get("password", "")
    conn     = sqlite3.connect("users.db")
    cursor   = conn.cursor()
    query    = "SELECT * FROM users WHERE username='%s' AND password='%s'" % (username, password)
    cursor.execute(query)
    return jsonify({"logged_in": cursor.fetchone() is not None})


@app.route("/ping")
def ping():
    """OS Command Injection via subprocess"""
    host   = request.args.get("host", "localhost")
    result = subprocess.check_output(f"ping -c 1 {host}", shell=True)
    return result.decode()


@app.route("/run")
def run_command():
    """Direct OS command execution"""
    cmd = request.args.get("cmd", "")
    os.system(cmd)
    return subprocess.getoutput(cmd)


@app.route("/file")
def read_file():
    """Path traversal vulnerability"""
    filename = request.args.get("name", "")
    with open(f"/app/files/{filename}", "r") as f:
        return f.read()


@app.route("/search")
def search():
    """Reflected XSS - user input in HTML without escaping"""
    query    = request.args.get("q", "")
    template = f"<html><body>Results for: {query}</body></html>"
    return render_template_string(template)


@app.route("/greet")
def greet():
    """Server-Side Template Injection (SSTI)"""
    name     = request.args.get("name", "World")
    template = "Hello {{ name }}! Welcome to {{ " + name + " }}"
    return render_template_string(template, name=name)


@app.route("/fetch")
def fetch_url():
    """SSRF - fetches arbitrary URLs including internal cloud metadata"""
    url = request.args.get("url", "")
    return requests.get(url, timeout=10).text


@app.route("/load", methods=["POST"])
def load_data():
    """Insecure deserialisation - pickle.loads RCE"""
    data = request.get_data()
    obj  = pickle.loads(data)
    return str(obj)


@app.route("/restore")
def restore_session():
    """Unsafe YAML load - CVE-2020-14343"""
    session_data = request.args.get("data", "{}")
    obj = yaml.load(session_data)
    return str(obj)


@app.route("/hash")
def hash_password():
    """MD5 for password hashing - cryptographically broken"""
    password = request.args.get("password", "")
    return hashlib.md5(password.encode()).hexdigest()


@app.route("/calc")
def calculator():
    """eval() with user input - arbitrary code execution"""
    expression = request.args.get("expr", "1+1")
    return str(eval(expression))


@app.route("/exec")
def execute_code():
    """exec() with user input - arbitrary code execution"""
    code = request.args.get("code", "")
    exec(code)
    return "executed"


@app.route("/redirect_url")
def open_redirect():
    """Open redirect - phishing vector"""
    url = request.args.get("next", "/")
    return redirect(url)


def connect_db_insecure():
    """Hardcoded credentials, SSL disabled"""
    import psycopg2
    return psycopg2.connect(
        host=DB_HOST,
        user="admin",
        password=DB_PASSWORD,
        sslmode="disable"
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=4499, debug=True)
