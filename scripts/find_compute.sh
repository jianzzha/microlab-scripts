#!/bin/bash

# this script find the node name and console info based on vm name in the form of demo<n>

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <vm>"
  exit 1
fi

vm=$1
source /home/stack/templates/overcloudrc || exit 1
compute=$(nova show $vm | grep hypervisor_hostname | sed -r -n 's/.*(compute-[0-9]+).*/\1/p')

source /home/stack/stackrc || exit 1
novaid=$(nova list | sed -n -r "s/[ |]*([0-9a-f\-]+).*$compute.*/\1/p")
ctladd=$(nova list | sed -n -r "s/.*$compute.*ctlplane=([0-9.]+).*/\1/p")
echo "$compute, address=$ctladd"

ironicid=$(ironic node-list | grep $novaid | sed -r -n "s/^[ |]*([0-9a-f\-]+).*/\1/p")
ironic node-show $ironicid | grep -A 1 ipmi_address

