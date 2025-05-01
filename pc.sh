#!/bin/bash

PI_IP="192.168.101.123"

echo "[INFO] Pinging $PI_IP..."
if ! ping -c 1 "$PI_IP" &>/dev/null; then
    echo "[ERROR] Pi is not reachable at $PI_IP."
    exit 1
fi

echo "[INFO] Pi is online. Looking for USB devices..."
USBIP_OUTPUT=$(usbip list -r "$PI_IP" 2>/dev/null)

echo "$USBIP_OUTPUT"

# Extract busid from the format: "        1-1: ..."
BUSID=$(echo "$USBIP_OUTPUT" | grep -oP '^\s*\K[0-9]+-[0-9]+(?=:)' | head -n 1)

if [ -z "$BUSID" ]; then
    echo "[INFO] No exportable USB devices found on $PI_IP. Maybe already attached?"
    exit 0
fi

echo "[INFO] Found busid: $BUSID"

# Check if already attached
if usbip port | grep -q "$BUSID"; then
    echo "[INFO] Device $BUSID is already attached. Exiting."
    exit 0
fi

# Short delay to avoid attach race condition
sleep 1

echo "[INFO] Attaching device $BUSID..."
sudo usbip attach -r "$PI_IP" -b "$BUSID"

# Wait a moment and check
sleep 1

if usbip port | grep -q "$BUSID"; then
    echo "[INFO] Device $BUSID successfully attached!"
    exit 0
else
    echo "[WARN] First attach failed. Retrying once..."
    sleep 1
    sudo usbip attach -r "$PI_IP" -b "$BUSID"
    sleep 1

    if usbip port | grep -q "$BUSID"; then
        echo "[INFO] Device $BUSID attached on second attempt!"
        exit 0
    else
        echo "[ERROR] Failed to attach device $BUSID after retry."
        exit 1
    fi
fi

