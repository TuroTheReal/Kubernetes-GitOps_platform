#!/bin/bash
# Apres changement de poste : retire les VMs VirtualBox "fantomes" (<inaccessible>).
# Usage : bash vmsetup/clean.sh

for id in $(VBoxManage list vms | grep inaccessible | grep -oE '[0-9a-f-]{36}'); do
    echo "VM fantome retiree : $id"
    VBoxManage unregistervm "$id"
done

vagrant global-status --prune > /dev/null   # oublie les VMs disparues
echo "OK"
