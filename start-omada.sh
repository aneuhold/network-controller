#!/bin/bash

echo "============================================="
echo "TP-Link Omada Controller - Simple Startup"
echo "============================================="

# Setup environment
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export LD_LIBRARY_PATH=/usr/lib/jvm/java-17-openjdk-amd64/lib/server:$LD_LIBRARY_PATH

# JVM performance options
export JAVA_OPTS="-Xms1024m -Xmx4096m -XX:MaxMetaspaceSize=512m -XX:+UseG1GC -XX:ParallelGCThreads=4"

# Create directories
mkdir -p /data/db /var/log/mongodb /opt/tplink
mkdir -p /opt/tplink/EAPController/{data,logs,work}
chmod -R 755 /data/db /var/log/mongodb

# Make JVM discoverable
mkdir -p /usr/lib/jvm/java-17-openjdk-amd64/jre/lib/amd64/server/
[ ! -f "/usr/lib/jvm/java-17-openjdk-amd64/jre/lib/amd64/server/libjvm.so" ] && \
  cp -f /usr/lib/jvm/java-17-openjdk-amd64/lib/server/libjvm.so /usr/lib/jvm/java-17-openjdk-amd64/jre/lib/amd64/server/

# Start MongoDB directly (don't rely on service)
echo "● Starting MongoDB..."
mongod --fork --logpath /var/log/mongodb/mongod.log || {
  echo "Failed to start MongoDB. Trying to recover..."
  pkill -f mongod
  rm -f /var/lib/mongodb/mongod.lock /tmp/mongodb-*.sock
  sleep 2
  mongod --fork --logpath /var/log/mongodb/mongod.log
}

echo "● Installing Omada Controller..."
if [ ! -f "/usr/bin/tpeap" ]; then
  # Using this simple approach to avoid installer hanging
  dpkg --unpack /tmp/omada-controller.deb
  
  # Fix the postinst script to not start the service
  if [ -f "/var/lib/dpkg/info/omadac.postinst" ]; then
    sed -i 's|^.*systemctl.*$|echo "Skipping automatic start"|g' /var/lib/dpkg/info/omadac.postinst
    sed -i 's|^.*tpeap start.*$|echo "Skipping automatic start"|g' /var/lib/dpkg/info/omadac.postinst
  fi
  
  # Configure the package without starting
  dpkg --configure omadac
else
  echo "Controller already installed."
fi

# Display network ports in use
echo "✅ Checking network ports..."
netstat -tulpn | grep -E '8088|8043|8843|29810|29811|29812|29813|29814' || echo "No controller ports detected yet - may still be starting up"

# Check for Java processes
echo "✅ Checking for running Java processes..."
ps aux | grep java | grep -v grep || echo "No Java processes running - controller may have failed to start"

# Check MongoDB connection
echo "✅ Checking MongoDB status..."
if command -v mongod &> /dev/null; then
    ps aux | grep mongod | grep -v grep || echo "MongoDB not running - this could be an issue"
fi

# Display useful logs
echo "✅ Recent logs (if available):"
tail -n 20 /opt/tplink/EAPController/logs/server.log 2>/dev/null || echo "No server logs available yet"

# Final status check
echo "✅ Omada Controller setup complete! The web interface should be available shortly at:"
echo "   - HTTP:  http://localhost:8088"
echo "   - HTTPS: https://localhost:8043"
echo "============================================="
echo "NOTE: The controller may take up to 2-3 minutes to fully initialize on first startup"
echo "If it doesn't start, check the logs using ./logs.sh"
echo "============================================="

# Keep the container running
tail -f /dev/null