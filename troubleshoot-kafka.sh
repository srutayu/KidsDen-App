#!/bin/bash

# Kafka Troubleshooting Script for EC2
# Use this script to diagnose Kafka issues

echo "🔍 Kafka Troubleshooting Script"
echo "================================"

# Function to check service status
check_service_status() {
    local service=$1
    echo "📊 Checking $service status:"
    
    if docker ps --filter "name=$service" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -v NAMES; then
        echo "✅ $service container is running"
        return 0
    else
        echo "❌ $service container is not running"
        return 1
    fi
}

# Function to check resource usage
check_resources() {
    echo ""
    echo "💾 System Resources:"
    echo "===================="
    
    # Memory usage
    echo "🧠 Memory Usage:"
    free -h
    
    # CPU usage
    echo ""
    echo "⚡ CPU Usage:"
    top -bn1 | head -5
    
    # Disk usage
    echo ""
    echo "💿 Disk Usage:"
    df -h / /var/lib/docker 2>/dev/null || df -h /
    
    # Docker system usage
    echo ""
    echo "🐳 Docker System Usage:"
    docker system df 2>/dev/null || echo "Docker not accessible"
}

# Function to check container resources
check_container_resources() {
    local container=$1
    echo ""
    echo "📊 Container Resources - $container:"
    echo "===================================="
    
    if docker stats "$container" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null; then
        echo "✅ Resource stats retrieved"
    else
        echo "❌ Cannot get resource stats for $container"
    fi
}

# Function to check logs
check_logs() {
    local container=$1
    local lines=${2:-50}
    
    echo ""
    echo "📜 Last $lines lines from $container logs:"
    echo "=========================================="
    
    if docker logs --tail "$lines" "$container" 2>/dev/null; then
        echo "✅ Logs retrieved"
    else
        echo "❌ Cannot get logs for $container"
    fi
}

# Function to test Kafka connectivity
test_kafka_connectivity() {
    echo ""
    echo "🔗 Testing Kafka Connectivity:"
    echo "==============================="
    
    # Test from host
    if command -v nc >/dev/null 2>&1; then
        if nc -z localhost 9092; then
            echo "✅ Kafka port 9092 is accessible from host"
        else
            echo "❌ Cannot connect to Kafka port 9092 from host"
        fi
    fi
    
    # Test from inside container
    if docker exec -it kidsden-kafka kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null; then
        echo "✅ Kafka is responsive inside container"
    else
        echo "❌ Kafka is not responsive inside container"
    fi
    
    # Test Zookeeper connection
    if docker exec -it kidsden-zookeeper bash -c "echo ruok | nc localhost 2181" 2>/dev/null; then
        echo "✅ Zookeeper is responsive"
    else
        echo "❌ Zookeeper is not responsive"
    fi
}

# Function to show Kafka configuration
show_kafka_config() {
    echo ""
    echo "⚙️  Kafka Configuration:"
    echo "========================"
    
    echo "Environment variables:"
    docker exec -it kidsden-kafka env | grep KAFKA_ | head -20 2>/dev/null || echo "Cannot access Kafka container"
}

# Main execution
echo "🕐 $(date)"
echo ""

# Check system resources first
check_resources

# Check service statuses
echo ""
echo "🔍 Service Status Check:"
echo "========================"

check_service_status "kidsden-zookeeper"
check_service_status "kidsden-kafka"
check_service_status "kidsden-app"

# Check container resource usage
check_container_resources "kidsden-zookeeper"
check_container_resources "kidsden-kafka"

# Test connectivity
test_kafka_connectivity

# Show configuration
show_kafka_config

# Check recent logs
echo ""
echo "📋 Recent Container Events:"
echo "=========================="
docker events --since 5m --until now 2>/dev/null | grep -E "(kidsden-kafka|kidsden-zookeeper)" | tail -10 || echo "No recent events"

# Check logs
check_logs "kidsden-zookeeper" 20
check_logs "kidsden-kafka" 30

# Recommendations
echo ""
echo "💡 Troubleshooting Recommendations:"
echo "==================================="
echo ""

# Check if containers are restarting
if docker ps -a --filter "name=kidsden-kafka" --format "{{.Status}}" | grep -q "Restarting"; then
    echo "🔄 Kafka is restarting repeatedly - likely resource issues:"
    echo "   1. Check memory usage above - Kafka needs at least 512MB free"
    echo "   2. Consider using docker-compose.ec2-minimal.yml instead"
    echo "   3. Upgrade to a larger EC2 instance type"
    echo "   4. Run: docker-compose -f docker-compose.ec2-minimal.yml up -d"
    echo ""
fi

# Check memory pressure
MEM_AVAILABLE=$(free -m | awk 'NR==2{printf "%.0f", $7}')
if [ "$MEM_AVAILABLE" -lt 512 ]; then
    echo "⚠️  Low memory detected (${MEM_AVAILABLE}MB available):"
    echo "   1. Kafka requires significant memory to run stable"
    echo "   2. Consider disabling Kafka: export KAFKA_DISABLED=true"
    echo "   3. Use minimal deployment: docker-compose -f docker-compose.ec2-minimal.yml up -d"
    echo "   4. Upgrade instance to have at least 2GB RAM"
    echo ""
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "💿 High disk usage detected (${DISK_USAGE}%):"
    echo "   1. Clean up Docker: docker system prune -a"
    echo "   2. Clean up logs: docker logs kidsden-kafka | tail -100 > /tmp/kafka.log"
    echo "   3. Reduce Kafka log retention in docker-compose.yml"
    echo ""
fi

echo "🔧 Useful Commands:"
echo "=================="
echo "  Restart Kafka:       docker-compose restart kafka"
echo "  Use minimal setup:    docker-compose -f docker-compose.ec2-minimal.yml up -d"
echo "  View live logs:       docker logs -f kidsden-kafka"
echo "  Check health:         docker exec kidsden-kafka kafka-topics --bootstrap-server localhost:9092 --list"
echo "  Clean system:         docker system prune -f"
echo "  Check processes:      docker exec kidsden-app supervisorctl status"
echo ""

# Final status
if check_service_status "kidsden-kafka" >/dev/null 2>&1; then
    echo "✅ Kafka appears to be running. If issues persist, consider the minimal setup."
else
    echo "❌ Kafka is not running. Recommend using docker-compose.ec2-minimal.yml for this instance."
fi

echo ""
echo "📧 If problems persist, the minimal configuration runs without Kafka:"
echo "    docker-compose down"
echo "    docker-compose -f docker-compose.ec2-minimal.yml up -d"