# TP-Link Omada Network Controller

This repository contains Docker configuration to run the TP-Link Omada SDN Controller in a container.
The Omada Controller allows you to manage TP-Link access points, switches, and gateways on your network.

## Requirements

- Docker or Podman installed on your system
- Network access to your TP-Link devices

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
   podman-compose up -d
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

## Updating the Controller

To update to a newer version of the controller, update the `OMADA_VERSION` in the Dockerfile and the download URL, then rebuild:

```bash
# Using Docker
docker-compose build --no-cache
docker-compose up -d

# Using Podman
podman-compose build --no-cache
podman-compose up -d
```

## Troubleshooting

- If the controller cannot discover your devices, ensure that your network configuration allows UDP broadcasts.
- Check the container logs for any issues: `docker logs omada-controller` or `podman logs omada-controller`
- For detailed logs, examine the files in the logs volume.
