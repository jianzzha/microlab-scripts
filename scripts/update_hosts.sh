#!/bin/bash

error ()
{
  echo $* 1>&2 
  exit 1
}

# remove exisitng entry first
sudo sed -i.bak -r '/compute/d' /etc/hosts
sudo sed -i -r '/controller/d' /etc/hosts
sudo sed -i -r '/vm/d' /etc/hosts
sudo sed -i -r '/demo/d' /etc/hosts

source /home/stack/stackrc || error "can't load stackrc"
nova list | sed -r -n 's/.*(compute-[0-9]+).*ctlplane=([0-9.]+).*/\2 \1/p' | sudo tee --append /etc/hosts >/dev/null

nova list | sed -r -n 's/.*(controller-[0-9]+).*ctlplane=([0-9.]+).*/\2 \1/p' | sudo tee --append /etc/hosts >/dev/null

source /home/stack/templates/overcloudrc || error "can't load overcloudrc"

nova list | sudo sed -n -r 's/.*(demo[0-9]+).*access=([.0-9]+).*/\2 \1/p' | sudo tee --append /etc/hosts >/dev/null

