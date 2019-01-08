#!/bin/bash

#######################################################################################################################################################
### This bootstrap script runs on glusterFS server and configures the following
### 1- install gluster packages
### 2- formats the disks (NVME), creates a LVM LV called "brick" (XFS)
### 3- fixes the resolve.conf file. GlusterFS needs DNS to work properly so make sure you update the below domains to match your environment
### 4- disable local firewall. Feel free to update this script to open only the required ports.
### 5- install and configure a gluster volume called glustervol using server1-mybrick, server2-mybrick (distributed)
###
######################################################################################################################################################

exec 2>/dev/null

action=$1
server_nodes=$2
subnet=$3


config_node()
{
    # Disable firewalld TODO: Add firewall settings to node in future rev.
    systemctl stop firewalld
    systemctl disable firewalld

    # Disable Selinux TODO: Enable Selinux
    setenforce 0

    # Enable latest Oracle Linux Gluster release
    yum-config-manager --add-repo http://yum.oracle.com/repo/OracleLinux/OL7/gluster312/x86_64
    yum install -y glusterfs-server samba git nvme-cli

    # Clone OCI-HPC Reference Architecture
    cd ~
    git clone https://github.com/oci-hpc/oci-hpc-ref-arch

    touch /var/log/CONFIG_COMPLETE
}

create_pvolume()
{
    if [ `lsblk -d --noheadings | awk '{print $1}' | grep nvme0n1` = "nvme0n1" ]; then NVME=true; else NVME=false; fi
    for i in `lsblk -d --noheadings | awk '{print $1}'`
    do 
        if [ $i = "sda" ]; then next
        else
            pvcreate --dataalignment 256K /dev/$i
            vgcreate vg_gluster /dev/$i
            vgextend vg_gluster /dev/$i
        fi
    done

    vgdisplay
    config_gluster
}

config_gluster()
{
    echo CONFIG GLUSTER
    # Create Logical Volume for Gluster Brick
    lvcreate -l 100%VG -n brick1 vg_gluster
    lvdisplay
    
    # Create XFS filesystem with Inodes set at 512 and Directory block size at 8192
    mkfs.xfs -f -i size=512 -n size=8192 /dev/vg_gluster/brick1
    mkdir -p /bricks/brick1
    mount /dev/vg_gluster/brick1 /bricks/brick1
    echo "/dev/vg_gluster/brick1  /bricks/brick1    xfs     noatime,inode64  1 2" >> /etc/fstab
    df -h
    
    # Setup DNS search path
    sed -i '/search/d' /etc/resolv.conf 
    echo "search baremetal.oraclevcn.com gluster_subnet-d6700.baremetal.oraclevcn.com publicsubnetad1.baremetal.oraclevcn.com publicsubnetad3.baremetal.oraclevcn.com localdomain" >> /etc/resolv.conf
    chattr -R +i /etc/resolv.conf
    
    # Start gluster services
    systemctl enable glusterd.service
    systemctl start glusterd.service
    
    # Create gluster brick
    mkdir /bricks/brick1/brick

    if [ "$(hostname -s | tail -c 3)" = "-1" ]; then
        echo CONFIGURING GLUSTER SERVER
        sleep 60
        host=`hostname -i`
        for i in `seq 2 $server_nodes`;
        do
            gluster peer probe $subnet.1$i --mode=script
        done
        sleep 20
        gluster volume create glustervol transport tcp ${host}:/bricks/brick1/brick force --mode=script
        sleep 10
        for i in `seq 2 $server_nodes`;
        do
            gluster volume add-brick glustervol $subnet.1$i:/bricks/brick1/brick force --mode=script
            sleep 10
        done
        gluster volume start glustervol force --mode=script
        sleep 20
        gluster volume start glustervol force --mode=script
        gluster volume status --mode=script
        gluster volume info --mode=script
    fi
}

if [ $action = "create_volume" ]; then create_pvolume
else config_node; fi