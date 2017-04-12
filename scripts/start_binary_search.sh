#!/bin/bash
# usage cmd <VM1> <VM2>

prefix="demo"

execcmd=$0

function usuage() {
  echo "usage $execcmd <1st VM num> <2nd VMi num>"
  echo "Example: $execcmd 1 3"
  exit 1
}


if (( $# != 2 )); then
  echo "invalide argument count $#"
  usuage
fi

if [ "$1" -eq "$1" ] 2>/dev/null; then
  num1=$1
else
  usuage
fi

if [ "$2" -eq "$2" ] 2>/dev/null; then
  num2=$2
else
  usuage
fi

if (( num1 > num2 )); then
  echo "1st vm number can't be greater than 2nd vm number!"
  usuage
fi

./set.sh em3 em4 || exit 1

src=${prefix}${num1}
dst=${prefix}${num2}

source ../vars/${src}_macs || exit 1
mac1=$(eval echo \${${src}_mac1})

source ../vars/${dst}_macs || exit 1
mac2=$(eval echo \${${dst}_mac2})

cd /root/lua-trafficgen
if ((num1 % 2)); then
  ./binary-search.py --frame-size=64 --use-ip-flows=0 --use-mac-flows=0 --run-bidirec=1 --search-runtime=30 --validation-runtime=60 --rate=4 --src-ips-list=192.168.$((num1-1)).100,192.168.$num2.100 --dst-ips-list=192.168.$num2.100,192.168.$((num1-1)).100 --dst-macs-list=$mac1,$mac2 --vlan-ids-list=$((100+num1-1)),$((100+num2))
else
  ./binary-search.py --frame-size=64 --use-ip-flows=0 --use-mac-flows=0 --run-bidirec=1 --search-runtime=30 --validation-runtime=60 --rate=4 --src-ips-list=192.168.$num2.100,192.168.$((num1-1)).100 --dst-ips-list=192.168.$((num1-1)).100,192.168.$num2.100 --dst-macs-list=$mac2,$mac1 --vlan-ids-list=$((100+num2)),$((100+num1-1))
fi

