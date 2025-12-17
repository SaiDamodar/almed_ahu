# Dockerfile for Railway.com deployment
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
# gcc is needed for some Python packages that compile C extensions
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose port (Railway will set PORT env var automatically)
# Default to 5000 for local development
ENV PORT=5000
EXPOSE $PORT

# Health check for Railway (optional - Railway has built-in health checks)
# HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
#     CMD python -c "import requests; requests.get('http://localhost:${PORT}/api/health', timeout=5)" || exit 1

# Run the application
# Railway sets PORT automatically, we read it from environment
CMD python app.py

