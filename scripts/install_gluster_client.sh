
set -x

#gluster_yum_release="http://yum.oracle.com/repo/OracleLinux/OL7/gluster312/x86_64"
#gluster_yum_release="http://yum.oracle.com/repo/OracleLinux/OL7/gluster5/x86_64"


function mount_glusterfs() {
    echo "sleep - 300s"
    sleep 300s
    sudo mkdir -p ${mount_point}
    sudo mount -t glusterfs ${server_hostname_prefix}1:/glustervol ${mount_point}
}

# Enable latest Oracle Linux Gluster release
yum-config-manager --add-repo $gluster_yum_release
sudo yum install glusterfs glusterfs-fuse attr -y
mount_glusterfs
while [ $? -ne 0 ]; do
    mount_glusterfs
done

echo "${server_hostname_prefix}1:/glustervol ${mount_point} glusterfs defaults,_netdev,direct-io-mode=disable 0 0" >> /etc/fstab




