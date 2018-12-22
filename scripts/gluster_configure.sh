#!/bin/bash
#yum update -y
#######################################################################################################################################################
### This bootstrap script runs on glusterFS server and configures the following
### 1- install gluster packages
### 2- formats the NVME disks (HighIO1.36 shape), creates a LVM LV called "brick" (XFS)
### 3- fixes the resolve.conf file. GlusterFS needs DNS to work properly so make sure you update the below domains to match your environment
### 4- disable local firewall. Feel free to update this script to open only the required ports.
### 5- install and configure a gluster volume called glustervol using server1-mybrick, server2-mybrick and server3-mybrick LVs (replicas)
###
######################################################################################################################################################
exec 2>/dev/null

config_node()
{
    systemctl stop firewalld
    systemctl disable firewalld
    yum-config-manager --add-repo http://yum.oracle.com/repo/OracleLinux/OL7/developer_gluster310/x86_64
    yum install -y glusterfs-server samba git
    cd ~
    git clone https://github.com/oci-hpc/oci-hpc-ref-arch

    touch /var/log/CONFIG_COMPLETE
}

create_pvolume()
{
    for i in `lsblk -d --noheadings | awk '{print $1}'`
    do 
        if [ $i = "sda" ]; then  break
        else
            lsblk
            parted /dev/$i mklabel gpt
            parted -a opt /dev/$i mkpart primary ext4 0% 100%
            pvcreate /dev/$i\1
            vgcreate vg_gluster /dev/$i\1
            vgextend vg_gluster /dev/$i\1
        fi
    done
    vgdisplay
    config_gluster
}

config_gluster()
{
    lvcreate -L $1T -n brick1 vg_gluster
    mkfs.xfs /dev/vg_gluster/brick1
    mkdir -p /bricks/brick1
    mount /dev/vg_gluster/brick1 /bricks/brick1
    echo "/dev/vg_gluster/brick1  /bricks/brick1    xfs     defaults,_netdev  0 0" >> /etc/fstab
    sed -i '/search/d' /etc/resolv.conf 
    echo "search baremetal.oraclevcn.com gluster_subnet-d6700.baremetal.oraclevcn.com publicsubnetad1.baremetal.oraclevcn.com publicsubnetad3.baremetal.oraclevcn.com localdomain" >> /etc/resolv.conf
    chattr -R +i /etc/resolv.conf
    #firewall-cmd --zone=public --add-port=24007-24020/tcp --permanent
    #firewall-cmd --reload
    systemctl disable firewalld
    systemctl stop firewalld
    systemctl enable glusterd.service
    systemctl start glusterd.service
    mkdir /bricks/brick1/brick

    if [ "$(hostname -s | tail -c 3)" = "-1" ]; then
        sleep 180
        export host=`hostname -i`
        for i in `seq 2 $2`;
        do
            gluster peer probe 10.0.2.1$i
        done
        sleep 20
        sudo gluster volume create glustervol transport tcp ${host}:/bricks/brick1/brick
        sleep 10
        for i in `seq 2 $2`;
        do
            sudo gluster volume add-brick glustervol 10.0.2.1$i:/bricks/mybrick/brick force
            sleep 10
        done
        #gluster volume create glustervol replica 3 transport tcp ${host}:/bricks/brick1/brick ${server2}:/bricks/brick1/brick ${server3}:/bricks/brick1/brick force
        gluster volume start glustervol
    fi
}

if [ $1 = "create_volume" ]; then create_pvolume
else config_node; fi