#!/bin/bash

# Start MongoDB
echo "Starting MongoDB..."
mongod --fork --logpath /var/log/mongodb.log

# Give MongoDB a moment to start
sleep 5

# Start Omada Controller
echo "Starting Omada Controller..."
cd /opt/tp-link/omada-controller
./bin/control.sh start

# Keep container running
echo "Services started. Container is now running..."
tail -f /opt/tp-link/omada-controller/logs/server.log
