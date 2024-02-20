# Introduction
Deploy shadowsocks server in "tls + websocket" mode, use:
 - [shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)
 - [v2ray-plugin](https://github.com/shadowsocks/v2ray-plugin)
 - [Caddy v2](https://caddyserver.com)
 - [Let's Encrypt certificate](https://letsencrypt.org/)

# Prepare
1. Buy a VPS, install debian 10-12
2. Buy a domain, points to VPS's IP
3. If CDN is using for your domain, disable it until deploy finished

# Now run commands below, follow the instructions
```
apt update &&
apt install -y curl &&
bash <(curl -fsSL 'https://raw.githubusercontent.com/zmyxpt/debian-ss/main/setup.sh')
```
