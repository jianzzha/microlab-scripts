#!/bin/bash

set -x

# below commands are for configuration output capture

vppctl show interface

vppctl show interface address

vppctl show hardware

# baremetal bridged packet forwarding
#vppctl show bridge 1 detail

# KVM guest bridged packet forwarding
#vppctl show bridge 10 detail
#vppctl show bridge 20 detail

vppctl show threads

vppctl show dpdk interface placement

vppctl show vhost-user

vppctl show run
