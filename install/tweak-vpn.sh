#!/bin/bash
# =========================================
# VPS VPN & Xray Optimization Script
# BY : XCODEX Style
# Date: 2025-11-29
# =========================================

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Run this script as root!" 
   exit 1
fi

echo "=============================="
echo "Starting VPS VPN & Xray Tweak"
echo "=============================="

# -------------------------------
# 1️⃣ System Optimization
# -------------------------------
echo "[*] Setting up swap RAM 1GB by default..."
dd if=/dev/zero of=/swapfile bs=1024 count=1048576
chmod 0600 /swapfile
mkswap /swapfile
swapon /swapfile
sed -i '/\/swapfile/d' /etc/fstab
echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
sleep 1

# 3️⃣ Tambah repository rasmi Ookla
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash

# 4️⃣ Pasang Speedtest CLI
apt-get install speedtest -y

wget -O bbr "https://raw.githubusercontent.com/vibecodingxx/trix/main/tweak/bbr.sh" && chmod +x bbr && ./bbr

# -------------------------------
echo "==================================="
echo "✅ VPS VPN & Xray tweak completed!"
echo "==================================="
rm -r tweak-vpn.sh
sleep 1
