# INTENTIONALLY VULNERABLE DOCKERFILE
# Triggers: container scan, IaC findings

# Old base image with known CVEs
FROM python:3.8-slim-buster

# Running as root - security misconfiguration
USER root

# Hardcoded secrets in ENV (triggers secret scan)
ENV AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
ENV AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
ENV DB_PASSWORD="SuperSecret@Password123!"
ENV GITHUB_TOKEN="ghp_1234567890abcdefghijklmnopqrstuvwxyz12"
ENV STRIPE_SECRET="sk_live_4eC39HqLyjWDarjtT1zdp7dc"
ENV JWT_SECRET="my_super_secret_jwt_key_that_is_hardcoded"
ENV FLASK_SECRET="flask_secret_key_hardcoded_12345"

# Install packages without pinning (non-deterministic)
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    netcat \
    nmap \
    openssh-server \
    telnet \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .

# Install vulnerable packages
RUN pip install --no-cache-dir -r requirements.txt \
    --trusted-host pypi.org \
    --trusted-host files.pythonhosted.org

COPY . .

# World-writable directory
RUN chmod 777 /app

# Expose unnecessary ports
EXPOSE 4499 22 3306 5432 6379 8080 9200

# SSH server started (unnecessary attack surface)
RUN mkdir /var/run/sshd \
    && echo 'root:password123' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Run as root with debug mode
CMD ["python", "app.py"]
