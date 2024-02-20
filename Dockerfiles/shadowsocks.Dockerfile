FROM debian:latest
RUN set -evx && \
    apt-get update && \
    apt-get upgrade --with-new-pkgs -y && \
    apt-get install -y shadowsocks-libev shadowsocks-v2ray-plugin
CMD [ "ss-server" ]
