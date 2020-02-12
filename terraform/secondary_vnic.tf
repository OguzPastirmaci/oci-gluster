
resource "oci_core_vnic_attachment" "server_secondary_vnic_attachment" {
  count = var.gluster_server["node_count"]

  #Required
  create_vnic_details {
    #Required
    subnet_id = oci_core_subnet.privateb[0].id

    #Optional
    assign_public_ip = "false"
    display_name     = "${var.gluster_server["hostname_prefix"]}vnic2-${format("%01d", count.index + 1)}"
    hostname_label   = "${var.gluster_server["hostname_prefix"]}vnic2-${format("%01d", count.index + 1)}"

    # false is default value
    skip_source_dest_check = "false"
  }
  instance_id = element(oci_core_instance.gluster_server.*.id, count.index)

  #Optional
  #display_name = "SecondaryVNIC"
  # set to 1, if you want to use 2nd physical NIC for this VNIC
  nic_index = 0
  # (local.server_dual_nics ? "1" : "0")
}
