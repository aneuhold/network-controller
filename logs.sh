#!/bin/zsh

echo "📜 Showing container logs (press Ctrl+C to exit)..."
podman logs -f omada-controller
