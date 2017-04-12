#!/bin/bash

PMD_CORES='2,4,6,8,10,1'
SOCKET_MEMORY='1024,1024'

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

get_core_mask $PMD_CORES
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem=$SOCKET_MEMORY
ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=$core_mask
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask=0x1

systemctl daemon-reload
systemctl restart openvswitch
systemctl restart neutron-openvswitch-agent

