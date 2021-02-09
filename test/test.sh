#!/bin/bash

set -e

containerID1=""
containerID2=""

function cleanup()
{
    rm ./test/1.*
    rm ./test/2.*
    docker stop ${containerID1} ${containerID2} || true
    docker rm ${containerID1} ${containerID2} || true
}
trap cleanup INT HUP SIGINT EXIT

echo -n "generating configs and launching test containers.."
for i in 1 2; do
    docker run --rm -v $(pwd)/test/:/test/ --entrypoint /bin/sh kristaxox/wg-docker -c "wg genkey | tee /test/$i.privatekey | wg pubkey > /test/$i.publickey"
done

publickey1=$(cat ./test/1.publickey)
privatekey1=$(cat ./test/1.privatekey)
publickey2=$(cat ./test/2.publickey)
privatekey2=$(cat ./test/2.privatekey)

cat > ./test/1.wg0.conf <<EOF
[Interface]
Address = 10.28.0.1/32
ListenPort = 51899
PrivateKey = ${privatekey1}
DNS = 1.1.1.1,8.8.8.8
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = ${publickey2}
AllowedIPs = 10.28.0.2/32
EOF

echo -n "starting c1"
interfaceName1=$(sed "s/[^a-zA-Z0-9]//g" <<< $(openssl rand -base64 3))
containerID1=$(docker run -d --privileged -p 51899:51899 -v /dev/net/tun:/dev/net/tun -v $(pwd)/test/1.wg0.conf:/etc/wireguard/config/${interfaceName1}.conf -e WG_CONFIG_PATH=/etc/wireguard/config/${interfaceName1}.conf --cap-add NET_ADMIN --cap-add SYS_ADMIN kristaxox/wg-docker)
endpoint=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${containerID1})

cat > ./test/2.wg0.conf <<EOF2
[Interface]
Address = 10.28.0.2/32
PrivateKey = ${privatekey2}

[Peer]
PublicKey = ${publickey1}
Endpoint = ${endpoint}:51899
AllowedIPs = 10.28.0.1/32
EOF2

echo -n "starting c2"
interfaceName2=$(sed "s/[^a-zA-Z0-9]//g" <<< $(openssl rand -base64 3))
containerID2=$(docker run -d --privileged -v /dev/net/tun:/dev/net/tun -v $(pwd)/test/2.wg0.conf:/etc/wireguard/config/${interfaceName2}.conf -e WG_CONFIG_PATH=/etc/wireguard/config/${interfaceName2}.conf --cap-add NET_ADMIN --cap-add SYS_ADMIN kristaxox/wg-docker)

echo "testing connection from c2 to c1"
docker exec -t ${containerID2} sh -c 'ping -c 5 10.28.0.1'
if [ "${?}" -eq "1" ]; then
    echo "test failed, cannot ping c1 from c2"
fi
