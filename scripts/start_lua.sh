#!/bin/bash
# usage cmd <VM1> <VM2>

execcmd=$0

if (( $# < 4 )); then
  echo "invalide argument count $#"
  echo "usage $execcmd --src <1st VM> --dst <2nd VM>"
  exit 1
fi

while [[ $# -gt 1 ]]
do
key="$1"
case $key in
  --src)
  src=$2
  shift
  ;;
  --dst)
  dst=$2
  shift
  ;;
  *)
  echo "Usage: $execcmd --src <1st VM> --dst <2nd VM>"
  exit 1
  ;;
esac
shift
done

./set.sh em3 em4 || exit 1

source ../vars/${src}_macs || exit 1
mac1=$(eval echo \${${src}_mac1})

source ../vars/${dst}_macs || exit 1
mac2=$(eval echo \${${dst}_mac2})

num1=$(echo $src | sed -r -n 's/demo([0-9]+)/\1/p')
num2=$(echo $dst | sed -r -n 's/demo([0-9]+)/\1/p')

cd /root/lua-trafficgen
if ((num1 % 2)); then
  ./MoonGen/build/MoonGen ./txrx.lua --size=64 --devices=0,1 --runTime=15 --srcIps=192.168.$((num1-1)).100,192.168.$num2.100 --dstIps=192.168.$num2.100,192.168.$((num1-1)).100 --dstMacs=$mac1,$mac2 --calibrateTxRate=0 --vlanIds=$((100+num1-1)),$((100+num2)) --flowMods="" --bidirectional=1  --rate=2
else
  ./MoonGen/build/MoonGen ./txrx.lua --size=64 --devices=1,0 --runTime=15 --srcIps=192.168.$((num1-1)).100,192.168.$num2.100 --dstIps=192.168.$num2.100,192.168.$((num1-1)).100 --dstMacs=$mac1,$mac2 --calibrateTxRate=0 --vlanIds=$((100+num1-1)),$((100+num2)) --flowMods="" --bidirectional=1  --rate=2
fi

