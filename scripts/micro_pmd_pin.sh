#!/bin/bash
set -x

# accessCore: access core; p1Core: data port 1 core; v1Core: p1 VM port; 
accessCore=1
p1Core=2
v1Core=26
p2Core=4
v2Core=28
coreList="$accessCore,$p1Core,$p2Core,$v1Core,$v2Core"
accessPort=dpdk2
p1Port=dpdk0
p2Port=dpdk1

get_core_mask()
{
 list=$1
 declare -a bm
 bm=(0 0 0 0 0 0 0 0 0 0)
 max_idx=0
 for core in $(echo $list | sed 's/,/ /g')
 do
     index=$(($core/32))
     temp=$((1<<$core))
     bm[$index]=$((${bm[$index]} | $temp))
     if [ $max_idx -lt $index ]; then
        max_idx=$index
     fi
 done
 printf -v core_mask "%x" "${bm[$max_idx]}"
 for ((i=$max_idx-1;i>=0;i--));
 do
     printf -v hex "%08x" "${bm[$i]}"
     core_mask+=$hex
 done
 return 0
}

get_core_mask ${coreList}
ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=$core_mask

vm=`virsh list | grep running | awk '{print $2}'`
if [ ! -z "$vm" ]; then
  echo found vm: $vm
  # v0Port is the VM access
  v0Port=`virsh dumpxml $vm | grep /var/run/openvswitch | sed -n '1p' | awk -F\' '{print $4}' | sed -e sX/var/run/openvswitch/XX`
  v1Port=`virsh dumpxml $vm | grep /var/run/openvswitch | sed -n '2p' | awk -F\' '{print $4}' | sed -e sX/var/run/openvswitch/XX`
  v2Port=`virsh dumpxml $vm | grep /var/run/openvswitch | sed -n '3p' | awk -F\' '{print $4}' | sed -e sX/var/run/openvswitch/XX`

  if [ ! -z "$v0Port" ]; then
    ovs-vsctl set Interface $accessPort other_config:pmd-rxq-affinity="0:$accessCore"
    ovs-vsctl set Interface $v0Port other_config:pmd-rxq-affinity="0:$accessCore"
  fi
  if [ ! -z "$v1Port" ]; then
    ovs-vsctl set Interface $p1Port other_config:pmd-rxq-affinity="0:$p1Core"
    ovs-vsctl set Interface $v1Port other_config:pmd-rxq-affinity="0:$v1Core"
  fi
  if [ ! -z "$v2Port" ]; then
    ovs-vsctl set Interface $p2Port other_config:pmd-rxq-affinity="0:$p2Core"
    ovs-vsctl set Interface $v2Port other_config:pmd-rxq-affinity="0:$v2Core"
  fi
fi
ovs-appctl dpif-netdev/pmd-rxq-show 
