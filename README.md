# How To Use

## Prepare
1. An overseas VPS, with debian 10 or 11 installed;
2. A domain name, pointed to your VPS's IP;

## Caution
If you use a CDN, you need to disable it temporarily.
You can then enable it again after setup.

## Now just run commands below:
```
apt install -y unzip wget \
&& wget https://github.com/zmyxpt/debian-ss/archive/refs/heads/main.zip -O debian-ss.zip \
&& unzip debian-ss.zip \
&& rm debian-ss.zip \
&& cd debian-ss-main \
&& bash setup.sh
```
