#!/bin/bash
if [[ $# -lt 1 ]]; then
  echo "usuage $0 <if1> <if2> <..>"
  exit 1
fi

modprobe vfio
modprobe vfio_pci

while [[ $# -gt 0 ]]; do
  ifname=$1
  shift

  if ! ip link show $ifname > /dev/null; then
    echo "can't find businfo for $ifname, maybe invalid name or not in kernel"
    continue
  fi

  echo "Binding devices $ifname to vfio-pci/DPDK"
  
  businfo=`ethtool -i $ifname | grep 'bus-info' | awk '{print $2}'`
  ifconfig $ifname down
  sleep 1
  dpdk-devbind -u $ifname
  sleep 1
  dpdk-devbind -b vfio-pci $businfo
done

dpdk-devbind --status
 
