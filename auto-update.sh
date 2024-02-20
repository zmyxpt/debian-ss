#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail #-o xtrace


cd "$HOME"/debian-ss-main

apt-get update
apt-get upgrade --with-new-pkgs -y

docker-compose down
docker-compose pull
docker-compose build --pull
docker-compose up -d

systemctl reboot
