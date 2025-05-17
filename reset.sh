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

echo "🔨 Rebuilding the container..."
podman build --no-cache -t localhost/omada-controller:latest .

echo "🚀 Starting fresh container..."
podman run -d \
  --name omada-controller \
  --restart=always \
  --cpus=4.0 \
  --memory=6g \
  --memory-reservation=2g \
  --ulimit nofile=65536:65536 \
  -p 8088:8088 \
  -p 8043:8043 \
  -p 8843:8843 \
  -p 29810:29810 \
  -p 29811:29811 \
  -p 29812:29812 \
  -p 29813:29813 \
  -p 29814:29814 \
  -v omada-data:/opt/tplink/EAPController/data:Z \
  -v omada-logs:/opt/tplink/EAPController/logs:Z \
  -v omada-work:/opt/tplink/EAPController/work:Z \
  -v mongodb-data:/data/db:Z \
  localhost/omada-controller:latest

echo "✅ Container reset and restarted with fresh data!"
echo "📊 To view logs: ./logs.sh"
echo "🖥️  Access the web interface at:"
echo "   - http://localhost:8088"
echo "   - https://localhost:8043"
echo ""
echo "⏳ Note: The controller will take a few minutes to initialize."
