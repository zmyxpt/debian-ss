#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail #-o xtrace


cd "$HOME"/debian-ss-main

apt-get update
apt-get upgrade --with-new-pkgs -y
apt-get autoremove --purge -y

docker-compose down
docker-compose pull || true
docker-compose build --no-cache --pull || true
docker-compose up -d
docker system prune --volumes -f

systemctl reboot
