# MediQ OCR Engine Service - Python Flask with YOLO + EasyOCR
FROM python:3.11-slim as base

# Install system dependencies untuk OpenCV dan ML libraries
RUN apt-get update && apt-get install -y \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libfontconfig1 \
    libxrender1 \
    libgomp1 \
    libgcc-s1 \
    libgl1-mesa-glx \
    libgthread-2.0-0 \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create non-root user untuk security
RUN groupadd -r ocr && useradd -r -g ocr -u 1001 ocr

WORKDIR /app

# Copy requirements dan install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy application code dengan proper ownership
COPY --chown=ocr:ocr . .

# Create necessary directories dengan proper permissions
RUN mkdir -p debug_out runs/detect_train/weights uploads temp \
    && chown -R ocr:ocr /app

# Set environment variables
ENV PYTHONPATH=/app
ENV PORT=8604
ENV FLASK_ENV=production
ENV PYTHONUNBUFFERED=1
ENV PIN_OCR_CONFIG=config.yaml

# Switch to non-root user
USER ocr

# Expose port
EXPOSE 8604

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8604/health/health || exit 1

# Run the application
CMD ["python", "app.py"]
