# Multi-stage build for minimal Alpine image
FROM python:3.11-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    gcc \
    musl-dev \
    libffi-dev \
    openssl-dev \
    cargo \
    && rm -rf /var/cache/apk/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Final stage - minimal runtime image
FROM python:3.11-alpine AS runtime

# Install runtime dependencies only
RUN apk add --no-cache \
    libffi \
    openssl \
    && rm -rf /var/cache/apk/*

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Create non-root user for security
RUN addgroup -g 1000 dtn && \
    adduser -D -s /bin/sh -u 1000 -G dtn dtn

# Set working directory
WORKDIR /app

# Copy application files
COPY --chown=dtn:dtn server.py .
COPY --chown=dtn:dtn processor_gpt_o3.py .
COPY --chown=dtn:dtn config.yaml .

# Switch to non-root user
USER dtn

# Expose port
EXPOSE 8026

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8026/health', timeout=5)" || exit 1

# Run the server
CMD ["python", "server.py"] 