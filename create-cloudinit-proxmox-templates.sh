#!/bin/bash

# Must run on a Proxmox VE server
# Creates a minimal Cloud-Init template for each configured image. Requires later customization, e.g. CPU/RAM, expanding storage, adding users, SSH keys, etc.
# Since I handle the configuration in Terraform and Ansible, I wanted to keep these Cloud-Init templates as minimal as possible.

# Variables - Change these to match your environment
VM_ID=10000 # VMIDs are globally unique in your PVE server/cluster. The first template will have this ID; all others will increment by 1. 
STORAGE=zfs-nvme # Change to your storage 
SSD=1 # set to 0 if HDD
NET_BRIDGE="vmbr0"
CORES="1"
CPU_TYPE="host"
MEM="1024"
DOWNLOAD_IMAGES=true # will run the "wget". Useful to turn on/off with the RM_DOWNLOADS var for testing
RM_DOWNLOADS=true # Will remove the downloaded file after creating the template if set to 1

# Colors
R='\e[31m'
G='\e[32m'
B='\e[34m'
W='\e[0m'
# echo -e "${COLOR}your-text-here${W}" # <-- example

# Checks to see if libguestfs-tools is installed. It is required
echo -e "${B}Checking if libguestfs-tools is installed...${W}"
if [ "$(dpkg -l | awk '/libguestfs-tools/ {print }'|wc -l)" -ge 1 ]; then
    echo -e "${G}libguestfs-tools is installed${W}"
else
    echo -e "${R}libguestfs-tools is not installed. Installing${W}"
    apt update -y
    apt install libguestfs-tools -y
    echo -e "${G}Done${W}"
fi

# args:
#   - VM/Template ID
#   - VM/Template Name
#   - File Name
function create_template() {

    # Destroys old template if it exists
    echo -e "${R}Destroying existing VM template${W}"
    qm destroy $1 

    echo -e "${B}Install QEMU Guest Agent on new image${W}"
    virt-customize -a $3 --install qemu-guest-agent

    # Create and configure the image
    echo -e "${B}Configuring image${W}"
    qm create $1 --name $2 --ostype l26 
    qm set $1 --net0 virtio,bridge=${NET_BRIDGE} #  Network
    qm set $1 --serial0 socket --vga serial0 # Display
    qm set $1 --memory ${MEM} --cores ${CORES} --cpu ${CPU_TYPE} # Compute Resources
    qm set $1 --scsi0 ${STORAGE}:0,import-from="$(pwd)/$3",cache=writethrough,discard=on,iothread=1,ssd=$SSD # Storage
    qm set $1 --boot order=scsi0 --scsihw virtio-scsi-single # Boot Order & SCSI Controller
    qm set $1 --agent enabled=1,fstrim_cloned_disks=1 # QEMU Guest Agent
    qm set $1 --ide2 ${STORAGE}:cloudinit # Cloud-Init drive
    qm set $1 --ipconfig0 "ip=dhcp" # IP Address
    qm set $1 --description "Cloud-Init Template - Created on $(date)" # Lists the creation date

    echo -e "${B}Final Configuration:${W}"
    qm config $1

    echo -e "${B}Converting to VM Template${W}"
    qm template $1

    # Remove downloaded image file if enabled
    if $RM_DOWNLOADS; then
        echo -e "${R}Removing downloaded image file: $3${W}"
        rm $3
    fi

    echo -e "${G}Done creating '$2' template!${W}"
    echo ""
    VM_ID=$((VM_ID + 1)) # Increment the ID for the next template
}

# If you want to add or remove images, update the associative array below
# Images to create:
# Ubuntu 24.04 (Noble Numbat) LTS
# Debian 12 (Bookworm) (Old Stable)
# Debian 13 (Trixie) (Stable)
# Fedora 41
# Fedora 42
# Rocky 9
# Rocky 10 (Latest)

# Key=Template Name, Value=Image Download URL
declare -A IMAGES=(
    ["ubuntu-24.04"]="https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
    # ["debian-12"]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
    ["debian-13"]="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
    # ["fedora-41"]="https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2"
    ["fedora-42"]="https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2"
    # ["rocky-9"]="http://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
    ["rocky-10"]="https://dl.rockylinux.org/pub/rocky/10/images/x86_64/Rocky-10-GenericCloud-Base.latest.x86_64.qcow2"
)

for NAME in "${!IMAGES[@]}"; do
    URL="${IMAGES[$NAME]}"
    FILE="${URL##*/}"
    echo -e "\n-------------------------------------------------"
    echo "Creating Template for $NAME (VM ID $VM_ID)"
    echo -e "-------------------------------------------------\n"
    if $DOWNLOAD_IMAGES; then
        echo -e "${B}Downloading image${W}"
        wget "$URL";
    fi
    create_template "$VM_ID" "$NAME" "$FILE"
done
