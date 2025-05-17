# TP-Link Omada Network Controller

This repository contains Docker configuration to run the TP-Link Omada SDN Controller v5.15.20.18 in a container.
The Omada Controller allows you to manage TP-Link access points, switches, and gateways on your network.

## Requirements

- Docker or Podman installed on your system
- Network access to your TP-Link devices

## Specifications

This container includes:

- Ubuntu 22.04 as the base OS
- Omada Controller v5.15.20.18 (installed via Debian package)
- OpenJDK 17 (required by Omada 5.15.20+)
- MongoDB 7.0
- Performance-optimized configuration for maximum CPU resources

## Installation Details

This container uses the official TP-Link Omada Controller installer. The controller is installed to the standard path `/opt/tplink/EAPController`.

For compatibility, symbolic links are created:

- `/tp-link/omada-controller` → `/opt/tplink/EAPController`
- `/omada-controller` → `/opt/tplink/EAPController`

This ensures the controller and its files can be found regardless of which path convention is used.

## Installation and Setup

1. Clone this repository:

   ```bash
   git clone https://github.com/yourusername/network-controller.git
   cd network-controller
   ```

2. Build and start the container:

   ```bash
   # Using Docker
   docker-compose up -d

   # Using Podman
   podman compose up -d
   ```

3. Access the Omada Controller web interface:
   - HTTP: http://localhost:8088
   - HTTPS: https://localhost:8043

## Ports Used

- 8088: HTTP portal
- 8043: HTTPS portal for web interface
- 8843: HTTPS portal for controller to manage EAPs
- 29810-29814: Discovery ports
- 27001-27002: MongoDB ports

## Data Persistence

The container uses Docker volumes for data persistence:

- `omada-data`: Stores controller configuration and data
- `omada-logs`: Stores controller logs
- `omada-work`: Stores working files
- `mongodb-data`: Stores MongoDB database files

## Stopping the Container

```bash
# Using Docker
docker-compose down

# Using Podman
podman compose down
```

## Managing the Container

### Quick Scripts

We've included helper scripts to make managing the container easier:

- `./restart.sh` - Stops, removes, rebuilds, and starts the container with one command
- `./logs.sh` - Shows the container logs for monitoring

### Manual Management

```bash
# Stop the container
podman stop omada-controller

# Remove the container
podman rm omada-controller

# Rebuild the image (after making changes)
podman build -t localhost/omada-controller:latest .

# Start the container
podman run -d \
  --name omada-controller \
  --restart=always \
  -p 8088:8088 -p 8043:8043 -p 8843:8843 \
  -p 29810:29810 -p 29811:29811 -p 29812:29812 -p 29813:29813 -p 29814:29814 \
  -v omada-data:/opt/tplink/EAPController/data \
  -v omada-logs:/opt/tplink/EAPController/logs \
  -v omada-work:/opt/tplink/EAPController/work \
  -v mongodb-data:/data/db \
  localhost/omada-controller:latest
```

## Updating the Controller

To update to a newer version of the controller, update the `OMADA_VERSION` in the Dockerfile and the download URL, then rebuild:

```bash
# Update the version in the Dockerfile
# Then run the restart script
./restart.sh

# Or manually:
podman build -t localhost/omada-controller:latest .
podman stop omada-controller
podman rm omada-controller
podman run -d --name omada-controller [OPTIONS] localhost/omada-controller:latest
```

## Troubleshooting

### Common Issues

- **Web Interface Not Available**: The container startup script checks for port 8088 availability. If after 5 minutes the web interface is not available, check the logs.
- **Discovery Issues**: If the controller cannot discover your TP-Link devices, ensure your network configuration allows UDP broadcasts on ports 29810-29814.
- **High CPU Usage**: If you notice high CPU usage when the container starts, wait about 5 minutes for it to stabilize. The initial startup process can be resource-intensive.
- **Installation Errors**: If the installation fails, check the logs for specific errors. You might need to clean existing data volumes if upgrading from a previous version.
- **Previous Installation Detected**: If you see errors about a "controller installed by deb", the container will try to clean up the previous installation automatically. If it fails, you may need to manually remove the volumes and rebuild the container.
- **Path Issues**: The container uses a standard path (`/opt/tplink/EAPController`) and creates symbolic links to maintain compatibility. If you encounter path-related errors, please report them.

### Viewing Logs

- Use the included script: `./logs.sh`
- Direct container logs: `podman logs omada-controller` or `docker logs omada-controller`
- Detailed application logs: These are stored in the omada-logs volume

### Reset Installation

If you encounter persistent issues with the controller, you can completely reset the installation:

```bash
# Stop and remove the container
podman stop omada-controller
podman rm omada-controller

# Remove all volumes to start fresh
podman volume rm omada-data omada-logs omada-work mongodb-data

# Rebuild and start the container
./restart.sh
```

This will remove all configuration and data, so use with caution!

### Omada Controller Management Commands

Once inside the container, you can use the following commands to manage the Omada Controller:

```bash
# Standard commands via tpeap
tpeap start    # Start the controller
tpeap stop     # Stop the controller
tpeap restart  # Restart the controller
tpeap status   # Check controller status
```

You can execute these commands using:

```bash
podman exec omada-controller /opt/tp-link/omada-controller/bin/control.sh status
```
