#!/bin/bash

# Use set -x for debugging
set -x

# Make sure Java 17 is selected
echo "Checking Java version..."
java -version

# Find the actual Java home path
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
echo "Detected Java Home: $JAVA_HOME"

# Create directories needed for operation
echo "Creating required directories..."
mkdir -p /data/db /var/log/mongodb

# Make sure OMADA_DIR is set correctly and exists
OMADA_DIR=${OMADA_DIR:-/opt/tplink/EAPController}
mkdir -p ${OMADA_DIR}

# Ensure symbolic links exist for compatibility 
# (these links help maintain compatibility with both path structures)
mkdir -p /tp-link
ln -sf ${OMADA_DIR} /tp-link/omada-controller
ln -sf ${OMADA_DIR} /omada-controller

# Create a proper JVM structure as expected by the controller
echo "Setting up JVM directories..."
if [ ! -d "/usr/lib/jvm/java-17-openjdk-amd64/jre/lib/amd64/server/" ]; then
    mkdir -p /usr/lib/jvm/java-17-openjdk-amd64/jre/lib/amd64/server/
    # Only copy if files are different
    if [ ! -f "/usr/lib/jvm/java-17-openjdk-amd64/jre/lib/amd64/server/libjvm.so" ]; then
        cp -f /usr/lib/jvm/java-17-openjdk-amd64/lib/server/libjvm.so /usr/lib/jvm/java-17-openjdk-amd64/jre/lib/amd64/server/
    fi
fi

# Ensure MongoDB data directory exists with proper permissions
mkdir -p /data/db /var/log/mongodb
chmod -R 755 /data/db /var/log/mongodb

# Set up Java environment variables properly
export JAVA_HOME=$JAVA_HOME
export LD_LIBRARY_PATH=/usr/lib/jvm/java-17-openjdk-amd64/lib/server:$LD_LIBRARY_PATH

echo "Environment variables:"
echo "JAVA_HOME=$JAVA_HOME"
echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"

# Run the install script if needed
if [ ! -f "/usr/bin/tpeap" ]; then
    echo "Installing Omada Controller via official installer..."
    
    # Find the installer directory
    if [ -d "/opt/installer/Omada_SDN_Controller_v5.15.20.20_linux_x64" ]; then
        INSTALLER_DIR="/opt/installer/Omada_SDN_Controller_v5.15.20.20_linux_x64"
    else
        # Try to find it elsewhere
        INSTALLER_DIR=$(find / -name "Omada_SDN_Controller_v5.15.20.20_linux_x64" -type d 2>/dev/null | head -n 1)
    fi
    
    if [ -z "$INSTALLER_DIR" ]; then
        echo "ERROR: Could not find installer directory"
        exit 1
    fi
    
    echo "Found installer at: $INSTALLER_DIR"
    cd "$INSTALLER_DIR"
    
    # Check for previous installations and clean them up
    if dpkg -l | grep -q omada; then
        echo "Found previous deb-based installation, removing..."
        apt-get remove --purge -y omada-controller || true
    fi

    # Check for /usr/bin/tpeap and remove it if it exists but is broken
    if [ -f "/usr/bin/tpeap" ] && ! /usr/bin/tpeap help >/dev/null 2>&1; then
        echo "Found broken tpeap installation, removing..."
        rm -f /usr/bin/tpeap
    fi

    # Create expect script to handle multiple prompts
    cat > /tmp/install_expect.sh << 'EOF'
#!/usr/bin/expect -f
set timeout 120
spawn ./install.sh
expect {
    "Omada Controller will be installed in" { send "y\r"; exp_continue }
    "continue with upgrade" { send "y\r"; exp_continue }
    "controller is installed by deb" { exit 1 }
    timeout { exit 2 }
    eof
}
EOF
    
    # Make the expect script executable
    chmod +x /tmp/install_expect.sh
    
    # Run the expect script
    echo "Running installation with expect..."
    /tmp/install_expect.sh
    
    # Check if installation failed
    if [ $? -ne 0 ]; then
        echo "Expect script failed or detected a problem"
        
        # Try manual uninstallation of any previous version
        if [ -f "/opt/tplink/EAPController/uninstall.sh" ]; then
            echo "Running uninstall script first..."
            /opt/tplink/EAPController/uninstall.sh -y || true
            sleep 5
        fi
        
        # Try a direct installation
        echo "Trying direct installation..."
        echo -e "y\ny\n" | ./install.sh
    fi
    
    # Verify installation
    if [ ! -f "/usr/bin/tpeap" ]; then
        echo "ERROR: Installation failed - tpeap command not found"
        # Continue anyway to keep container running for debugging
    fi
else
    echo "Omada Controller is already installed, starting service..."
    tpeap start
fi

# Check if the process is running properly
sleep 10
echo "Checking if controller started..."
if command -v tpeap >/dev/null 2>&1; then
    tpeap status
else
    echo "tpeap command not found - installation may have failed"
    echo "Checking for running Java processes..."
    ps aux | grep java
fi

echo "Checking for network ports..."
if command -v netstat >/dev/null 2>&1; then
    netstat -tulpn | grep -E '8088|8043|8843|29810|29811|29812|29813|29814|27001|27002'
else
    echo "netstat not found, installing..."
    apt-get update && apt-get install -y net-tools
    netstat -tulpn | grep -E '8088|8043|8843|29810|29811|29812|29813|29814|27001|27002'
fi

# Keep container running and monitor the main process
echo "Services started. Container is now running..."

# Use a monitoring loop to keep the container running
echo "Starting monitoring loop..."

# Wait for web interface to be available
echo "Waiting for web interface to become available..."
attempt=1
max_attempts=30
while ! nc -z localhost 8088 && [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt/$max_attempts: Web interface not yet available, waiting..."
    sleep 10
    ((attempt++))
done

if nc -z localhost 8088; then
    echo "✅ Web interface is available on port 8088"
else
    echo "⚠️ Web interface did not become available within timeout period"
fi

# Main monitoring loop
while true; do
    # Check if the controller process is still running
    if ! pgrep -f "com.tplink.smb.omada.starter.OmadaLinuxMain" > /dev/null; then
        echo "WARNING: Omada Controller process not found. Attempting to restart..."
        
        if command -v tpeap >/dev/null 2>&1; then
            tpeap restart
        elif [ -f "${OMADA_DIR}/bin/control.sh" ]; then
            ${OMADA_DIR}/bin/control.sh restart
        else
            echo "CRITICAL: Cannot restart controller - neither tpeap nor control.sh found"
        fi
        
        sleep 10
    fi
    
    # Check web interface 
    if ! nc -z localhost 8088; then
        echo "WARNING: Web interface is not responding. Checking controller status..."
        
        if command -v tpeap >/dev/null 2>&1; then
            tpeap status
        elif [ -f "${OMADA_DIR}/bin/control.sh" ]; then
            ${OMADA_DIR}/bin/control.sh status
        else
            echo "Controller status check failed - no control methods found"
            ps aux | grep java
        fi
    else
        # Print status every minute if everything is ok
        echo "Web interface is responding on port 8088"
        
        if command -v tpeap >/dev/null 2>&1; then
            tpeap status
        elif [ -f "${OMADA_DIR}/bin/control.sh" ]; then
            ${OMADA_DIR}/bin/control.sh status
        fi
    fi
    
    echo "---------------- $(date) ----------------"
    sleep 60
done
