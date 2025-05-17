# TP-Link Omada Network Controller

This repository contains Docker configuration to run the TP-Link Omada SDN Controller v5.15.20.20 in a container.
The Omada Controller allows you to manage TP-Link access points, switches, and gateways on your network.

## Requirements

- Docker or Podman installed on your system
- Network access to your TP-Link devices

## Specifications

This container includes:

- Ubuntu 22.04 as the base OS
- Omada Controller v5.15.20.20
- OpenJDK 17 (required by Omada 5.15.20+)
- MongoDB 7.0

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

## Stopping the Container

```bash
# Using Docker
docker-compose down

# Using Podman
podman-compose down
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
  -v omada-data:/opt/tp-link/omada-controller/data \
  -v omada-logs:/opt/tp-link/omada-controller/logs \
  -v omada-work:/opt/tp-link/omada-controller/work \
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

- If the controller cannot discover your devices, ensure that your network configuration allows UDP broadcasts.
- Check the container logs for any issues: `docker logs omada-controller` or `podman logs omada-controller`
- For detailed logs, examine the files in the logs volume.
