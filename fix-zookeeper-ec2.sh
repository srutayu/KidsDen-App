#!/bin/bash

# Quick ZooKeeper Fix Deployment Commands for EC2
# Run these commands on your EC2 instance to apply the fixes

set -e

echo "🔧 Quick ZooKeeper Fix for t2.medium EC2"
echo "========================================"

# Function to check if we're on EC2
check_ec2_environment() {
    if curl -s --connect-timeout 3 http://169.254.169.254/latest/meta-data/instance-type >/dev/null 2>&1; then
        INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
        echo "✅ Running on EC2 instance: $INSTANCE_TYPE"
        return 0
    else
        echo "⚠️  Not running on EC2 or metadata service unavailable"
        return 1
    fi
}

# Function to apply immediate fixes
apply_immediate_fixes() {
    echo ""
    echo "🚀 Applying immediate ZooKeeper fixes..."
    
    # Navigate to project directory
    cd /home/$(whoami)/kidsden-backend || {
        echo "❌ Project directory not found. Please run the full deployment script first."
        exit 1
    }
    
    # Pull latest changes with the fixes
    echo "📥 Pulling latest configuration changes..."
    git pull origin main || {
        echo "❌ Git pull failed. Applying fixes manually..."
        return 1
    }
    
    # Stop current containers
    echo "🛑 Stopping current containers..."
    docker-compose down || sudo docker-compose down
    
    # Clean up to ensure fresh start
    echo "🧹 Cleaning Docker system..."
    docker system prune -f || sudo docker system prune -f
    
    # Start with new configuration
    echo "🚀 Starting with optimized ZooKeeper configuration..."
    docker-compose up -d || sudo docker-compose up -d
    
    # Wait for services to start
    echo "⏳ Waiting for services to start (60 seconds)..."
    sleep 60
}

# Function to verify the fixes
verify_fixes() {
    echo ""
    echo "🔍 Verifying ZooKeeper fixes..."
    
    # Check if ZooKeeper container is running
    if docker ps --filter "name=kidsden-zookeeper" --format "{{.Names}}" | grep -q kidsden-zookeeper; then
        echo "✅ ZooKeeper container is running"
        
        # Check memory allocation
        echo "💾 ZooKeeper memory usage:"
        docker stats kidsden-zookeeper --no-stream --format "{{.Container}}: {{.MemUsage}} ({{.MemPerc}})" || echo "Could not get stats"
        
        # Test connectivity
        echo "🔗 Testing ZooKeeper connectivity..."
        if timeout 10 bash -c 'echo ruok | nc localhost 2181' 2>/dev/null | grep -q imok; then
            echo "✅ ZooKeeper is responding correctly"
            
            # Show ZooKeeper configuration
            echo "⚙️  ZooKeeper status:"
            timeout 10 bash -c 'echo stat | nc localhost 2181' 2>/dev/null | head -10 || echo "Could not get status"
        else
            echo "❌ ZooKeeper not responding"
            echo "📋 Recent logs:"
            docker logs kidsden-zookeeper --tail 20
            return 1
        fi
    else
        echo "❌ ZooKeeper container not running"
        echo "📋 Docker containers status:"
        docker ps -a --filter "name=kidsden"
        return 1
    fi
    
    # Check Kafka if it's running
    if docker ps --filter "name=kidsden-kafka" --format "{{.Names}}" | grep -q kidsden-kafka; then
        echo "✅ Kafka container is running"
        
        # Test Kafka-ZooKeeper connection
        echo "🔗 Testing Kafka-ZooKeeper connection..."
        if docker exec kidsden-kafka timeout 10 kafka-topics --bootstrap-server localhost:9092 --list >/dev/null 2>&1; then
            echo "✅ Kafka successfully connected to ZooKeeper"
        else
            echo "❌ Kafka cannot connect to ZooKeeper"
            echo "📋 Kafka logs:"
            docker logs kidsden-kafka --tail 10
        fi
    fi
}

# Function to show resource usage
show_resources() {
    echo ""
    echo "📊 System Resources After Fix:"
    echo "=============================="
    
    echo "💾 Memory usage:"
    free -h
    
    echo ""
    echo "🐳 Docker container resources:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" || echo "Could not get Docker stats"
}

# Function to show next steps
show_next_steps() {
    echo ""
    echo "🎯 Summary of Applied Fixes:"
    echo "============================"
    echo "✅ Increased ZooKeeper heap from 128MB to 1GB"
    echo "✅ Updated container memory limit from 256MB to 1.5GB"
    echo "✅ Optimized ZooKeeper configuration for t2.medium"
    echo "✅ Added auto-purge settings to manage disk usage"
    echo "✅ Increased tick time to 3000ms for better stability"
    
    echo ""
    echo "📋 Verification Commands:"
    echo "========================"
    echo "Check ZooKeeper status:     echo stat | nc localhost 2181"
    echo "Test ZooKeeper health:      echo ruok | nc localhost 2181"
    echo "Monitor container memory:   docker stats kidsden-zookeeper"
    echo "View ZooKeeper logs:        docker logs kidsden-zookeeper"
    echo "Run verification script:    ./verify-zookeeper.sh"
    
    echo ""
    echo "🔧 If Issues Persist:"
    echo "====================="
    echo "1. Check security groups allow port 2181"
    echo "2. Ensure sufficient disk space: df -h"
    echo "3. Monitor system memory: free -h"
    echo "4. Check for other memory-hungry processes: top"
    echo "5. Consider upgrading to t3.medium for better performance"
}

# Main execution
main() {
    check_ec2_environment
    apply_immediate_fixes
    verify_fixes
    show_resources
    show_next_steps
    
    echo ""
    echo "🎉 ZooKeeper optimization complete!"
    echo "Your ZooKeeper should now be properly configured for t2.medium instance."
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Running as root. Consider running as regular user with Docker permissions."
fi

# Run the script
main "$@"