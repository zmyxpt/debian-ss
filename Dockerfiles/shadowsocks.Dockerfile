FROM debian:bullseye
RUN set -evx \
 && sed -i "s/ main/ main contrib/g" /etc/apt/sources.list \
 && apt update \
 && apt upgrade -y \
 && apt install -y shadowsocks-libev shadowsocks-v2ray-plugin
CMD [ "ss-server" ]
