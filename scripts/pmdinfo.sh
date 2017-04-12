#!/bin/bash
declare -A core_pmd_map
declare -A pmd_port_map

ovs_pid=`pgrep ovs-vswitchd`
for i in `/bin/ls /proc/$ovs_pid/task`; do
  if grep -q pmd /proc/$ovs_pid/task/$i/stat; then
    core=$(taskset -pc $i | sed -n -r 's/.* list: ([0-9]+)/\1/p')
    core_pmd_map["$core"]=$i
  fi
done

if [ -f pmd_port_map ]; then
  . pmd_port_map
else
for core in $(ovs-appctl dpif-netdev/pmd-rxq-show | grep "pmd thread" | sed -n -r 's/.*core_id ([0-9]+):.*/\1/p'); do
  port=$(ovs-appctl dpif-netdev/pmd-rxq-show | grep -A 3 "core_id ${core}:" | sed -n -r 's/.*port: (\S+).*/\1/p')
  pmd_port_map["${core_pmd_map[$core]}"]=$port
  echo pmd_port_map["${core_pmd_map[$core]}"]=$port >> pmd_port_map
done
fi

for core in ${!core_pmd_map[@]}; do
  echo "port: ${pmd_port_map["${core_pmd_map[$core]}"]}, core: ${core}, pmd: ${core_pmd_map["$core"]}"
done

