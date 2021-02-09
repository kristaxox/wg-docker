#!/bin/ash
set -e
wgConfigPath=${WG_CONFIG_PATH:-/etc/wireguard/config/wg0.conf}

function cleanup()
{
    echo "stopping wg interface..."
    wg-quick down ${wgConfigPath} || true
}
trap cleanup INT HUP SIGINT

echo "starting wg interface..."
sysctl -w net.ipv4.ip_forward=1 && sysctl -w net.ipv4.conf.all.forwarding=1
wg-quick up ${wgConfigPath}
wg show

# block forever!
sleep infinity &
wait