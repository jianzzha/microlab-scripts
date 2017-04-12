#/bin/bash

echo "empty .ssh/known_hosts"
> $HOME/.ssh/known_hosts 

echo "fix compute-0 setup to establish vxlan"
ssh root@compute-0 'bash -s' < scripts/compute_vxlan_fix.sh

imagefile=/home/stack/nfv.qcow2
imagename=nfv

source /home/stack/with-dpdk/overcloudrc

if ! openstack image list | grep ${imagename}; then
  openstack image create --disk-format qcow2 --container-format bare   --public --file ${imagefile} ${imagename} || exit 1
fi

nova keypair-list | grep 'demo-key' || nova keypair-add --pub-key ~/.ssh/id_rsa.pub demo-key
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0 
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0

if ! openstack flavor list | grep nfv; then 
  openstack flavor create nfv --id 1 --ram 4096 --disk 500 --vcpus 4
  nova flavor-key 1 set hw:cpu_policy=dedicated
  nova flavor-key 1 set hw:mem_page_size=1GB
fi

if ! neutron net-list | grep access; then
  neutron net-create access --provider:network_type flat  --provider:physical_network access
  neutron subnet-create --name access --dns-nameserver 10.35.28.28 access 10.1.1.0/24
fi

#if ! neutron net-list | grep private; then
#  neutron net-create private
#  neutron subnet-create --name private --dns-nameserver 10.35.28.28 private 10.0.0.0/24
#fi

if ! neutron net-list | grep provider-nfv0; then
  neutron net-create  provider-nfv0 --provider:network_type vxlan --port_security_enabled=False
  sleep 1
  neutron subnet-create --name provider-nfv0 --disable-dhcp --gateway 192.168.0.254 provider-nfv0 192.168.0.0/24
fi

#if ! neutron net-list | grep provider-nfv1; then
#  neutron net-create  provider-nfv1 --provider:network_type flat --provider:physical_network dpdk1 --port_security_enabled=False
#  sleep 1
#  neutron subnet-create --name provider-nfv1 --disable-dhcp --gateway 192.168.1.254 provider-nfv1 192.168.1.0/24
#fi

neutron net-list > tmpfile
#private=$(cat tmpfile | grep private | awk -F'|' '{print $2}' | awk '{print $1}')

access=$(cat tmpfile | grep access | awk -F'|' '{print $2}' | awk '{print $1}')

provider1=$(cat tmpfile | grep provider-nfv0 | awk -F'|' '{print $2}' | awk '{print $1}')
#provider2=$(cat tmpfile | grep provider-nfv1 | awk -F'|' '{print $2}' | awk '{print $1}')

echo excuting "nova boot --flavor nfv --image ${imagename} --nic net-id=$private --nic net-id=$provider1 --nic net-id=$provider2 --key-name demo-key demo1"
nova boot --flavor nfv --image ${imagename} --nic net-id=$access --nic net-id=$provider1 --key-name demo-key demo1 

if [[ $? -ne 0 ]]; then
  echo "VM start immediately failed"
  exit 1
fi

echo "demo1 started, wait for active status"

for n in {0..100}; do
  sleep 6
  if nova list | grep demo1 | egrep 'ACTIVE|ERROR' ; then
    break
  fi
done

if ! nova list | grep demo1 | egrep 'ACTIVE'; then
  echo "failed to start VM"
  exit 1
fi
   
vm_ip=$(nova list | sed -n -r 's/.*(demo[0-9]+).*access=([.0-9]+).*/\2/ p')
vm_num=$(nova list | grep demo | wc -l)

source /home/stack/stackrc
control_ip=$(nova list | sed -r -n 's/.*(controller-[0-9]+).*ctlplane=([0-9.]+).*/\2/p')
    
echo "record all VM's access info for ansible"
echo "[VMs]" > VMs
echo "demo1 ansible_host=${control_ip} ansible_port=2222"  >> VMs

cat <<EOF >>VMs
[all:vars]
ansible_connection=ssh 
ansible_user=root 
ansible_ssh_pass=100yard-
EOF
echo vm_num=$vm_num >>VMs
echo "stack_key=\"$(sudo cat /home/stack/.ssh/id_rsa.pub)\"" >> VMs
echo "root_key=\"$(sudo cat /root/.ssh/id_rsa.pub)\"" >> VMs

echo "setup controller"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${control_ip} "sudo sh -c '\
ip a del 10.1.1.1/24 dev br-p2p1 2>/dev/null; \
ip a add 10.1.1.1/24 dev br-p2p1; \
ip link set up dev br-p2p1; \
echo 1 > /proc/sys/net/ipv4/ip_forward; \
iptables -t nat -D PREROUTING 2 2>/dev/null; \
iptables -t nat -D POSTROUTING 3 2>/dev/null; \
iptables -D FORWARD 5 2>/dev/null; \
iptables -t nat -I PREROUTING 2 -p tcp --dport 2222 -j DNAT --to ${vm_ip}:22; \
iptables -t nat -I POSTROUTING 3 -o br-ex -j MASQUERADE; \
sed -i \"/demo1/d\" /etc/hosts 2>/dev/null; \
echo \"${vm_ip}  demo1\" >> /etc/hosts; \
'"
[ $? -eq 0 ] || exit 1
echo "setup VM"
for (( count=0; count<5; count++ )); do
  sleep 5
  ! ansible-playbook -i VMs microlab_vm.yml || break
done
