#!/bin/bash
#set -x
source variables

create_key()
{
  #CREATE KEY
  echo -e "${GREEN}CREATING key${NC}"
  ssh-keygen -f $PRE.key -t rsa -N '' > /dev/null
}

create_network()
{
  #CREATE NETWORK
  echo -e "${GREEN}CREATING glusterfs-network ${NC}"
  V=`oci network vcn create --region $region --cidr-block 10.0.$subnet.0/24 --compartment-id $compartment_id --display-name "gluster_vcn-$PRE" --wait-for-state AVAILABLE | jq -r '.data.id'`
  NG=`oci network internet-gateway create --region $region -c $compartment_id --vcn-id $V --is-enabled TRUE --display-name "gluster_ng-$PRE" --wait-for-state AVAILABLE | jq -r '.data.id'`
  RT=`oci network route-table create --region $region -c $compartment_id --vcn-id $V --display-name "gluster_rt-$PRE" --wait-for-state AVAILABLE --route-rules '[{"cidrBlock":"0.0.0.0/0","networkEntityId":"'$NG'"}]' | jq -r '.data.id'`
  SL=`oci network security-list create --region $region -c $compartment_id --vcn-id $V --display-name "gluster_sl-$PRE" --wait-for-state AVAILABLE --egress-security-rules '[{"destination":  "0.0.0.0/0",  "protocol": "all", "isStateless":  null}]' --ingress-security-rules '[{"source":  "0.0.0.0/0",  "protocol": "all", "isStateless":  null}]' | jq -r '.data.id'`
  S=`oci network subnet create -c $compartment_id --vcn-id $V --region $region --availability-domain "$AD" --display-name "gluster_subnet-$PRE" --cidr-block "10.0.$subnet.0/26" --route-table-id $RT --security-list-ids '["'$SL'"]' --wait-for-state AVAILABLE | jq -r '.data.id'`
}

create_headnode()
{
  #CREATE BLOCK AND HEADNODE
  BLKSIZE_GB=`expr $blksize_tb \* 1024`
  for i in `seq $server_nodes -1 1`; do
    echo -e "${GREEN}CREATING glusterfs-server$i ${NC}"
    masterID=`oci compute instance launch $INFO --shape "$gluster_server_shape" -c $compartment_id --display-name "gluster-server-$PRE-$i" --image-id $OS --subnet-id $S --private-ip 10.0.$subnet.1$i --wait-for-state RUNNING --user-data-file scripts/gluster_configure.sh --ssh-authorized-keys-file $PRE.key.pub | jq -r '.data.id'`
    for k in `seq 1 $blk_num`; do
      echo -e "${GREEN}CREATING glusterfs-block-$PRE-$i-$k ${NC}"
      BV=`oci bv volume create $INFO --display-name "gluster-block-$PRE-$i-$k" --size-in-gbs $BLKSIZE_GB --wait-for-state AVAILABLE | jq -r '.data.id'`;
    done
  done

}

attach_blocks()
{
  IID=`oci compute instance list --compartment-id $compartment_id --region $region | jq -r '.data[] | select(."display-name" | contains ("'$PRE-$i'")) | .id'`
  IP=`oci compute instance list-vnics --region $region --instance-id $IID | jq -r '.data[]."public-ip"'`
  echo $IP
  echo -e "${GREEN}Adding key to head node${NC}"
  n=0
  until [ $n -ge 5 ]
  do
    scp -o StrictHostKeyChecking=no -i $PRE.key $PRE.key $USER@$IP:/home/$USER/.ssh/id_rsa && break
    n=$[$n+1]
    sleep 60
  done 

  ssh -i $PRE.key $USER@$IP 'while [ ! -f /var/log/CONFIG_COMPLETE ]; do sleep 30; echo "Waiting for node to complete configuration: `date +%T`"; done'
  for i in `seq $server_nodes -1 1`; do
    echo -e "${GREEN}ATTACHING glusterfs-block-$PRE-$i-$k ${NC}"
    IID=`oci compute instance list --compartment-id $compartment_id --region $region | jq -r '.data[] | select(."display-name" | contains ("'$PRE-$i'")) | .id'`
    IP=`oci compute instance list-vnics --region $region --instance-id $IID | jq -r '.data[]."public-ip"'`
    echo
 
    for k in `seq 1 $blk_num`; do
      BVID=`oci bv volume list --compartment-id $compartment_id --region $region | jq -r '.data[] | select(."display-name" | contains ("'gluster-block-$PRE-$i-$k'")) | .id'`
      attachID=`oci compute volume-attachment attach --region $region --instance-id $IID --type iscsi --volume-id $BVID --wait-for-state ATTACHED | jq -r '.data.id'`
      attachIQN=`oci compute volume-attachment get --volume-attachment-id $attachID --region $region | jq -r .data.iqn`
      attachIPV4=`oci compute volume-attachment get --volume-attachment-id $attachID --region $region | jq -r .data.ipv4`
      ssh -o StrictHostKeyChecking=no -i $PRE.key $USER@$IP sudo sh /root/oci-hpc-ref-arch/scripts/mount_block.sh $attachIQN $attachIPV4
    done
    echo
  done
}

create_remove()
{
cat << EOF >> removeCluster-$PRE.sh
#!/bin/bash
export masterIP=$masterIP
export masterPRVIP=$masterPRVIP
export USER=$USER
export compartment_id=$compartment_id
export PRE=$PRE
export region=$region
export AD=$AD
export V=$V
export NG=$NG
export RT=$RT
export SL=$SL
export S=$S
export BV=$BV
export masterID=$masterID
EOF

cat << "EOF" >> removeCluster-$PRE.sh
echo -e "Removing: Gluster Nodes"
for instanceid in $(oci compute instance list --region $region --compartment-id $compartment_id | jq -r '.data[] | select(."display-name" | contains ("'$PRE'")) | .id'); do oci compute instance terminate --region $region --instance-id $instanceid --force; done
sleep 60
echo -e "Removing: Blocks"
for id in `oci bv volume list --compartment-id $compartment_id --region $region | jq -r '.data[] | select(."display-name" | contains ("'$PRE'")) | .id'`; do oci bv volume delete --region $region --volume-id $id --force; done
sleep 60
echo -e "Removing: Subnet, Route Table, Security List, Gateway, and VCN"
oci network subnet delete --region $region --subnet-id $S --force
sleep 10
oci network route-table delete --region $region --rt-id $RT --force
sleep 10
oci network security-list delete --region $region --security-list-id $SL --force
sleep 10
oci network internet-gateway delete --region $region --ig-id $NG --force
sleep 10
oci network vcn delete --region $region --vcn-id $V --force

mv removeCluster-$PRE.sh .removeCluster-$PRE.sh
mv $PRE.key .$PRE.key
mv $PRE.key.pub .$PRE.key.pub
echo -e "Complete"
EOF
  chmod +x removeCluster-$PRE*.sh

}

create_key
create_network
create_headnode
attach_blocks
create_remove

echo GlusterFS IP is: $IP