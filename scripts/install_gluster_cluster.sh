
set -x


#server_node_count=$2
#server_hostname_prefix=$3
echo "server_node_count = $server_node_count"
echo "server_hostname_prefix = $server_hostname_prefix"

#lvm_stripe_size="1024k"
lvm_stripe_size=${block_size}

#gluster_yum_release="http://yum.oracle.com/repo/OracleLinux/OL7/gluster312/x86_64"
#gluster_yum_release="http://yum.oracle.com/repo/OracleLinux/OL7/gluster5/x86_64"

# list_length(): Return the length of the list
function list_length() {
  echo $(wc -w <<< "$@")
}


# tuned_config(): Enable/Start Tuned
function tuned_config() {
  /sbin/chkconfig tuned on
  /sbin/service tuned start
  /sbin/tuned-adm profile throughput-performance

  /sbin/service irqbalance stop
  /sbin/chkconfig irqbalance off
}


config_node()
{
    # Disable firewalld TODO: Add firewall settings to node in future rev.
    systemctl stop firewalld
    systemctl disable firewalld

    # Disable Selinux TODO: Enable Selinux
    setenforce 0

    # Enable latest Oracle Linux Gluster release
    yum-config-manager --add-repo $gluster_yum_release
    yum install -y glusterfs-server samba git nvme-cli

    touch /var/log/CONFIG_COMPLETE
}

make_filesystem()
{
    # Create Logical Volume for Gluster Brick
    lvcreate -l 100%VG --stripes $brick_count --stripesize $lvm_stripe_size -n $brick_name $vg_gluster_name
    lvdisplay

    # Create XFS filesystem with Inodes set at 512 and Directory block size at 8192
    # and set the su and sw for optimal stripe performance
    mkfs.xfs -f -i size=512 -n size=8192 -d su=${lvm_stripe_size},sw=${brick_count} /dev/${vg_gluster_name}/${brick_name}
    mkdir -p /bricks/${brick_name}
    mount -o noatime,inode64,nobarrier /dev/${vg_gluster_name}/${brick_name} /bricks/${brick_name}
    echo "/dev/${vg_gluster_name}/${brick_name}  /bricks/${brick_name}    xfs     noatime,inode64,nobarrier  1 2" >> /etc/fstab
    df -h

    # Create gluster brick
    mkdir -p /bricks/${brick_name}/brick
}

create_bricks()
{
    # Check if NVME
    if [ `lsblk -d --noheadings | awk '{print $1}' | grep nvme0n1` = "nvme0n1" ]; then NVME=true; else NVME=false; fi

    # Wait for block-attach of the Block volumes to complete. Terraform then creates the below file on server nodes of cluster.
    while [ ! -f /tmp/block-attach.complete ]
    do
      sleep 60s
      echo "Waiting for block-attach via Terraform to  complete ..."
    done

    # Gather list of block devices for brick config
    blk_lst=$(lsblk -d --noheadings | grep -v sda | awk '{ print $1 }' | sort)
    blk_cnt=$(lsblk -d --noheadings | grep -v sda | wc -l)

    count=1
    # Configure physical volumes and volume group
    for pvol in $blk_lst
    do

        if [ "$volume_types" = "Dispersed" ]; then
            pvcreate /dev/$pvol
            vgcreate vg_gluster /dev/$pvol
            vgextend vg_gluster /dev/$pvol
            vgdisplay vg_gluster
            vg_gluster_name="vg_gluster"
            brick_name="brick1"
            brick_count=$blk_cnt
        else
            # Same logic for DistributedDispersed & Distributed
            pvcreate /dev/$pvol
            vgcreate vg_gluster_$count /dev/$pvol
            vgdisplay vg_gluster_$count
            vg_gluster_name="vg_gluster_$count"
            brick_name="brick${count}"
            brick_count=1
            make_filesystem
        fi
        count=$((count+1))
    done

    if [ "$volume_types" = "Dispersed" ]; then
        make_filesystem
    fi
}


gluster_probe_peers()
{
    if [ "$(hostname -s | tail -c 3)" = "-1" ]; then
        echo GLUSTER PROBING PEERS
        sleep 60
        host=`hostname -i`
        for i in `seq 2 $server_node_count`;
        do
            gluster peer probe $server_hostname_prefix${i} --mode=script
        done
        sleep 20
        gluster peer status
    fi
}



create_gluster_volumes()
{
    if [ "$(hostname -s | tail -c 3)" = "-1" ]; then

        # Gather list of block devices for brick config
        brick_lst=$(ls /bricks | sort)
        brick_cnt=$(ls /bricks | sort | wc -l)
        count=1
        buffer=""
        for brick in $brick_lst
        do
            for i in `seq 1 $server_node_count`;
            do
                buffer="$buffer ${server_hostname_prefix}${i}:/bricks/${brick}/brick "
            done

            count=$((count+1))
        done

        if [ "$volume_types" = "Distributed" ]; then
            command_parameters=" transport tcp $buffer  force --mode=script"
        else
            command_parameters=" disperse $server_node_count redundancy 1 transport tcp $buffer  force --mode=script"
        fi

    gluster volume create glustervol $command_parameters
    sleep 20
    gluster volume start glustervol force --mode=script
    sleep 20
    gluster volume status --mode=script
    gluster volume info --mode=script

    fi
}

config_node
tuned_config
create_bricks

# Start gluster services
systemctl enable glusterd.service
systemctl start glusterd.service
gluster_probe_peers
create_gluster_volumes

# Tuning
gluster volume set  glustervol performance.cache-size 15GB
gluster volume set  glustervol nfs.disable on
gluster volume set  glustervol performance.io-cache on
gluster volume set  glustervol performance.io-thread-count 32


exit 0
