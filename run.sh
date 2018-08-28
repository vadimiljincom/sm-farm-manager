#!/bin/bash

if [ "$2" = "" ]; then
	echo "usage: $0 <hostname> <script> [argument] [...]"
	exit 1
elif [ ! -f $2 ]; then
	echo "error: file $2 not found"
	exit 1
fi

query=$1
script="`realpath $2`"
shift
shift

server=`/opt/farm/ext/farm-manager/internal/lookup-server.sh $query`

if [[ $server =~ ^[a-z0-9.-]+$ ]]; then
	server="$server::"
elif [[ $server =~ ^[a-z0-9.-]+[:][0-9]+$ ]]; then
	server="$server:"
fi

host=$(echo $server |cut -d: -f1)
port=$(echo $server |cut -d: -f2)
tag=$(echo $server |cut -d: -f3)

if [ "$port" = "" ]; then
	port=22
fi

if [ -x /etc/local/hooks/ssh-accounting.sh ] && [ "$tag" != "" ]; then
	/etc/local/hooks/ssh-accounting.sh start $tag
fi

sshkey=`/opt/farm/ext/keys/get-ssh-management-key.sh $host`
remote="`dirname $script`"

ssh -i $sshkey -p $port -o StrictHostKeyChecking=no root@$host mkdir -p $remote

if [[ $? = 0 ]]; then
	scp -i $sshkey -P $port $script root@$host:$remote
	ssh -i $sshkey -p $port -t root@$host "sh -c '$script $@'"
fi

if [ -x /etc/local/hooks/ssh-accounting.sh ] && [ "$tag" != "" ]; then
	/etc/local/hooks/ssh-accounting.sh stop $tag
fi
