#!/bin/bash
for slot in $(dpdk-devbind -s | sed -n -r '/DPDK-compatible/,/kernel driver/p' | sed -n -r 's/^([0-9:.]+).*/\1/p'); do
  dpdk-devbind -u $slot
  sleep 1
  dpdk-devbind -b i40e $slot
done
for slot in $(dpdk-devbind -s | sed -n -r '/Other network/,$p' | sed -n -r 's/^([0-9:.]+).*/\1/p'); do
  dpdk-devbind -b i40e $slot
done
