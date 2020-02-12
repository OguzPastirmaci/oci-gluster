
set -x

echo "server_dual_nics=\"${server_dual_nics}\"" >> /tmp/env_variables.sh
echo "storage_subnet_domain_name=\"${storage_subnet_domain_name}\"" >> /tmp/env_variables.sh
echo "filesystem_subnet_domain_name=\"${filesystem_subnet_domain_name}\"" >> /tmp/env_variables.sh
echo "vcn_domain_name=\"${vcn_domain_name}\"" >> /tmp/env_variables.sh



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


function update_resolvconf {
    #################   Update resolv.conf  ###############"
    ## Modify resolv.conf to ensure DNS lookups work from one private subnet to another subnet
    cp /etc/resolv.conf /etc/resolv.conf.backup
    rm -f /etc/resolv.conf
    echo "search ${storage_subnet_domain_name} ${filesystem_subnet_domain_name} ${vcn_domain_name} " > /etc/resolv.conf
    echo "nameserver 169.254.169.254" >> /etc/resolv.conf
}

# tuned_config(): Enable/Start Tuned
function tuned_config() {
  /sbin/chkconfig tuned on
  /sbin/service tuned start
  /sbin/tuned-adm profile throughput-performance

  /sbin/service irqbalance stop
  /sbin/chkconfig irqbalance off
}

function configure_nics() {

if [ "$server_dual_nics" = "false" ]; then


#cd /etc/sysconfig/network-scripts/

   # Wait till 2nd NIC is configured
   privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp ' | sed 's/"//g' ` ;
   echo $privateIp | grep "\." ;
   while [ $? -ne 0 ];
   do
     sleep 10s
     echo "Waiting for 2nd Physical NIC to get configured with hostname"
     privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp ' | sed 's/"//g' ` ;
     echo $privateIp | grep "\." ;
   done
   vnicId=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].vnicId ' | sed 's/"//g' ` ;
   macAddr=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].macAddr ' | sed 's/"//g' ` ;
   subnetCidrBlock=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].subnetCidrBlock ' | sed 's/"//g' ` ;
   sleep 30s
   curl -O https://docs.cloud.oracle.com/en-us/iaas/Content/Resources/Assets/secondary_vnic_all_configure.sh
   chmod +x secondary_vnic_all_configure.sh
   /secondary_vnic_all_configure.sh -c
   sleep 30s
# Sometimes, "ip addr" , it returned empty. hence added another command.
   interface=`ip addr | grep -B2 $privateIp | grep "BROADCAST" | gawk -F ":" ' { print $2 } ' | sed -e 's/^[ \t]*//'`
   interface=`/secondary_vnic_all_configure.sh  | grep $vnicId |  gawk -F " " ' { print $8 } ' | sed -e 's/^[ \t]*//'`

   echo "$subnetCidrBlock via $privateIp dev $interface" >  /etc/sysconfig/network-scripts/route-$interface
   echo "Permanently configure 2nd VNIC...$interface"
   echo "DEVICE=$interface
HWADDR=$macAddr
ONBOOT=yes
TYPE=Ethernet
USERCTL=no
IPADDR=$privateIp
NETMASK=255.255.255.0
MTU=9000
NM_CONTROLLED=no
" > /etc/sysconfig/network-scripts/ifcfg-$interface

    systemctl status network.service
    ifdown $interface
    ifup $interface

    SecondVNicFQDNHostname=`nslookup $privateIp | grep "name = " | gawk -F"=" '{ print $2 }' | sed  "s|^ ||g" | sed  "s|\.$||g"`
    THIS_FQDN=$SecondVNicFQDNHostname
    THIS_HOST=${THIS_FQDN%%.*}
    SecondVNICDomainName=${THIS_FQDN#*.*}

  else
    echo "todo"
  fi
}

function tune_nics() {
nic_lst=$(ifconfig | grep " flags" | grep -v "^lo:" | gawk -F":" '{ print $1 }' | sort) ; echo $nic_lst
for nic in $nic_lst
do
    ethtool -G $nic rx 2047 tx 2047 rx-jumbo 8191
done
}



function tune_sysctl() {

echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf
echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf
echo "net.core.wmem_default=16777216" >> /etc/sysctl.conf
echo "net.core.rmem_default=16777216" >> /etc/sysctl.conf
echo "net.core.optmem_max=16777216" >> /etc/sysctl.conf
echo "net.core.netdev_max_backlog=27000" >> /etc/sysctl.conf
echo "kernel.sysrq=1" >> /etc/sysctl.conf
echo "kernel.shmmax=18446744073692774399" >> /etc/sysctl.conf
echo "net.core.somaxconn=8192" >> /etc/sysctl.conf
echo "net.ipv4.tcp_adv_win_scale=2" >> /etc/sysctl.conf
echo "net.ipv4.tcp_low_latency=1" >> /etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 212992 87380 16777216" >> /etc/sysctl.conf
echo "net.ipv4.tcp_sack = 1" >> /etc/sysctl.conf
echo "net.ipv4.tcp_window_scaling = 1" >> /etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 212992 65536 16777216" >> /etc/sysctl.conf
echo "vm.min_free_kbytes = 65536" >> /etc/sysctl.conf
echo "net.ipv4.tcp_no_metrics_save = 0" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = cubic" >> /etc/sysctl.conf
echo "net.ipv4.tcp_timestamps = 0" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = htcp" >> /etc/sysctl.conf

/sbin/sysctl -p /etc/sysctl.conf

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
    lvcreate -l 100%VG -n $brick_name $vg_gluster_name
    lvdisplay

    # Create XFS filesystem with Inodes set at 512 and Directory block size at 8192
    # and set the su and sw for optimal stripe performance
    mkfs.xfs -f -i size=512 -n size=8192 -d su=${lvm_stripe_size},sw=${lvm_disk_count} /dev/${vg_gluster_name}/${brick_name}
    mkdir -p /bricks/${brick_name}
    mount -t xfs -o noatime,inode64,nobarrier /dev/${vg_gluster_name}/${brick_name} /bricks/${brick_name}
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

    chunk_size=${block_size}; chunk_size_tmp=`echo $chunk_size | gawk -F"K" ' { print $1 }'` ; echo $chunk_size_tmp;

    disk_list=""
    for disk in $blk_lst
    do
        disk_list="$disk_list /dev/$disk"
    done
    echo "disk_list=$disk_list"
    raid_device_count=$blk_cnt
    raid_device_name="md0"
    mdadm --create md0 --level=0 --chunk=$chunk_size --raid-devices=$blk_cnt $disk_list

    count=1
    # Configure physical volumes and volume group
    # Gather list of RAID devices for brick config
    raid_lst=$(ls /dev/md/md* | sort)
    raid_cnt=$(ls /dev/md/md* | wc -l)
    echo $raid_lst ; echo $raid_cnt
    raid_prefix="/dev/md/"
    for pvol in $raid_lst
    do

        if [ "$volume_types" = "Dispersed" ]; then
            pvcreate $pvol
            vg_gluster_name="vg_gluster"
            vgcreate $vg_gluster_name $pvol
            vgextend $vg_gluster_name $pvol
            vgdisplay $vg_gluster_name
            #brick_name="brick1"
            #brick_count=$raid_cnt
        else
            # Same logic for DistributedDispersed & Distributed
            dataalignment=$((raid_device_count*chunk_size_tmp));
            echo $dataalignment;
            pvcreate --dataalignment $dataalignment $pvol
            #pvcreate ${raid_prefix}$pvol

            vg_gluster_name="vg_gluster_$count" ; echo $vg_gluster_name
            physicalextentsize=$chunk_size;  echo $physicalextentsize
            vgcreate --physicalextentsize $physicalextentsize $vg_gluster_name $pvol
            #          vgcreate vg_gluster_$count ${raid_prefix}$pvol
            #            vgdisplay vg_gluster_$count

            brick_name="brick${count}"
            lvm_disk_count=$((raid_device_count*1))
            make_filesystem
        fi
        count=$((count+1))
    done

    if [ "$volume_types" = "Dispersed" ]; then
        lvm_disk_count=$((raid_device_count*raid_cnt))
        brick_name="brick1"
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
            gluster peer probe ${server_filesystem_vnic_hostname_prefix}${i}.${filesystem_subnet_domain_name} --mode=script
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
                buffer="$buffer ${server_filesystem_vnic_hostname_prefix}${i}:/bricks/${brick}/brick "
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

update_resolvconf
config_node
tuned_config
configure_nics
tune_nics
tune_sysctl
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
