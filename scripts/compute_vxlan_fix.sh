#!/bin/bash
local_ip=$(ovs-vsctl show | grep remote_ip | sed -n -r 's/.*local_ip=\"([0-9.]+)\".*/\1/p')
if ! ip a show br-link0 | grep ${local_ip}; then
  ip link set up dev br-link0
  ip a add ${local_ip}/24 dev br-link0
  systemctl restart neutron-openvswitch-agent
fi

