# Use Python 3.9 slim image for smaller size
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Download spaCy Chinese model
RUN python -m spacy download zh_core_web_sm

# Copy application files
COPY script.py .
COPY definitions.txt .

# Create necessary directories
RUN mkdir -p input known unknown

# Copy directory contents - use .dockerignore to handle missing dirs
# These will only copy if directories exist and contain files
COPY --chown=root:root . /tmp/build/
RUN if [ -d /tmp/build/input ]; then cp -r /tmp/build/input/* input/ 2>/dev/null || true; fi && \
    if [ -d /tmp/build/known ]; then cp -r /tmp/build/known/* known/ 2>/dev/null || true; fi && \
    if [ -d /tmp/build/unknown ]; then cp -r /tmp/build/unknown/* unknown/ 2>/dev/null || true; fi && \
    rm -rf /tmp/build

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Run the script
CMD ["python", "script.py"]