# Proxmox Cloud-Init Template Script
This script will create a variety [Cloud-Init](https://cloud-init.io/) templates for Proxmox. 

It creates a minimal Cloud-Init template for each configured image. Requires later customization, e.g. CPU/RAM, expanding storage, adding users, SSH keys, etc. Since I handle configuration in Terraform and Ansible, I wanted to keep these Cloud-Init templates as minimal as possible. If you would like to add additional functionality, feel free to fork this repo.

### Included Images
- Ubuntu 24.04 LTS (Noble Numbat)
- Debian 12 (Bookworm) (Old Stable)
- Debian 13 (Trixie) (Current Stable)
- Fedora 41
- Fedora 42
- Rocky 9
- Rocky 10 (Latest)

## How To Use

### Setting Variables
Most likely my Proxmox environment does not match yours. Be sure to update the Variables section with with your own values before running. Pay special attention to:
- `VM_ID`
- `STORAGE`
- `NET_BRIDGE`

### Adding / Removing Images
To add or remove images, edit the `$IMAGES` associative array.
- Key: the VM Template Name (e.g. `ubuntu-24.04`)
- Value: the URL to download the image

### Running the Script
This is intended to only be run on Proxmox hosts. Tested on PVE 8.4.