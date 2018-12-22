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

    config_gluster
}

config_gluster()
{
    lvcreate -L 3.5T -n mybrick vg_gluster
    mkfs.xfs /dev/vg_gluster/mybrick
    mkdir -p /bricks/mybrick
    mount /dev/vg_gluster/mybrick /bricks/mybrick
    echo "/dev/vg_gluster/mybrick  /bricks/mybrick    xfs     defaults,_netdev  0 0" >> /etc/fstab
    sed -i '/search/d' /etc/resolv.conf 
    echo "search baremetal.oraclevcn.com publicsubnetad2.baremetal.oraclevcn.com publicsubnetad1.baremetal.oraclevcn.com publicsubnetad3.baremetal.oraclevcn.com localdomain" >> /etc/resolv.conf
    chattr -R +i /etc/resolv.conf
    #firewall-cmd --zone=public --add-port=24007-24020/tcp --permanent
    #firewall-cmd --reload
    systemctl disable firewalld
    systemctl stop firewalld
    systemctl enable glusterd.service
    systemctl start glusterd.service
    mkdir /bricks/mybrick/brick

    if ["$(hostname -s)" == "glusterfs-server1"]; then
        sleep 180
        export host=`hostname`
        export server1=`host glusterfs-server2 |cut -c1-17`
        export server2=`host glusterfs-server3 |cut -c1-17`
        gluster peer probe ${server1}
        gluster peer probe ${server2}
        sleep 20
        gluster volume create glustervol replica 3 transport tcp ${host}:/bricks/mybrick/brick ${server2}:/bricks/mybrick/brick ${server3}:/bricks/mybrick/brick force
        sleep 10
        gluster volume start glustervol
    fi
}

if [ $1 = "create_volume" ]; then create_pvolume
else config_node; fi