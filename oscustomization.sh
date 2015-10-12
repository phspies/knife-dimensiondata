#!/usr/bin/env bash

VERSION="1.0"
OLD_HOSTNAME="$( hostname )"
DNSSERVERLIST="$2"
DNSDOMAIN="$3"

if [ -z "$NEW_HOSTNAME" ] || [ -z $DNSSERVERLIST] || [ -z $DNSDOMAIN ] ; then
 echo "Error: paramters are: [hostname] [comma seperate dns servers] [dns domain]"
 exit 1
fi


if [[ S1 == *"."* ]]; then
	NEW_HOSTNAME="$1"
else
	NEW_HOSTNAME="$1.$3"
fi



function dnsmethod1() {
	echo "#file created by Dimension Data customization script" > /etc/resolv.conf
	echo "" >> /etc/resolv.conf
	#Process DNS domain and servers
	IFS=',' read -a DNSLIST <<< "$DNSSERVERLIST"
	for DNSSERVER in "${DNSLIST[@]}"
	do
		echo "nameserver $DNSSERVER" >> /etc/resolv.conf
	done
	echo "domain $DNSDOMAIN" >> /etc/resolv.conf

	hostname "$NEW_HOSTNAME"
        
	sed -i "s/HOSTNAME=.*/HOSTNAME=$NEW_HOSTNAME/g" /etc/sysconfig/network
		
	OLD_SHORT_HOSTNAME="$( hostname )"
	OLD_LONG_HOSTNAME="$( hostname -f )"
		
	if [ -n "$( grep "$OLD_LONG_HOSTNAME" /etc/hosts )" ]; then
            sed -i "s/$OLD_LONG_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
    else
            echo -e "$( hostname -I | awk '{ print $1 }' )\t$NEW_HOSTNAME" >> /etc/hosts
    fi
	if [ -n "$( grep "$OLD_SHORT_HOSTNAME" /etc/hosts )" ]; then
            sed -i "s/$OLD_SHORT_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
    else
            echo -e "$( hostname -I | awk '{ print $1 }' )\t$NEW_HOSTNAME" >> /etc/hosts
    fi
}
function dnsmethod2() {

	OLD_SHORT_HOSTNAME="`hostname | cut -d"." -f1`"
	OLD_LONG_HOSTNAME="`hostname`"

	NEW_SHORT_HOSTNAME="`echo $NEW_HOSTNAME | cut -d"." -f1`"
	NEW_LONG_HOSTNAME=$NEW_HOSTNAME
	if [ -n "$( grep "$OLD_LONG_HOSTNAME" /etc/hosts )" ]; then
            sed -i "s/$OLD_LONG_HOSTNAME/$NEW_LONG_HOSTNAME/g" /etc/hosts
    else
            echo -e "$( hostname -I | awk '{ print $1 }' )\t$NEW_HOSTNAME" >> /etc/hosts
    fi
	if [ -n "$( grep "$OLD_SHORT_HOSTNAME" /etc/hosts )" ]; then
            sed -i "s/$OLD_SHORT_HOSTNAME/$NEW_SHORT_HOSTNAME/g" /etc/hosts
    else
            echo -e "$( hostname -I | awk '{ print $1 }' )\t$NEW_HOSTNAME" >> /etc/hosts
    fi

	DNSSERVERS=${DNSSERVERLIST/,/' '} 
	DNS="dns-nameservers $DNSSERVERS"
	sed -i 's/.*dns-nameservers.*/'"$DNS"'/g' /etc/network/interfaces

	hostname "$NEW_HOSTNAME"
        
	echo "$NEW_HOSTNAME" > /etc/hostname
		

}

if [ -r /etc/SuSE-release ] ; then
	OS="SUSE"
elif [ -r /etc/redhat-release ] ; then
	OS="Redhat"
elif [ -r /etc/os-release ] ; then
	OS="Ubuntu"
fi

echo "Dimension Data Customization Script: $VERSION"
echo "Detected $OS as the current operating system"
echo "Setting DNS name resolution to $DNSSERVERLIST"
echo "Setting DNS domain to $DNSDOMAIN"
echo "Changing hostname from $OLD_HOSTNAME to $NEW_HOSTNAME..."


if [[ "$OS" = "Ubuntu" ]] ; then
  dnsmethod2
else
  dnsmethod1
fi





