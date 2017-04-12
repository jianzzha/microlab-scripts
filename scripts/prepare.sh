#!/bin/bash

#set -x
source /root/overcloudrc || exit 1

if ! ip a show br-p2p1 | egrep "10.1.1.1/24"; then
  echo "config 10.1.1.1/24 on br-p2p1"
  ip a add 10.1.1.1/24 dev br-p2p1
  ip link set up dev br-p2p1
fi

if ovs-vsctl show | grep em1; then
  echo "remove em1 from br-link0"
  ovs-vsctl del-port em1
fi

if ! lsmod | grep vfio_pci; then
  echo "loading vfio and vfio_pci"
  modprobe vfio
  modprobe vfio_pci
fi

if ! ip link show em1 2> /dev/null; then
  echo "can't find em1, 01:00.0 must be binded to vfio_pci"
else
  dpdk-devbind -u 01:00.0
  dpdk-devbind -b vfio-pci 01:00.0
fi

vm_eth1_mac=$(neutron port-list | grep 192.168.0. | awk -F'|' '{print $4}' | awk '{print $1}')
echo "vm mac: ${vm_eth1_mac}"

local_ip=$(ovs-vsctl show | grep remote_ip | sed -n -r 's/.*local_ip=\"([0-9.]+)\".*/\1/p')
remote_ip=$(ovs-vsctl show | grep remote_ip | sed -n -r 's/.*remote_ip=\"([0-9.]+)\".*/\1/p')
echo "vxlan local_ip: ${local_ip}; remote_ip: ${remote_ip}"

vni=$(neutron net-show provider-nfv0 | grep provider:segmentation_id | awk -F'|' '{print $3}' | awk '{print $1}')
echo "vni: $vni"

echo "building run_txrx.sh"

cat >run_txrx.sh <<EOF
#!/bin/bash
./MoonGen/build/MoonGen txrx.lua --devices=0,0 --measureLatency=0 --rate=0.1 --size=64 --runTime=10 \
 --bidirectional=0 --vxlanIds=${vni},${vni} --srcIps=${local_ip},${local_ip} \
 --dstIps=${remote_ip},${remote_ip} --dstMacs=ec:f4:bb:ce:be:a8,ec:f4:bb:ce:be:a8 \
 --encapSrcIps=192.168.100.2,192.168.101.2 --encapDstIps=192.168.100.1,192.168.101.1 \
 --encapSrcMacs=9e:e9:96:e4:76:02,9e:e9:96:e4:76:02 --encapDstMacs=${vm_eth1_mac},${vm_eth1_mac}
EOF

chmod 0777 run_txrx.sh

echo "building run_binarysearch.sh"
cat >run_binarysearch.sh <<EOF
#!/bin/bash
./binary-search.py --rate=3 --search-runtime=30 --validation-runtime=120 --frame-size=64 \
 --use-src-ip-flows=0 --use-dst-ip-flows=0 --use-src-mac-flows=0 --use-dst-mac-flows=0 \
 --use-encap-src-ip-flows=0 --use-encap-dst-ip-flows=0 --use-encap-src-mac-flows=0 \
 --use-encap-dst-mac-flows=0  --vxlan-ids-list=${vni},${vni} \
 --encap-src-ips-list=192.168.100.2,192.168.101.2 \
 --encap-dst-ips-list=192.168.100.1,192.168.101.1 \
 --encap-src-macs-list=9e:e9:96:e4:76:02,9e:e9:96:e4:76:02 \
 --encap-dst-macs-list=${vm_eth1_mac},${vm_eth1_mac} \
 --run-bidirec=0 --dst-ips-list=${remote_ip},${remote_ip} --src-ips-list=${local_ip},${local_ip} \
 --dst-macs-list=ec:f4:bb:ce:be:a8,ec:f4:bb:ce:be:a8  --traffic-generator=moongen-txrx
EOF

chmod 0777 run_binarysearch.sh

