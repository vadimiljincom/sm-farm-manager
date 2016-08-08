#!/bin/bash
. /opt/farm/scripts/functions.custom

PH=0
VM=0
VZ=0
LXC=0
DCK=0
XEN=0
WKS=0
EC2=0
PRB=0
DEF=1
command=$@

if [ "$1" = "" ]; then
	echo "usage: $0 [-ph] [-vm] [-vz] [-lxc] [-dck] [-wks] [-ec2] [-prb] command argument(s)"
	exit 1
fi

while [ "$1" = "-ph" ] || [ "$1" = "-vm" ] || [ "$1" = "-vz" ] || [ "$1" = "-lxc" ] || [ "$1" = "-dck" ] || [ "$1" = "-xen" ] || [ "$1" = "-wks" ] || [ "$1" = "-ec2" ] || [ "$1" = "-prb" ]; do
	DEF=0
	if   [ "$1" = "-ph" ]; then PH=1
	elif [ "$1" = "-vm" ]; then VM=1
	elif [ "$1" = "-vz" ]; then VZ=1
	elif [ "$1" = "-lxc" ]; then LXC=1
	elif [ "$1" = "-dck" ]; then DCK=1
	elif [ "$1" = "-xen" ]; then XEN=1
	elif [ "$1" = "-wks" ]; then WKS=1
	elif [ "$1" = "-ec2" ]; then EC2=1
	elif [ "$1" = "-prb" ]; then PRB=1
	fi
	shift
	command=$@
done

# default behaviour, when no -xx switches are used: execute command only on virtual machines
if [ $DEF = 1 ]; then
	VM=1
fi


connect_loop() {
	for server in `cat /etc/local/.farm/$2`; do

		if [ -z "${server##*:*}" ]; then
			host="${server%:*}"
			port="${server##*:}"
		else
			host=$server
			port=22
		fi

		sshkey="`ssh_management_key_storage_filename $host`"
		echo
		echo "####### executing \"$1\" on $3 $server"
		ssh -t -i $sshkey -p $port -o StrictHostKeyChecking=no root@$host "$1"
	done
}

if [ $EC2 = 1 ]; then connect_loop "$command" ec2.hosts "Amazon EC2 instance"; fi
if [ $WKS = 1 ]; then connect_loop "$command" workstation.hosts "workstation"; fi
if [ $PRB = 1 ]; then connect_loop "$command" problematic.hosts "problematic server"; fi
if [ $PH = 1 ]; then connect_loop "$command" physical.hosts "physical server"; fi
if [ $VM = 1 ]; then connect_loop "$command" virtual.hosts "virtual server"; fi
if [ $LXC = 1 ]; then connect_loop "$command" lxc.hosts "LXC container"; fi

if [ $VZ = 1 ]; then
	for server in `cat /etc/local/.farm/openvz.hosts`; do

		if [ -z "${server##*:*}" ]; then
			host="${server%:*}"
			port="${server##*:}"
		else
			host=$server
			port=22
		fi

		sshkey="`ssh_management_key_storage_filename $host`"
		containers="`ssh -i $sshkey -p $port root@$host \"/usr/sbin/vzlist -Ho ctid\"`"

		for ID in $containers; do
			cthost="`ssh -i $sshkey -p $port root@$host \"/usr/sbin/vzlist -Ho hostname $ID\"`"
			echo
			echo "####### executing \"$command\" on container $ID [$cthost] at server $server"
			ssh -t -i $sshkey -p $port root@$host "/usr/sbin/vzctl exec $ID \"TERM=vt100 $command\""
		done
	done
fi

if [ $XEN = 1 ]; then echo "skipping Xen containers; not implemented yet"; fi
if [ $DCK = 1 ]; then echo "skipping Docker containers; not implemented yet"; fi
