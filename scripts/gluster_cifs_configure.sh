#!/bin/bash
# Name: gluster_cifs_configure.sh
# Author: Chuck Gilbert <chuck.gilbert@oracle.com>
# Description: This script takes an existing GlusterFS Volume,
#   and enables CIFS export of the volume for access of windows clients.
#

# Exit on any errors
set -e

# Source Functions
source functions

# print_usage(): Function to print script usage
function print_usage() {
  echo "$0 -v volume -m \"x.x.x.x y.y.y.y\""
  exit 1
}

# Check Arg Length
if [ "$#" = 0 ]
then
  print_usage
fi

# Get Commandline Options
while getopts ":v:m:" opt; do
   case $opt in
     v)
       VOLNAME=$OPTARG
       ;;
     m)
       NODE_LIST=$OPTARG
       ;;
     \?)
       echo "Invalid option: -$OPTARG" >&2
       print_usage
       ;;
   esac
 done

echo $VOLNAME
echo $NODE_LIST

create_ctdb_volume "/brick/bricks/mybrick/ctdb" "$NODE_LIST"

# end of script