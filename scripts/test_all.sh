#!/bin/bash

first=$1
last=$2

[ -d "$HOME/reports" ] || mkdir $HOME/reports
  
for ((i=$first; i<=$last; i++)); do
  [ -f "$HOME/reports/vm$i" ] && continue
  sudo ./start_binary_search.sh $i $i | tee $HOME/reports/tmpfile
  tail -n 40 $HOME/reports/tmpfile >> $HOME/reports/vm$i 
done

if ((first == last)); then
  exit 0
fi

[ -f "$HOME/reports/vm${first}_vm${last}" ] && exit 1

sudo ./start_binary_search.sh $first $last | tee $HOME/reports/tmpfile
tail -n 40 $HOME/reports/tmpfile >> $HOME/reports/vm${first}_vm${last} 

