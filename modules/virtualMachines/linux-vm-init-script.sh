#!/bin/sh

echo "Script triggered by cloud-init process"


# Install required packages and ensure installed packages are updated

apt update
apt upgrade -y
apt install curl nfs-common jq python3-pip -y

# Install latest Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Mount the NFS File Share

mkdir -p /mnt/share

mount -o sec=sys,vers=3,nolock,proto=tcp {0}.blob.core.windows.net:/{0}/{1}  /mnt/share

# AzFinSim setup
git clone https://github.com/utkarshayachit/azfinsim /azfinsim