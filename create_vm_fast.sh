#/bin/bash
# create n Vms, n specified by the first augument

if [[ $# -ne 1 ]]; then
  echo "Usuage: $0 <number of instances to create>"
  exit 1
fi

num_vm=$1
errorlog=vmStart.log

# truc the logfile
> $errorlog

source /home/stack/templates/overcloudrc

#update nova quota to allow more core use and more network
project_id=$(openstack project show -f value -c id admin)
nova quota-update --instances $num_vm $project_id
nova quota-update --cores $(( $num_vm * 4 )) $project_id
neutron quota-update --tenant_id $project_id --network $(( $num_vm + 2 ))
neutron quota-update --tenant_id $project_id --subnet $(( $num_vm + 2 ))

if ! openstack image list | grep rhelsnapshot; then
  openstack image create --disk-format qcow2 --container-format bare   --public --file /home/stack/rhelsnapshot.raw rhelsnapshot || exit 1
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

for i in $(eval echo "{0..$num_vm}"); do
  neutron net-create provider-nfv$i --provider:network_type vlan --provider:physical_network dpdk$(($i % 2)) --provider:segmentation_id $((100 + $i)) --port_security_enabled=False
  sleep 1
  neutron subnet-create --name provider-nfv$i --disable-dhcp --gateway 192.168.$i.254 provider-nfv$i 192.168.$i.0/24
done

neutron net-list > tmpfile
access=$(cat tmpfile | grep access | awk -F'|' '{print $2}' | awk '{print $1}')
declare -a providers
declare -a vmState
declare -a retries
declare -a duration
declare -a port

for i in $(eval echo "{1..$num_vm}"); do
  provider1=$(cat tmpfile | grep provider-nfv$((i - 1)) | awk -F'|' '{print $2}' | awk '{print $1}')
  provider2=$(cat tmpfile | grep provider-nfv$i | awk -F'|' '{print $2}' | awk '{print $1}')
  echo excuting "nova boot --flavor nfv --image rhelsnapshot --nic net-id=$access --nic net-id=$provider1 --nic net-id=$provider2 --key-name demo-key demo$i"
    nova boot --flavor nfv --image rhelsnapshot --nic net-id=$access --nic net-id=$provider1 --nic net-id=$provider2 --key-name demo-key demo$i
  if [[ $? -ne 0 ]]; then
    echo "VM start immediately failed"
    nova show demo$i >> $errorlog
    exit 1
  fi
  echo "demo$i started, wait for active status"
  providers[$((i-1))]=$provider1
  providers[$i]=$provider2
  vmState[$i]=0
  retries[$i]=0
  duration[$i]=0
done

# check to make sure all VM complete with ACTIVE
for n in {0..1000}; do
  sleep 3
  nova list > tmpfile
  completed=1
  for i in $(eval echo "{1..$num_vm}"); do
    if [ ${vmState[$i]} -ne 1 ]; then
      if grep demo$i tmpfile | egrep 'ACTIVE'; then
        vmState[$i]=1
      elif grep demo$i tmpfile | egrep 'ERROR'; then
        completed=0
        nova show demo$i >> $errorlog
        if [ ${retries[$i]} -lt 10 ]; then
          intcount=0
          for pID in $(nova interface-list demo$i | egrep '10.1|192.168' | awk -F'|' '{print $3}' | awk '{print $1}'); do
            port[$intcount]=$pID
            ((++intcount))
          done
          nova delete demo$i
          sleep 2
          for ((k=0; k<$intcount; k++)); do
            neutron port-delete ${port[$k]} 2>/dev/null
            sleep 1
          done
          nova boot --flavor nfv --image rhelsnapshot --nic net-id=$access --nic net-id=${providers[((i-1))]} --nic net-id=${providers[$i]} --key-name demo-key demo$i
          ((++retries[$i]))
          duration[$i]=0
        else
          echo failed to start instance demo$i for ${retries[$i]} times
          exit 1
        fi
      else
        completed=0
        ((++duration[$i]))
        if [ ${duration[$i]} -gt 200 ]; then
        # this instance took 600s not completed, let's kill and restart it
          intcount=0
          for pID in $(nova interface-list demo$i | egrep '10.1|192.168' | awk -F'|' '{print $3}' | awk '{print $1}'); do
            port[$intcount]=$pID
            ((++intcount))
          done
          nova delete demo$i
          sleep 2
          for ((k=0; k<$intcount; k++)); do
            neutron port-delete ${port[$k]} 2>/dev/null
            sleep 1
          done
          nova boot --flavor nfv --image rhelsnapshot --nic net-id=$access --nic net-id=${providers[((i-1))]} --nic net-id=${providers[$i]} --key-name demo-key demo$i
        fi
      fi
    fi
  done
  if [ $completed -eq 1 ]; then
    break
  fi
done

if [ $completed -ne 1 ]; then
  echo failed to start all the instances
  exit 1
fi

echo "record all VM's access info for ansible"
echo "[VMs]" > VMs
nova list | sed -n -r 's/.*(demo[0-9]+).*access=([.0-9]+).*/\1 ansible_host=\2/ p' >> VMs

cat <<EOF >>VMs
[all:vars]
ansible_connection=ssh 
ansible_user=root 
ansible_ssh_pass=100yard-
EOF
vm_num=$(nova list | grep demo | wc -l)
echo vm_num=$vm_num >>VMs
echo "stack_key=\"$(sudo cat /home/stack/.ssh/id_rsa.pub)\"" >> VMs
echo "root_key=\"$(sudo cat /root/.ssh/id_rsa.pub)\"" >> VMs

