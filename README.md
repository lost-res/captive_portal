# Captive_Portal
Basic Captive Portal, redirects to single webpage on connecting to created Access Point. Very NOOB Freindly.

## 💡 Prerequisite
[Any Linux OS] Preferably `UBUNTU`
[Python 3](https://www.python.org/)
[kea-dhcp4-server](https://kea.isc.org/)
[lighttpd](https://www.lighttpd.net)
[hostapd](https://w1.fi/hostapd/)
[xterm]

## 🛠️ Installation

Install Prerequisites:

'''bash
sudo apt install python3 kea-dhcp4-server lighttpd hostapd xterm
'''

## 💻 Usage

1. CLone this repo:

'''bash 
git clone https://github.com/wilcodex/Captive_Portal.git
'''

2. Change to cloned directory and run `run.sh` :

'''bash
cd Captive_Portal
sudo ./run.sh -i "Access Point Interface" -s "SSID of AP" -c "AP Channel" -p "Password"
'''

> -i "Access Point Interface" -- Name of WiFi Interface of your machine. Default `wlan0` .
> -s "SSID" -- Name of WiFi Access Point to be seen to others. Default `My_Portal` .
> -c "Channel" -- Channel for WiFi Access Point. Default `5` .
> -p "Password" -- Password for the WiFi Access Point. By default No Password Protection. Omit `-p` to use default.

## 🛠️ Issues:

> Would Love to Reolve.

### Find Me on :
<p align="left">
  <a href="https://github.com/wilcodex" target="_blank"><img src="https://img.shields.io/badge/Github-HTR--TECH-green?style=for-the-badge&logo=github"></a>
