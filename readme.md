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

## Notes for Future Updates

When trying to update MongoDB to a higher version, anything version 5 or higher, there is an issue on my Mac Podman setup at the moment where any interaction with `mongod` will result in `Illegal instruction (core dumped)`. This is because MongodDB 5 and higher use [AVX](https://en.wikipedia.org/wiki/Advanced_Vector_Extensions) (Advanced Vector Extensions). [Link to docs that say that](https://www.mongodb.com/docs/manual/administration/production-notes/#x86_64:~:text=MongoDB%205.0%20requires%20use%20of%20the%20AVX%20instruction%20set%2C%20available%20on%20select%20Intel%20and%20AMD%20processors.). It doesn't seem like the [default emulation on Mac Rosetta Stone supports that](https://developer.apple.com/documentation/apple-silicon/about-the-rosetta-translation-environment#Determine-Whether-Your-App-Is-Running-as-a-Translated-Binary). This might be able to be fixed by using QEMU instead of default Mac translation when the podman machine is created.
