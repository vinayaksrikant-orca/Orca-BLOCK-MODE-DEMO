FROM alpine:3.10
WORKDIR /app
RUN apk add --no-cache python3 py3-pip && \
    pip3 install requests==2.20.0
COPY app.py .
ENV API_KEY="AIzaSyAExampleSecretKey4ScanTestingOnly"
CMD ["python3", "-c", "print('Vulnerable image is running...')"]