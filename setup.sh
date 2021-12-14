#!/bin/bash
set -e

install_tools() {
  apt update
  apt install -y docker docker-compose grep lsof net-tools sed
  systemctl enable docker
  systemctl start docker
}

enable_bbr() {
  if [ $(uname -r) '>' "4.9" ]; then
    if [[ $(lsmod | grep 'tcp_bbr') == "" ]]; then
      modprobe tcp_bbr
      echo "tcp_bbr" >>/etc/modules-load.d/modules.conf
    fi
    echo "net.core.default_qdisc=fq" >>/etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.conf
    sysctl -p
    echo "Enable bbr ... ... [OK]."
  else
    echo "Enable bbr ... ... [fail]. BBR only supported on linux 4.9 or newer."
  fi
}

gen_docker_volumes() {
  mkdir -p Volumes/shadowsocks
  mkdir -p Volumes/caddyfile
  mkdir -p Volumes/caddydata
}

prepare() {
  if [ ! -e Volumes ]; then
    install_tools
    enable_bbr
    gen_docker_volumes
  fi

  if [[ $(lsof -i :443 | grep 'docker' | grep -v 'grep') != "" ]]; then
    docker-compose -f docker_compose.yaml down
  fi
}

configure() {
  read -p $'Set your domains, splite them with space, e.g. example.com www.example.com:\n' domains
  read -p $'Set your email, e.g. abc@example.com:\n' email
  read -p $'Set your websocket path, e.g. /example:\n' path
  read -p $'Set your shadowsocks password, e.g. example:\n' sspassword

  finish=false
  until $finish; do
    echo "Your domains is: $domains"
    echo "Your email is: $email"
    echo "Your websocket path is: $path"
    echo "Your sspassword is: $sspassword"
    echo "what do you want next:"
    echo "1. change domains"
    echo "2. change email"
    echo "3. change path"
    echo "4. change sspassword"
    echo "0. finish setting, start up"
    read -p $'Please choose an option by number:\n' choice
    case $choice in
    1)
      read -p $'Set your domains, splite them with space, e.g. example.com www.example.com:\n' domains
      ;;
    2)
      read -p $'Set your email, e.g. abc@example.com:\n' email
      ;;
    3)
      read -p $'Set your websocket path, e.g. /example:\n' path
      ;;
    4)
      read -p $'Set your shadowsocks password, e.g. example:\n' sspassword
      ;;
    0)
      finish=true
      ;;
    *) ;;
    esac
  done

  cp Samples/shadowsocks.sample Volumes/shadowsocks/config.json
  cp Samples/Caddyfile.sample Volumes/caddyfile/Caddyfile

  sed -i "s/domains/${domains}/g" Volumes/caddyfile/Caddyfile
  sed -i "s/email/${email}/g" Volumes/caddyfile/Caddyfile
  sed -i "s/path/${path:1}/g" Volumes/caddyfile/Caddyfile
  sed -i "s/sspassword/${sspassword}/g" Volumes/shadowsocks/config.json
}

prepare
configure
docker-compose -f docker_compose.yaml up -d --build
echo "Done"
