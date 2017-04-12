#!/bin/bash

service vpp stop

service vpp start

vppctl set interface state GigabitEthernet0/7/0 up
vppctl set interface state GigabitEthernet0/8/0 up

vppctl set interface ip address GigabitEthernet0/7/0 192.168.1.1/24
vppctl set interface ip address GigabitEthernet0/8/0 192.168.2.1/24
