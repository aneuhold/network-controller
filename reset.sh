#!/bin/zsh

echo "⚠️  WARNING: This will delete all controller data and configuration!"
echo "    All settings, managed devices, and statistics will be lost."
echo ""
read "REPLY?Are you sure you want to continue? (y/n): "

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "🛑 Reset cancelled."
    exit 0
fi

echo "🛑 Stopping and removing container..."
podman stop omada-controller 2>/dev/null || true
podman rm omada-controller 2>/dev/null || true

echo "🗑️  Removing all volumes..."
podman volume rm omada-data 2>/dev/null || true
podman volume rm omada-logs 2>/dev/null || true
podman volume rm omada-work 2>/dev/null || true
podman volume rm mongodb-data 2>/dev/null || true

echo "🗑️  Removing old image..."
podman rmi localhost/omada-controller:latest -i 2>/dev/null || true

echo "🔨 Rebuilding the container..."
podman build --no-cache -t localhost/omada-controller:latest .

echo "🚀 Starting fresh container..."
./start.sh

echo "✅ Container reset and restarted with fresh data!"
echo "🖥️  Access the web interface at:"
echo "   - http://localhost:8088"
echo "   - https://localhost:8043"
echo ""
echo "⏳ Note: The controller will take a few minutes to initialize."
