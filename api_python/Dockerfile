FROM mcr.microsoft.com/devcontainers/python:3.12-bullseye

WORKDIR /app

RUN mkdir -p /app/uploads
COPY ./api_python/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY ./api_python/app.py .
EXPOSE 5000

CMD ["python", "app.py"]
