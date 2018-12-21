#!/bin/bash
set -x
source variables

create_key()
{
  #CREATE KEY
  ssh-keygen -f $PRE.key -t rsa -N '' > /dev/null
}

create_network()
{
  #CREATE NETWORK
  V=`oci network vcn create --region $region --cidr-block 10.0.$subnet.0/24 --compartment-id $compartment_id --display-name "hpc_vcn-$PRE" --wait-for-state AVAILABLE | jq -r '.data.id'`
  NG=`oci network internet-gateway create --region $region -c $compartment_id --vcn-id $V --is-enabled TRUE --display-name "hpc_ng-$PRE" --wait-for-state AVAILABLE | jq -r '.data.id'`
  RT=`oci network route-table create --region $region -c $compartment_id --vcn-id $V --display-name "hpc_rt-$PRE" --wait-for-state AVAILABLE --route-rules '[{"cidrBlock":"0.0.0.0/0","networkEntityId":"'$NG'"}]' | jq -r '.data.id'`
  SL=`oci network security-list create --region $region -c $compartment_id --vcn-id $V --display-name "hpc_sl-$PRE" --wait-for-state AVAILABLE --egress-security-rules '[{"destination":  "0.0.0.0/0",  "protocol": "all", "isStateless":  null}]' --ingress-security-rules '[{"source":  "0.0.0.0/0",  "protocol": "all", "isStateless":  null}]' | jq -r '.data.id'`
  S=`oci network subnet create -c $compartment_id --vcn-id $V --region $region --availability-domain "$AD" --display-name "hpc_subnet-$PRE" --cidr-block "10.0.$subnet.0/26" --route-table-id $RT --security-list-ids '["'$SL'"]' --wait-for-state AVAILABLE | jq -r '.data.id'`
}

create_headnode()
{
  #CREATE BLOCK AND HEADNODE
  BLKSIZE_GB=`expr $blksize_tb \* 1024`
  for i in `seq 1 $server_nodes`; do
    BV=`oci bv volume create $INFO --display-name "hpc_block-$PRE" --size-in-gbs $BLKSIZE_GB --wait-for-state AVAILABLE | jq -r '.data.id'`;
    masterID=`oci compute instance launch $INFO --shape "$gluster_server_shape" --display-name "glusterfs-server$i" --image-id $OS --subnet-id $S --private-ip 10.0.$subnet.$i --wait-for-state RUNNING --user-data-file scripts/gluster_configure.sh --ssh-authorized-keys-file $PRE.key.pub | jq -r '.data.id'`;
    attachID=`oci compute volume-attachment attach --region $region --instance-id $masterID --type iscsi --volume-id $BV --wait-for-state ATTACHED | jq -r '.data.id'`;
    attachIQN=`oci compute volume-attachment get --volume-attachment-id $attachID --region $region | jq -r .data.iqn`;
    attachIPV4=`oci compute volume-attachment get --volume-attachment-id $attachID --region $region | jq -r .data.ipv4`;
  done
  masterIP=$(oci compute instance list-vnics --region $region --instance-id $masterID | jq -r '.data[]."public-ip"')
  masterPRVIP=$(oci compute instance list-vnics --region $region --instance-id $masterID | jq -r '.data[]."private-ip"')
}

create_key
create_network
create_headnode

