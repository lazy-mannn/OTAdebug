#!/bin/bash

set -e

echo "[+] Updating package list and installing usbip..."
sudo apt update
sudo apt install -y usbip

echo "[+] Enabling kernel modules..."
echo -e "usbip-core\nusbip-host" | sudo tee -a /etc/modules > /dev/null

echo "[+] Loading kernel modules..."
sudo modprobe usbip-core
sudo modprobe usbip-host

echo "[+] Enabling usbipd daemon..."
# usbipd runs manually for now, can be added to systemd if needed

echo "[+] Creating USB auto-bind script..."
sudo tee /usr/local/bin/usbip_autobind_udev.sh > /dev/null << 'EOF'
#!/bin/bash

BUSID=$1

echo "[udev] Attempting to bind USB device $BUSID to usbip..." >> /var/log/usbip-udev.log

modprobe usbip-core
modprobe usbip-host

DRIVER_PATH="/sys/bus/usb/devices/$BUSID/driver"
if [ -L "$DRIVER_PATH" ]; then
    DRIVER=$(basename "$(readlink "$DRIVER_PATH")")
    echo "$BUSID" > "/sys/bus/usb/drivers/$DRIVER/unbind"
    echo "[udev] Unbound $BUSID from driver $DRIVER" >> /var/log/usbip-udev.log
fi

usbip bind -b "$BUSID" >> /var/log/usbip-udev.log 2>&1
echo "[udev] Bound $BUSID to usbip at $(date)" >> /var/log/usbip-udev.log
EOF

sudo chmod +x /usr/local/bin/usbip_autobind_udev.sh

echo "[+] Creating udev rule for auto-binding USB devices..."
sudo tee /etc/udev/rules.d/99-usbip-autobind.rules > /dev/null << 'EOF'
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", RUN+="/usr/local/bin/usbip_autobind_udev.sh %k"
EOF

echo "[+] Reloading udev rules..."
sudo udevadm control --reload
sudo udevadm trigger

echo "[+] Starting usbipd daemon in background..."
sudo pkill usbipd || true
sudo usbipd -D

echo "[✓] Setup complete!"
echo "→ Plug in your USB device and check from your PC using:"
echo "    usbip list -r <pi-ip>"

