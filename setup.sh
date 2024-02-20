#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail #-o xtrace

check_if_running_as_root()
{
    if [[ $UID -ne 0 ]]
    then
        echo -e "\033[31mNot running with root, exiting...\033[0m"
        exit 1
    fi
}

check_if_running_in_container()
{
    if [[ $(ps --pid 1 | grep -v PID | awk '{print $4}') != "systemd" ]]
    then
        echo -e "\033[31mRunning in containers is not supported, exiting ...\033[0m"
        exit 2
    fi
}

check_os_version()
{
    if [[ $(lsb_release -is 2>&1) != "Debian" ]]
    then
        echo -e "\033[31mUnsupported linux distro!\033[0m"
        exit 3
    fi

    if [[ $(lsb_release -cs 2>&1) != "buster" &&
          $(lsb_release -cs 2>&1) != "bullseye" &&
          $(lsb_release -cs 2>&1) != "bookworm" ]]
    then
        echo -e "\033[31mUnsupported debian version!\033[0m"
        exit 4
    fi
}

install_packages()
{
    apt-get update
    apt-get upgrade --with-new-pkgs -y
    apt-get install -y aptitude cron docker.io docker-compose unzip
    aptitude search ~pstandard ~prequired ~pimportant -F%p | xargs apt-get install -y
}

enable_bbr()
{
    if [[ $(lsmod | awk '{print $1}' | grep 'tcp_bbr') == "tcp_bbr" ]] || modprobe tcp_bbr
    then
        if [[ $(grep '^tcp_bbr' /etc/modules-load.d/modules.conf) == "" ]]
        then
            echo "tcp_bbr" >>/etc/modules-load.d/modules.conf
        fi

        if [[ $(grep '^net.core.default_qdisc.*=' /etc/sysctl.conf) == "" ]]
        then
            echo "net.core.default_qdisc = fq" >>/etc/sysctl.conf
        else
            sed -i -e 's/net\.core\.default_qdisc.*=.*$/net\.core\.default_qdisc = fq/' /etc/sysctl.conf
        fi

        if [[ $(grep '^net.ipv4.tcp_congestion_control.*=' /etc/sysctl.conf) == "" ]]
        then
            echo "net.ipv4.tcp_congestion_control = bbr" >>/etc/sysctl.conf
        else
            sed -i -e 's/net\.ipv4\.tcp_congestion_control.*=.*$/net\.ipv4\.tcp_congestion_control = bbr/' /etc/sysctl.conf
        fi

        sysctl -p

        echo -e "Enable bbr ... \033[32m[done]\033[0m."
    else
        echo -e "Enable bbr ... \033[33m[cancel] This kernel don't support BBR.\033[0m"
    fi
}

download_res()
{
    if ! curl -fsSL 'https://github.com/zmyxpt/debian-ss/archive/refs/heads/main.zip' -o debian-ss.zip
    then
        echo -e "\033[31mFail to download debian-ss resource, exiting...\033[0m"
        exit 5
    fi

    unzip -o debian-ss.zip
    rm debian-ss.zip
}

configure()
{
    if [[ ! -e Volumes ]]
    then
        mkdir -p Volumes/shadowsocks
        mkdir -p Volumes/caddyfile
        mkdir -p Volumes/caddydata
    fi

    local domains email ws_path ss_password
    read -r -p $'Set your domains, splite them with space, e.g. \033[1mexample.com www.example.com\033[0m\n' domains
    read -r -p $'Set your email to receive TLS certificate notice, e.g. \033[1mabc@gmail.com\033[0m\n' email
    read -r -p $'Set your websocket path, e.g. \033[1m/path_to_ws\033[0m\n' ws_path
    read -r -p $'Set your shadowsocks password, e.g. \033[1mpass1234\033[0m\n' ss_password

    local finish=false
    until "$finish"
    do
        echo $'Here is your setting:\n=============================='
        echo -e "Domains: \033[32m${domains}\033[0m"
        echo -e "Email: \033[32m${email}\033[0m"
        echo -e "Path: \033[32m${ws_path}\033[0m"
        echo -e "Password: \033[32m${ss_password}\033[0m"
        echo $'===============================\nYou can:'
        echo "1. Reset domains"
        echo "2. Reset email"
        echo "3. Reset websocket path"
        echo "4. Reset shadowsocks password"
        echo "0. Finish it, start up"
        read -r -p $'Choose an option by number:\n' choice
        case "$choice" in
        1)
            read -r -p $'Set your domains, splite them with space, e.g. \033[1mexample.com www.example.com\033[0m\n' domains
            ;;
        2)
            read -r -p $'Set your email to receive TLS certificate notice, e.g. \033[1mabc@gmail.com\033[0m\n' email
            ;;
        3)
            read -r -p $'Set your websocket path, e.g. \033[1m/path_to_ws\033[0m\n' ws_path
            ;;
        4)
            read -r -p $'Set your shadowsocks password, e.g. \033[1mpass1234\033[0m\n' ss_password
            ;;
        0)
            finish=true
            ;;
        *) ;;
        esac
    done

    cp Samples/shadowsocks.sample Volumes/shadowsocks/config.json
    cp Samples/Caddyfile.sample Volumes/caddyfile/Caddyfile

    sed -i -e "s/domains/${domains}/" Volumes/caddyfile/Caddyfile
    sed -i -e "s/email/${email}/" Volumes/caddyfile/Caddyfile
    sed -i -e "s/ws_path/${ws_path:1}/" Volumes/caddyfile/Caddyfile
    sed -i -e "s/ss_password/${ss_password}/" Volumes/shadowsocks/config.json
}

run_server()
{    
    if [[ $(lsof -i :443 | grep 'docker' | grep -v 'grep') != "" ]]
    then
        docker-compose down
    fi

    docker-compose pull
    docker-compose build --pull
    docker-compose up -d
}

auto_update_cron()
{
    echo 'Etc/UTC' >/etc/timezone
    systemctl restart cron.service
    
    local cronfile
    cronfile=$(mktemp)
    cat <<'EOF' >"$cronfile"
0 19 * * 1 bash "$HOME"/debian-ss-main/auto-update.sh
EOF
    crontab "$cronfile"
    rm "$cronfile"
}

client_configure_help()
{
    echo -e "=================================================="
    echo -e "\n  Deploy finished!"
    echo -e "\n  On client side, install \033[33mshadowsocks\033[0m and \033[33mv2ray plugin\033[0m, then edit config json:"
    echo -e "\n   \"server\" should be \033[3;33m\"one_of_your_domains\"\033[0m"
    echo -e "   \"server_port\" should be \033[33m443\033[0m"
    echo -e "   \"password\" should be \033[3;33m\"your_ss_password\"\033[0m"
    echo -e "   \"method\" should be \033[33m\"aes-256-gcm\"\033[0m"
    echo -e "   \"plugin\" should be the path you run v2ray plugin from within shadowsocks workdir"
    echo -e "   \"plugin_opts\" should be \033[33m\"tls;host=\033[3mone_of_your_domains\033[0;33m;path=\033[3myour_path\033[33m\"\033[0m"
    echo -e "\n=================================================="
}

main()
{
    local old_PWD
    old_PWD=$PWD

    check_if_running_as_root
    check_if_running_in_container
    check_os_version
    install_packages
    enable_bbr

    cd "$HOME"
    download_res

    cd debian-ss-main
    configure
    run_server
    auto_update_cron
    client_configure_help

    cd "$old_PWD"
}

main
