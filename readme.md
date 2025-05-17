# TP-Link Omada Network Controller

This repository contains Docker configuration to run the TP-Link Omada SDN Controller v5.15.20.18 in a container.
The Omada Controller allows you to manage TP-Link access points, switches, and gateways on your network.

## Requirements

- Docker or Podman installed on your system
- Network access to your TP-Link devices

## Specifications

### Viewing Logs

- Use the included script: `./logs.sh`
- Direct container logs: `podman logs omada-controller` or `docker logs omada-controller`
- Detailed application logs: These are stored in the omada-logs volume

### Reset Installation

If you encounter persistent issues with the controller, you can completely reset the installation:

```bash
# Rebuild and start the container
./reset.sh
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

## Notes

- Left off trying to figure out why it hangs at the startup
