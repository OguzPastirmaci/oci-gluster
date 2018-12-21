#!/bin/bash

# gluster volume set VOLNAME stat-prefetch off

# gluster volume set VOLNAME server.allow-insecure on

# Need to update /etc/glusterf/glusterd.vol on all gluster servers
# option rpc-auth-allow-insecure on

# Restart Glusterd on wach node

# gluster volume set VOLNAME storage.batch-fsync-delay-usec 0

# chkconfig smb on

#/var/lib/glusterd/hooks/1/start/post
#Rename the S30samba-start.sh to K30samba-start.sh
# smbstatus -S

# gluster volume set user.smb disable

# /etc/samba/smb.conf
# [gluster-VOLNAME]
# comment = For samba share of volume VOLNAME
# vfs objects = glusterfs
# glusterfs:volume = VOLNAME
# glusterfs:logfile = /var/log/samba/VOLNAME.log
# glusterfs:loglevel = 7
# path = /
# read only = no
# guest ok = yes


