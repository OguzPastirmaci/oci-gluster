#!/bin/bash

# Reset Gluster Specific Settings
gluster volume stop glustervol force
service smb stop
service ctdb stop
gluster volume stop ctdb force
gluster volume remove glustervol force
gluster volume remove ctdb force
service glusterfsd stop
service glusterfs stop
# Remove LVM setup
rm -rf /bricks/brick1/*
umount /bricks/brick1
lvremove vg_gluster
vgremove vg_gluster

if [ `lsblk -d --noheadings | awk '{print $1}' | grep nvme0n1` = "nvme0n1" ]; then NVME=true; else NVME=false; fi

for i in `lsblk -d --noheadings | awk '{print $1}'`
do
  if [ $i = "sda" ]; then next
  else
    pvremove /dev/$i
  fi
done

echo "Remove /etc/fstab"
