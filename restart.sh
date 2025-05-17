#!/bin/zsh

echo "🛑 Stopping container..."
podman stop omada-controller 2>/dev/null || true

echo "🗑️  Removing container..."
podman rm omada-controller 2>/dev/null || true

echo "🔨 Rebuilding the image..."
podman build -t localhost/omada-controller:latest .

echo "🚀 Starting new container..."
podman run -d \
  --name omada-controller \
  --restart=always \
  -p 8088:8088 \
  -p 8043:8043 \
  -p 8843:8843 \
  -p 29810:29810 \
  -p 29811:29811 \
  -p 29812:29812 \
  -p 29813:29813 \
  -p 29814:29814 \
  -v omada-data:/opt/tplink/EAPController/data \
  -v omada-logs:/opt/tplink/EAPController/logs \
  -v omada-work:/opt/tplink/EAPController/work \
  -v mongodb-data:/data/db \
  localhost/omada-controller:latest

echo "✅ Container started!"
echo "📊 To view logs: podman logs -f omada-controller"
echo "🖥️  Access the web interface at:"
echo "   - http://localhost:8088"
echo "   - https://localhost:8043"
echo ""
echo "⏳ Note: The controller may take a minute or two to fully start up."
echo "   Check the logs to confirm when it's ready."
