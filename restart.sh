#!/bin/zsh

echo "🛑 Stopping container..."
podman stop omada-controller 2>/dev/null || true

echo "🗑️  Removing container..."
podman rm omada-controller 2>/dev/null || true

echo "🔨 Rebuilding the image..."
podman build -t localhost/omada-controller:latest .

echo "🚀 Starting new container..."
./start.sh

echo "✅ Container started!"
echo "📊 To view logs: podman logs -f omada-controller"
echo "🖥️  Access the web interface at:"
echo "   - http://localhost:8088"
echo "   - https://localhost:8043"
echo ""
echo "⏳ Note: The controller may take a minute or two to fully start up."
echo "   Check the logs to confirm when it's ready."
