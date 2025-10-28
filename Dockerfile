# Multi-stage Docker build for both backend services
FROM node:18-bullseye-slim as base

# Install necessary packages including supervisor for process management and Chromium
# Use Debian slim image for better Chromium compatibility in containers (Alpine often lacks required glibc/libs).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
   supervisor \
   curl \
   netcat-openbsd \
   chromium \
   ca-certificates \
   fonts-liberation \
   libnss3 \
   libatk1.0-0 \
   libatk-bridge2.0-0 \
   libc6 \
   libcairo2 \
   libcups2 \
   libdbus-1-3 \
   libexpat1 \
   libfontconfig1 \
   libgcc1 \
   libgconf-2-4 \
   libgdk-pixbuf2.0-0 \
   libglib2.0-0 \
   libgtk-3-0 \
   libnspr4 \
   libpango-1.0-0 \
   libpangocairo-1.0-0 \
   libstdc++6 \
   libx11-6 \
   libx11-xcb1 \
   libxcb1 \
   libxcomposite1 \
   libxcursor1 \
   libxdamage1 \
   libxext6 \
   libxfixes3 \
   libxi6 \
   libxrandr2 \
   libxrender1 \
   libxss1 \
   libxtst6 \
   xdg-utils \
 && rm -rf /var/lib/apt/lists/*

# Explicitly set a known chromium path environment variable used by the app
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

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

# Create non-root user for security (Debian-friendly)
# Use groupadd/useradd instead of Alpine addgroup/adduser
RUN groupadd -r appuser \
 && useradd -r -g appuser -s /bin/sh appuser \
 && mkdir -p /var/log/supervisor /app/logs \
 && chown -R appuser:appuser /app /var/log/supervisor \
 && chmod -R 777 /app/logs

# Switch to non-root user
USER appuser

# Expose ports for both services
EXPOSE 3000 8000

# Health check to ensure both services are running
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || curl -f http://localhost:8000/health || exit 1

# Use supervisor to manage both processes
ENTRYPOINT ["/bin/sh", "/app/start.sh"]