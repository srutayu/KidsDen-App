#!/bin/sh

# Startup script for combined backend services
# This script handles both local development and EC2 deployment

set -e

echo "===> Starting KidsDen Backend Services"
echo "===> User: $(whoami)"
echo "===> Current directory: $(pwd)"

# Function to wait for services to be ready
wait_for_service() {
    local host=$1
    local port=$2
    local service_name=$3
    local max_attempts=30
    local attempt=1

    echo "===> Waiting for $service_name to be available at $host:$port..."
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            echo "===> $service_name is ready!"
            return 0
        fi
        
        echo "===> Attempt $attempt/$max_attempts: $service_name not ready, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "===> Warning: $service_name not available after $max_attempts attempts"
    return 1
}

# Detect environment (local vs EC2)
if [ "${NODE_ENV}" = "production" ] || [ "${ENVIRONMENT}" = "ec2" ]; then
    echo "===> Running in production/EC2 environment"
    
    # In production, wait for external services
    wait_for_service "${MONGO_HOST:-mongodb}" "${MONGO_PORT:-27017}" "MongoDB"
    wait_for_service "${REDIS_HOST:-redis}" "${REDIS_PORT:-6379}" "Redis" 
    if ! wait_for_service "${KAFKA_HOST:-kafka}" "${KAFKA_PORT:-9092}" "Kafka"; then
        echo "===> Kafka not available, enabling fallback mode..."
        export KAFKA_DISABLED=true
    fi
else
    echo "===> Running in development environment"
    
    # In development, services might be on localhost
    MONGO_HOST=${MONGO_HOST:-localhost}
    REDIS_HOST=${REDIS_HOST:-localhost}
    KAFKA_HOST=${KAFKA_HOST:-localhost}
    
    echo "===> Using localhost for services"
    
    # Try Kafka, but don't fail if it's not available
    if ! wait_for_service "${KAFKA_HOST}" "${KAFKA_PORT:-9092}" "Kafka"; then
        echo "===> Kafka not available in development, enabling fallback mode..."
        export KAFKA_DISABLED=true
    fi
fi

# Set environment variables for both services
export NODE_ENV=${NODE_ENV:-development}
export BACKEND_PORT=${BACKEND_PORT:-3000}
export CHATBACKEND_PORT=${CHATBACKEND_PORT:-8000}

# Create log directories and ensure proper permissions
mkdir -p /app/logs
# Fix permissions in case of volume mount
chmod 755 /app/logs 2>/dev/null || true
# Ensure we can write to the logs directory
touch /app/logs/test.log 2>/dev/null && rm -f /app/logs/test.log || {
    echo "===> Warning: Cannot write to /app/logs directory"
    echo "===> This may be due to volume mount permissions"
    # Create alternative log directory
    mkdir -p /tmp/kidsden-logs
    export LOG_DIR="/tmp/kidsden-logs"
}

echo "===> Environment Configuration:"
echo "     NODE_ENV: $NODE_ENV"
echo "     Backend Port: $BACKEND_PORT"
echo "     Chat Backend Port: $CHATBACKEND_PORT"
echo "     MongoDB: ${MONGO_HOST:-mongodb}:${MONGO_PORT:-27017}"
echo "     Redis: ${REDIS_HOST:-redis}:${REDIS_PORT:-6379}"
echo "     Kafka: ${KAFKA_HOST:-kafka}:${KAFKA_PORT:-9092}"

if [ "$KAFKA_DISABLED" = "true" ]; then
    echo "     Kafka: DISABLED (fallback mode active)"
    echo ""
    echo "===> ⚠️  NOTICE: Kafka is disabled. Chat message persistence will use direct DB writes."
    echo "===> This reduces performance but ensures service availability."
else
    echo "     Kafka: ENABLED"
fi

echo "===> Starting supervisor to manage both services..."

# Start supervisor which will manage both Node.js processes
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf