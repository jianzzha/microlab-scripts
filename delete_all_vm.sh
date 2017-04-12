#!/bin/bash
source /home/stack/with-dpdk/overcloudrc
echo "delete instances"
for id in $(nova list | egrep 'demo|rhel' | awk -F'|' '{print $2}' | awk '{print $1}'); do
   nova delete $id
done

sleep 3
echo "delete unused ports"
for id in $(neutron port-list | grep ip_address | egrep -v '10.1.1.1|10.1.1.2|10.0.0.2|10.0.0.1' | awk -F'|' '{print $2}' | awk '{print $1}'); do
   neutron port-delete $id
done

sleep 3
echo "delete subnets"
for id in $(neutron subnet-list | egrep 'provider|private|access' | awk -F'|' '{print $2}' | awk '{print $1}'); do
   neutron subnet-delete $id
done

sleep 1
echo "delete nets"
for id in $(neutron net-list | egrep 'provider|private|access' | awk -F'|' '{print $2}' | awk '{print $1}'); do
   neutron net-delete $id
done


