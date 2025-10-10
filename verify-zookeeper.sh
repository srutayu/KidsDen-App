#!/bin/bash

# ZooKeeper Verification Script for t2.medium EC2
# This script verifies ZooKeeper is running properly with the new configuration

set -e

echo "🔍 ZooKeeper Verification Script"
echo "================================"

# Function to check if ZooKeeper container is running
check_zookeeper_container() {
    echo "📊 Checking ZooKeeper container status..."
    
    if docker ps --filter "name=kidsden-zookeeper" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -v NAMES; then
        echo "✅ ZooKeeper container is running"
        return 0
    else
        echo "❌ ZooKeeper container is not running"
        return 1
    fi
}

# Function to check ZooKeeper connectivity
check_zookeeper_connectivity() {
    echo ""
    echo "🔗 Testing ZooKeeper connectivity..."
    
    # Test ruok command
    if timeout 10 bash -c 'echo ruok | nc localhost 2181' 2>/dev/null | grep -q imok; then
        echo "✅ ZooKeeper is responding to ruok command"
    else
        echo "❌ ZooKeeper is not responding to ruok command"
        return 1
    fi
    
    # Test stat command
    echo ""
    echo "📈 ZooKeeper status:"
    timeout 10 bash -c 'echo stat | nc localhost 2181' 2>/dev/null || echo "❌ Could not get ZooKeeper stats"
}

# Function to check ZooKeeper memory usage
check_zookeeper_memory() {
    echo ""
    echo "💾 ZooKeeper memory usage:"
    
    # Get container memory stats
    docker stats kidsden-zookeeper --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null || echo "❌ Could not get memory stats"
    
    # Get JVM heap info from ZooKeeper
    echo ""
    echo "☕ JVM Heap Information:"
    timeout 10 bash -c 'echo mntr | nc localhost 2181' 2>/dev/null | grep -E "(heap|memory)" || echo "❌ Could not get JVM heap info"
}

# Function to check ZooKeeper logs
check_zookeeper_logs() {
    echo ""
    echo "📋 Recent ZooKeeper logs (last 20 lines):"
    docker logs kidsden-zookeeper --tail 20 2>/dev/null || echo "❌ Could not get ZooKeeper logs"
}

# Function to test Kafka connection to ZooKeeper
test_kafka_zookeeper_connection() {
    echo ""
    echo "🔗 Testing Kafka-ZooKeeper connection..."
    
    if docker ps --filter "name=kidsden-kafka" --format "{{.Names}}" | grep -q kidsden-kafka; then
        echo "📊 Kafka container is running, checking connection..."
        
        # Try to list topics (this tests ZooKeeper connection)
        if docker exec kidsden-kafka timeout 10 kafka-topics --bootstrap-server localhost:9092 --list >/dev/null 2>&1; then
            echo "✅ Kafka can connect to ZooKeeper successfully"
        else
            echo "❌ Kafka cannot connect to ZooKeeper"
        fi
    else
        echo "⚠️  Kafka container is not running - cannot test connection"
    fi
}

# Function to display system resources
show_system_resources() {
    echo ""
    echo "🖥️  System Resources (t2.medium check):"
    echo "========================================"
    
    echo "💾 Memory Usage:"
    free -h
    
    echo ""
    echo "⚡ CPU Usage:"
    top -bn1 | head -5
    
    echo ""
    echo "💿 Disk Usage:"
    df -h / 2>/dev/null
    
    echo ""
    echo "🐳 Docker System Info:"
    docker system df 2>/dev/null || echo "Could not get Docker system info"
}

# Main execution
main() {
    echo "Starting ZooKeeper verification for t2.medium EC2 instance..."
    echo ""
    
    # Run all checks
    check_zookeeper_container
    check_zookeeper_connectivity
    check_zookeeper_memory
    test_kafka_zookeeper_connection
    check_zookeeper_logs
    show_system_resources
    
    echo ""
    echo "🎯 Verification Summary:"
    echo "======================="
    echo "If all checks passed, ZooKeeper is properly configured for your t2.medium instance."
    echo "If any checks failed, review the output above for troubleshooting guidance."
    echo ""
    echo "💡 Tips for t2.medium optimization:"
    echo "- ZooKeeper should now use up to 1GB heap (was 128MB)"
    echo "- Container memory limit increased to 1.5GB (was 256MB)"
    echo "- Tick time increased to 3000ms for better performance"
    echo "- Auto-purge enabled to manage disk usage"
}

# Run the script
main "$@"