#/bin/bash
source ~stack/stackrc

echo "[computes]" > nodes 
nova list | sed -n -r 's/.*compute.*ctlplane=([.0-9]+).*/\1/ p' >> nodes 

echo "[controllers]" >> nodes
nova list | sed -n -r 's/.*control.*ctlplane=([.0-9]+).*/\1/ p' >> nodes 

cat <<EOF >>nodes
[all:vars]
ansible_connection=ssh 
ansible_user=heat-admin
ansible_become=true
EOF

echo "stack_key=\"$(sudo cat /home/stack/.ssh/id_rsa.pub)\"" >> nodes 
echo "root_key=\"$(sudo cat /root/.ssh/id_rsa.pub)\"" >> nodes

sudo sed -i.bak -r '/compute/d' /etc/hosts
sudo sed -i -r '/controller/d' /etc/hosts

nova list | sed -r -n 's/.*(compute-[0-9]+).*ctlplane=([0-9.]+).*/\2 \1/p' | sudo tee --append /etc/hosts >/dev/null

nova list | sed -r -n 's/.*(controller-[0-9]+).*ctlplane=([0-9.]+).*/\2 \1/p' | sudo tee --append /etc/hosts >/dev/null

ansible-playbook -i nodes update_key.yml
