# wg-docker

Wrapping [userspace wireguard](https://git.zx2c4.com/wireguard-go/) in a docker container.

## Why userspace?

Well there still exists several OS that do not have the wireguard kernel headers, but my main motivation was the lack of support in CO-OS (GKE in my case).

## Kubernetes Deploy

### sidecar

container spec:

```yaml
- name: wg-docker
  image: kristaxox/wg-docker:latest
  imagePullPolicy: Always
  env:
    - name: CONFIG_FILE_PATH
      value: /etc/wireguard/config/wg0.conf
  securityContext:
    privileged: true
    capabilities:
      add: ["NET_ADMIN"]
  volumeMounts:
    - name: wg-relay-config-volume
      mountPath: /etc/wireguard/config/
```

volumes spec:

```yaml
- name: wg-relay-config-volume
  configMap:
    name: wg-relay-config
    items:
    - key: "wg0.conf"
      path: "wg0.conf"
```

### configmap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: wg-relay-config
data:
  wg0.conf: |
    [Interface]
    # Name = relay1.example.com
    Address = 10.12.0.5/24
    PrivateKey = <PrivateKey>
    DNS = 1.1.1.1,8.8.8.8
    PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

    [Peer]
    # Name = server1.example.com
    PublicKey = <PublicKey>
    Endpoint = <Endpoint>
    AllowedIPs = 10.12.0.2/32
```
