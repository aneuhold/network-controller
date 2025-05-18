#!/bin/bash

echo "============================================="
echo "TP-Link Omada Controller - Simple Startup"
echo "============================================="

# Install omada if not found
if ! command -v tpeap &> /dev/null; then
  echo "⚠️ Omada Controller not found. Installing..."
  dpkg -i /tmp/omada-controller.deb
  if [ $? -ne 0 ]; then
    echo "❌ Failed to install Omada Controller package."
    exit 1
  fi
else
  echo "✅ Omada Controller already installed."
fi

# Start Omada Controller manually
echo "● Starting Omada Controller service..."
if [ -f "/usr/bin/tpeap" ]; then
  echo "  Starting with tpeap command..."
  tpeap start
else
  echo "  ⚠️ Cannot start Omada: tpeap command not found."
fi

# Display network ports in use
echo "✅ Checking network ports..."
netstat -tulpn | grep -E '8088|8043|8843|29810|29811|29812|29813|29814' || echo "No controller ports detected yet - may still be starting up"

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