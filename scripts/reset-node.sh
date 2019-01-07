#!/bin/bash

# Reset Gluster Specific Settings
gluster volume stop glustervol
service smb stop
service ctdb stop
gluster volume stop ctdb
gluster volume remove glustervol force
gluster volume remove ctdb force

# Remove LVM setup
rm -rf /bricks/*
umount /bricks
lvremove vg_gluster
vgremove vg_gluster

echo "Rmove /etc/fstab entry"
