# EvilAP
EvilAP is a script that allows to create a fake access point and bypass HTTPS/HSTS using dns2proxy and sslstrip2. Use this script only with Kali Linux 2.0.

## Packages needed:

###### Install sslstrip2 (do these commands in your home directory):
>git clone https://github.com/LeonardoNve/sslstrip2.git
>chmod +x sslstrip.py

##### Install dns2proxy (do these commands in your home directory):
>git clone https://github.com/LeonardoNve/dns2proxy.git
>chmod +x dns2proxy.py
  
All others packages needed are already installed in Kali Linux, make sure you’ve already upgrade these packages:
>apt-get update
>apt-get upgrade

Make sure you have an interface connected to internet and an other wireless interface.
