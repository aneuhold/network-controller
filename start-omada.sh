#!/bin/bash

# Make sure Java 17 is selected
echo "Checking Java version..."
java -version

# Find the actual Java home path
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
echo "Detected Java Home: $JAVA_HOME"

# Skip starting MongoDB externally - let the Omada Controller manage its own MongoDB
echo "Skipping external MongoDB startup - Controller will manage its own database"
# Create necessary directories that the controller might need
mkdir -p /data/db /var/log/mongodb

# Start Omada Controller with explicit Java home and JVM path
echo "Starting Omada Controller..."
cd /opt/tp-link/omada-controller

# Find the actual JVM path
export JAVA_HOME=$JAVA_HOME
JVM_PATH=$(find $JAVA_HOME -name libjvm.so | head -1)
if [ -n "$JVM_PATH" ]; then
    JVM_DIR=$(dirname "$JVM_PATH")
    echo "Found JVM at: $JVM_DIR"
    export LD_LIBRARY_PATH=$JVM_DIR:$LD_LIBRARY_PATH
else
    echo "WARNING: Could not find libjvm.so in $JAVA_HOME"
    # Try to find JVM in a typical location for OpenJDK 17
    if [ -d "/usr/lib/jvm/java-17-openjdk-amd64/lib/server" ]; then
        echo "Using default JVM path"
        export LD_LIBRARY_PATH=/usr/lib/jvm/java-17-openjdk-amd64/lib/server:$LD_LIBRARY_PATH
    fi
fi

# Try to fix permissions in JRE dir if it exists
if [ -d "${OMADA_DIR}/jre" ]; then
    echo "Fixing JRE permissions"
    chmod -R 755 ${OMADA_DIR}/jre
fi

# Set JAVA_OPTS to explicitly specify JVM path
export JAVA_OPTS="-Djava.library.path=$LD_LIBRARY_PATH"
echo "Using LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "Using JAVA_OPTS: $JAVA_OPTS"

# Start controller with explicit JVM path
./bin/control.sh start

# Keep container running
echo "Services started. Container is now running..."
tail -f /opt/tp-link/omada-controller/logs/server.log
