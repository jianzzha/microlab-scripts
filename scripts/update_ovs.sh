#!/bin/bash

wget http://download-node-02.eng.bos.redhat.com/brewroot/packages/openvswitch/2.6.1/3.git20161206.el7fdb/x86_64/openvswitch-2.6.1-3.git20161206.el7fdb.x86_64.rpm || exit 1
yum -y install openvswitch-2.6.1-3.git20161206.el7fdb.x86_64.rpm || exit 1

sed 's/SELINUX=enforcing/SELINUX=permissive/g' -i /etc/selinux/config
if [ -f /usr/lib/systemd/system/openvswitch-nonetwork.service ]; then
  ovs_service_path="/usr/lib/systemd/system/openvswitch-nonetwork.service"
elif [ -f /usr/lib/systemd/system/ovs-vswitchd.service ]; then
  ovs_service_path="/usr/lib/systemd/system/ovs-vswitchd.service"
fi
grep -q "RuntimeDirectoryMode=.*" $ovs_service_path
if [ "$?" -eq 0 ]; then
  sed -i 's/RuntimeDirectoryMode=.*/RuntimeDirectoryMode=0775/' $ovs_service_path
else
  echo "RuntimeDirectoryMode=0775" >> $ovs_service_path
fi
  grep -Fxq "Group=qemu" $ovs_service_path
if [ ! "$?" -eq 0 ]; then
  echo "Group=qemu" >> $ovs_service_path
fi
grep -Fxq "UMask=0002" $ovs_service_path
if [ ! "$?" -eq 0 ]; then
  echo "UMask=0002" >> $ovs_service_path
fi
ovs_ctl_path='/usr/share/openvswitch/scripts/ovs-ctl'
grep -q "umask 0002 \&\& start_daemon \"\$OVS_VSWITCHD_PRIORITY\"" $ovs_ctl_path
if [ ! "$?" -eq 0 ]; then
  sed -i 's/start_daemon \"\$OVS_VSWITCHD_PRIORITY.*/umask 0002 \&\& start_daemon \"$OVS_VSWITCHD_PRIORITY\" \"$OVS_VSWITCHD_WRAPPER\" \"$@\"/' $ovs_ctl_path
fi

tuned_service=/usr/lib/systemd/system/tuned.service
grep -q "network.target" $tuned_service
if [ "$?" -eq 0 ]; then
  sed -i '/After=.*/s/network.target//g' $tuned_service
fi
grep -q "Before=.*network.target" $tuned_service
if [ ! "$?" -eq 0 ]; then
  grep -q "Before=.*" $tuned_service
  if [ "$?" -eq 0 ]; then
    sed -i 's/^\(Before=.*\)/\1 network.target openvswitch.service/g' $tuned_service
  else
    sed -i '/After/i Before=network.target openvswitch.service' $tuned_service
  fi
fi

