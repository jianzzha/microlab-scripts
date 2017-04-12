#!/bin/bash
# based on a provision network name, find the vm ip address on that provision network
# find the port based on that vm ip; disable security on that port
# take a list of input of provision network name

source /home/stack/templates/overcloudrc

get_port_id () {
   port_id=$(neutron port-list | grep $1 | awk  '{print $2}')
}

for network in "$@"
do
  nova list | sed -n -r "/.*$network=([.0-9]+).*/\1/p"


get_port_id ${vm_ip}
neutron port-update --no-security-groups $port_id
done
