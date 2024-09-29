#!/bin/bash

set -x

# Identify the root device (usually mounted on /)
ROOT_DEVICE=$(df / | tail -1 | awk '{print $1}')

# List all block devices, excluding the root device and any partitions
UNFORMATTED_DEVICE=$(lsblk -dn -o NAME,TYPE | grep disk | grep -v $(basename $ROOT_DEVICE) | while read DEVICE TYPE; do
    # Check if the device has partitions or is mounted
    if ! mount | grep -q "/dev/$DEVICE" && [ -z "$(lsblk -n /dev/$DEVICE | grep part)" ]; then
        echo "/dev/$DEVICE"
        break
    fi
done)

# If an unformatted device is found, format it and mount it
if [ -n "$UNFORMATTED_DEVICE" ]; then
    echo "Formatting device: $UNFORMATTED_DEVICE"
    sudo mkfs.xfs -f $UNFORMATTED_DEVICE
    sudo mkdir -p /data
    sudo mount $UNFORMATTED_DEVICE /data
    sudo chown -R lucidlink:lucidlink /data
else
    echo "No unformatted device found, skipping disk formatting."
    exit 1
fi

# Enable and start lucidlink service
echo "Enabling 'systemctl enable lucidlink-1.service'"
sudo systemctl enable lucidlink-1.service
wait
echo "Starting 'systemctl start lucidlink-1.service'"
sudo systemctl start lucidlink-1.service
wait

# Wait for lucidlink to be linked
until lucid --instance 501 status | grep -qo "Linked"
do
    sleep 1
done
sleep 1

# Set DataCache size
/usr/bin/lucid --instance 501 config --set --DataCache.Size 80G
wait
sleep 1

# Enable and start s3-gw service
echo "Enabling 'systemctl enable s3-gw.service'"
sudo systemctl enable s3-gw.service
wait
echo "Starting 'systemctl start s3-gw.service'"
sudo systemctl start s3-gw.service