#!/bin/bash

# KidsDen Backend Deployment Script for EC2
# This script sets up and deploys the KidsDen backend services on an EC2 instance

set -e

echo "🚀 KidsDen Backend Deployment Script"
echo "==================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Docker permissions
check_docker_permissions() {
    if docker ps >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to fix Docker permissions
fix_docker_permissions() {
    echo "🔧 Fixing Docker permissions..."
    
    # Ensure Docker service is running
    sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null
    
    # Add user to docker group if not already added
    if ! groups $USER | grep -q docker; then
        echo "📝 Adding user $USER to docker group..."
        sudo usermod -a -G docker $USER
    fi
    
    # Try to refresh group membership
    echo "🔄 Refreshing group membership..."
    if command_exists newgrp; then
        newgrp docker << EOF
echo "Group membership refreshed"
EOF
    fi
    
    # Alternative: set socket permissions (less secure but works)
    if ! check_docker_permissions; then
        echo "⚠️  Applying temporary socket permissions..."
        sudo chmod 666 /var/run/docker.sock
    fi
}

# Function to install Docker on Amazon Linux 2
install_docker() {
    echo "📦 Installing Docker..."
    sudo yum update -y
    sudo yum install -y docker git
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -a -G docker $USER
    echo "✅ Docker installed successfully"
    echo "⚠️  Please run 'newgrp docker' or log out and back in to refresh permissions"
}

# Function to install Docker Compose
install_docker_compose() {
    echo "📦 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed successfully"
}

# Function to run docker-compose with proper permissions
run_docker_compose() {
    if check_docker_permissions; then
        docker-compose "$@"
    else
        echo "🔧 Running with sudo due to permission issues..."
        sudo docker-compose "$@"
    fi
}

# Check and install dependencies
echo "🔍 Checking dependencies..."

if ! command_exists docker; then
    install_docker
    fix_docker_permissions
    
    # Check if Docker is working now
    if ! check_docker_permissions; then
        echo "❌ Docker permissions still not working. Please run:"
        echo "   newgrp docker"
        echo "   Or log out and back in, then run this script again"
        exit 1
    fi
else
    echo "✅ Docker is already installed"
    
    # Check Docker permissions
    if ! check_docker_permissions; then
        echo "⚠️  Docker permission issue detected"
        fix_docker_permissions
        
        # Final check
        if ! check_docker_permissions; then
            echo "❌ Docker permissions could not be fixed automatically."
            echo "💡 Please run one of these commands and try again:"
            echo "   sudo chmod 666 /var/run/docker.sock"
            echo "   newgrp docker"
            echo "   Or log out and back in"
            exit 1
        fi
    fi
fi

if ! command_exists docker-compose; then
    install_docker_compose
else
    echo "✅ Docker Compose is already installed"
fi

if ! command_exists git; then
    echo "📦 Installing Git..."
    sudo yum install -y git
    echo "✅ Git installed successfully"
else
    echo "✅ Git is already installed"
fi

# Environment setup
echo ""
echo "🔧 Environment Configuration"
echo "==========================="

# Check if environment variables are set
if [ -z "$JWT_SECRET" ]; then
    echo "⚠️  JWT_SECRET not set. Using default (change in production!)"
    export JWT_SECRET="change-this-super-secure-jwt-secret-in-production"
fi

if [ -z "$RAZORPAY_KEY_ID" ]; then
    echo "⚠️  RAZORPAY_KEY_ID not set. Payment functionality will not work."
    export RAZORPAY_KEY_ID="your_razorpay_key_id"
fi

if [ -z "$RAZORPAY_KEY_SECRET" ]; then
    echo "⚠️  RAZORPAY_KEY_SECRET not set. Payment functionality will not work."
    export RAZORPAY_KEY_SECRET="your_razorpay_key_secret"
fi

# Set production environment
export NODE_ENV="production"
export ENVIRONMENT="ec2"

echo "Environment variables configured:"
echo "  NODE_ENV: $NODE_ENV"
echo "  ENVIRONMENT: $ENVIRONMENT"
echo "  JWT_SECRET: ${JWT_SECRET:0:10}... (truncated)"

# Application deployment
echo ""
echo "🚢 Deploying Application"
echo "======================"

# Create application directory
APP_DIR="/home/$(whoami)/kidsden-backend"

if [ -d "$APP_DIR" ]; then
    echo "📂 Updating existing deployment..."
    cd "$APP_DIR"
    git pull origin docker/EC2-Container || {
        echo "❌ Git pull failed. Please check repository access."
        exit 1
    }
else
    echo "📂 Cloning repository..."
    git clone https://github.com/deanurag/kidsden-backend.git "$APP_DIR" || {
        echo "❌ Git clone failed. Please check repository URL and access."
        echo "💡 If repository is private, set up SSH keys or use HTTPS with token"
        exit 1
    }
    cd "$APP_DIR"
    git checkout docker/EC2-Container
fi

# Create logs directory
mkdir -p logs

# Check available memory and CPU
MEMORY_GB=$(free -g | awk 'NR==2{printf "%.0f", $2}')
CPU_CORES=$(nproc)
echo "💾 Available memory: ${MEMORY_GB}GB"
echo "🔧 CPU cores: ${CPU_CORES}"

# Check instance type and decide on Kafka
INSTANCE_TYPE=""
if command -v curl >/dev/null 2>&1; then
    INSTANCE_TYPE=$(curl -s --connect-timeout 3 http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo "unknown")
    echo "🏷️  Instance type: $INSTANCE_TYPE"
fi

# Determine if we should use Kafka based on resources
USE_KAFKA=false

# Enable Kafka only on larger instances with sufficient resources
if [ "$MEMORY_GB" -ge 4 ] && [ "$CPU_CORES" -ge 2 ]; then
    # Check if instance type is suitable for Kafka
    case "$INSTANCE_TYPE" in
        t2.medium|t2.large|t2.xlarge|t3.medium|t3.large|t3.xlarge|m5.*|c5.*|r5.*)
            USE_KAFKA=true
            echo "✅ Sufficient resources detected. Enabling Kafka..."
            ;;
        *)
            echo "⚠️  Instance type not optimal for Kafka. Using minimal configuration..."
            ;;
    esac
else
    echo "⚠️  Limited resources detected (need 4GB+ RAM and 2+ CPU cores for Kafka)..."
fi

# Choose appropriate compose file
if [ "$USE_KAFKA" = "true" ]; then
    COMPOSE_FILE="docker-compose.yml"
    echo "📦 Using full configuration with optimized Kafka"
else
    COMPOSE_FILE="docker-compose.ec2-minimal.yml"
    echo "📦 Using minimal configuration (without Kafka)"
fi

# Stop existing containers
echo "🛑 Stopping existing containers..."
run_docker_compose -f "$COMPOSE_FILE" down 2>/dev/null || true

# Remove old images to ensure fresh deployment
echo "🧹 Cleaning up old images..."
docker system prune -f

# Build and start services
echo "🏗️  Building application..."
run_docker_compose -f "$COMPOSE_FILE" build app

echo "🚀 Starting services..."
run_docker_compose -f "$COMPOSE_FILE" up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Health check
echo ""
echo "🔍 Health Check"
echo "============="

check_service() {
    local service_name=$1
    local url=$2
    local max_attempts=10
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$url" >/dev/null 2>&1; then
            echo "✅ $service_name is healthy"
            return 0
        fi
        
        echo "⏳ Attempt $attempt/$max_attempts: $service_name not ready..."
        sleep 3
        attempt=$((attempt + 1))
    done
    
    echo "❌ $service_name health check failed"
    return 1
}

# Check infrastructure services first (if Kafka is enabled)
if [ "$USE_KAFKA" = "true" ]; then
    echo "🔍 Verifying ZooKeeper configuration..."
    
    # Check if ZooKeeper is running
    if docker ps --filter "name=kidsden-zookeeper" --format "{{.Names}}" | grep -q kidsden-zookeeper; then
        echo "✅ ZooKeeper container is running"
        
        # Wait a bit more for ZooKeeper to fully initialize
        echo "⏳ Waiting for ZooKeeper to initialize (30s)..."
        sleep 30
        
        # Test ZooKeeper connectivity
        if timeout 10 bash -c 'echo ruok | nc localhost 2181' 2>/dev/null | grep -q imok; then
            echo "✅ ZooKeeper is responding correctly"
            
            # Display ZooKeeper memory usage
            echo "💾 ZooKeeper memory usage:"
            docker stats kidsden-zookeeper --no-stream --format "{{.Container}}: {{.MemUsage}}" 2>/dev/null || echo "Could not get memory stats"
        else
            echo "⚠️  ZooKeeper not responding - checking logs:"
            docker logs kidsden-zookeeper --tail 10
        fi
    else
        echo "❌ ZooKeeper container not found"
    fi
    
    # Check Kafka
    if docker ps --filter "name=kidsden-kafka" --format "{{.Names}}" | grep -q kidsden-kafka; then
        echo "✅ Kafka container is running"
    else
        echo "❌ Kafka container not found"
    fi
fi

# Check application services
check_service "Backend API" "http://localhost:3000/health"
check_service "Chat Backend" "http://localhost:8000/health"

# Display status
echo ""
echo "📊 Deployment Status"
echo "=================="
run_docker_compose -f "$COMPOSE_FILE" ps

echo ""
echo "📋 Service Information"
echo "===================="
PUBLIC_IP=$(curl -s --connect-timeout 3 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
echo "🌐 Backend API:      http://$PUBLIC_IP:3000"
echo "💬 Chat Backend:     http://$PUBLIC_IP:8000"
echo "🔍 Health Check API: http://$PUBLIC_IP:3000/health"
echo "🔍 Health Check Chat:http://$PUBLIC_IP:8000/health"

echo ""
echo "📝 Next Steps"
echo "============"
echo "1. Configure your security groups to allow traffic on ports 3000 and 8000"
echo "2. Set up SSL/TLS certificates for production (recommended)"
echo "3. Configure DNS to point to your EC2 public IP: $PUBLIC_IP"
echo "4. Set proper environment variables for production:"
echo "   export JWT_SECRET=\"your-actual-jwt-secret\""
echo "   export RAZORPAY_KEY_ID=\"your-actual-key\""
echo "   export RAZORPAY_KEY_SECRET=\"your-actual-secret\""
echo "5. Monitor logs: docker-compose -f $COMPOSE_FILE logs -f app"

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📚 Useful Commands:"
echo "  View logs:           docker-compose -f $COMPOSE_FILE logs -f app"
echo "  Check status:        docker-compose -f $COMPOSE_FILE ps"
echo "  Restart services:    docker-compose -f $COMPOSE_FILE restart app"
echo "  Update deployment:   git pull && docker-compose -f $COMPOSE_FILE build app && docker-compose -f $COMPOSE_FILE up -d"
echo "  Stop services:       docker-compose -f $COMPOSE_FILE down"
echo ""
echo "🔧 Troubleshooting:"
echo "  Check app logs:      docker logs kidsden-app"
echo "  Enter container:     docker exec -it kidsden-app sh"
echo "  Check processes:     docker exec -it kidsden-app supervisorctl status"
echo ""
echo "Configuration used: $COMPOSE_FILE"
if [ "$USE_KAFKA" = "false" ]; then
    echo ""
    echo "ℹ️  Note: Kafka is disabled on this instance due to resource constraints."
    echo "   Chat messages will be saved directly to the database."
    echo "   For better performance, consider upgrading to a larger instance type."
fi