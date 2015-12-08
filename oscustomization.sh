#!/usr/bin/env bash

VERSION="1.0"
OLD_HOSTNAME="$( hostname )"
NEW_HOSTNAME="$1"
DNSSERVERLIST="$2"
DNSDOMAIN="$3"

if [ -z "$NEW_HOSTNAME" ] || [ -z $DNSSERVERLIST ] || [ -z $DNSDOMAIN ] ; then
 echo "Error: paramters are: [hostname] [comma seperate dns servers] [dns domain]"
 exit 1
fi

function dnsmethod1() {
	echo "#file created by Dimension Data customization script" > /etc/resolv.conf
	echo "" >> /etc/resolv.conf
	IFS=',' read -a DNSLIST <<< "$DNSSERVERLIST"
	for DNSSERVER in "${DNSLIST[@]}"
	do
		echo "nameserver $DNSSERVER" >> /etc/resolv.conf
	done
	echo "domain $DNSDOMAIN" >> /etc/resolv.conf
	sed -i "s/HOSTNAME=.*/HOSTNAME=$NEW_SHORT_HOSTNAME/g" /etc/sysconfig/network
	echo "$NEW_LONG_HOSTNAME" > /etc/hostname
}
function dnsmethod2() {
	DNSSERVERS=${DNSSERVERLIST/,/' '}
	DNS="dns-nameservers $DNSSERVERS"
	sed -i 's/.*dns-nameservers.*/'"$DNS"'/g' /etc/network/interfaces
	echo "$NEW_LONG_HOSTNAME" > /etc/hostname
}
function dnsmethod3() {
	echo "#file created by Dimension Data customization script" > /etc/resolv.conf
	echo "" >> /etc/resolv.conf
	IFS=',' read -a DNSLIST <<< "$DNSSERVERLIST"
	for DNSSERVER in "${DNSLIST[@]}"
	do
		echo "nameserver $DNSSERVER" >> /etc/resolv.conf
	done
	echo "domain $DNSDOMAIN" >> /etc/resolv.conf
	echo "$NEW_LONG_HOSTNAME" > /etc/HOSTNAME
	echo "$NEW_LONG_HOSTNAME" > /etc/hostname
}

issue_file="/etc/issue"
if grep "SUSE" $issue_file; then
    OS="SUSE"
elif grep "Red Hat" $issue_file; then
    OS="Redhat"
elif grep "Redhat" $issue_file; then
    OS="Redhat"
elif grep "Ubuntu" $issue_file; then
    OS="Ubuntu"
fi
NEW_SHORT_HOSTNAME="$1"
NEW_LONG_HOSTNAME="$1.$3"
IP=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`

echo "Dimension Data Customization Script: $VERSION"
echo "Detected $OS as the current operating system"
echo "Setting DNS name resolution to $DNSSERVERLIST"
echo "Setting DNS domain to $DNSDOMAIN"
echo "Changing hostname from $OLD_HOSTNAME to $NEW_HOSTNAME..."

if [[ "$OS" = "Ubuntu" ]] ; then
  dnsmethod2
elif [[ "$OS" = "SUSE" ]] ; then
  dnsmethod3
else
  dnsmethod1
fi

chattr -i /etc/hosts
`sed -i "/$IP/d" /etc/hosts`
echo -e "$IP \t$NEW_LONG_HOSTNAME $NEW_SHORT_HOSTNAME" >> /etc/hosts

