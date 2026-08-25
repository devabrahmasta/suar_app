FROM python:3.10-slim

# Install system dependencies needed for OpenQuake / GDAL / Spatial libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gdal-bin \
    libgdal-dev \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY . .

# Hugging Face Spaces exposes port 7860 by default
EXPOSE 7860

# Run FastAPI app with Uvicorn on 0.0.0.0:7860
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "7860"]
