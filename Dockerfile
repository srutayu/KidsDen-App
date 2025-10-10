# Multi-stage Docker build for both backend services
FROM node:18-alpine as base

# Install necessary packages including supervisor for process management
RUN apk add --no-cache supervisor curl netcat-openbsd

# Set working directory
WORKDIR /app

# Create application directory structure
RUN mkdir -p /app/backend /app/chatbackend /app/logs

# Copy package.json files first for better Docker layer caching
COPY backend/package*.json /app/backend/
COPY chatbackend/package*.json /app/chatbackend/

# Install dependencies for both applications
WORKDIR /app/backend
RUN npm ci --only=production

WORKDIR /app/chatbackend  
RUN npm ci --only=production

# Copy application source code
WORKDIR /app
COPY backend/ /app/backend/
COPY chatbackend/ /app/chatbackend/

# Copy startup script and supervisor configuration
COPY start.sh /app/start.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Fix line endings and make startup script executable
RUN sed -i 's/\r$//' /app/start.sh && chmod +x /app/start.sh

# Create non-root user for security
RUN addgroup -S appuser && \
    adduser -D -s /bin/sh -G appuser appuser && \
    mkdir -p /var/log/supervisor /app/logs && \
    chown -R appuser:appuser /app && \
    chown -R appuser:appuser /var/log/supervisor && \
    chmod -R 755 /app/logs

# Switch to non-root user
USER appuser

# Expose ports for both services
EXPOSE 3000 8000

# Health check to ensure both services are running
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || curl -f http://localhost:8000/health || exit 1

# Use supervisor to manage both processes
ENTRYPOINT ["/bin/sh", "/app/start.sh"]