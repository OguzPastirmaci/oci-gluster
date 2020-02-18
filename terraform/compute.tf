

resource "oci_core_instance" "gluster_server" {
  count               = var.gluster_server["node_count"]
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[(count.index%3)]["name"]
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1]["name"]

  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.gluster_server["hostname_prefix"]}${format("%01d", count.index+1)}"
  hostname_label      = "${var.gluster_server["hostname_prefix"]}${format("%01d", count.index+1)}"
  shape               = "${var.gluster_server["shape"]}"
  subnet_id           = "${oci_core_subnet.private.*.id[0]}"

  source_details {
    source_type = "image"
    source_id = "${var.images[var.region]}"
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "gluster_yum_release=\"${var.gluster_ol_repo_mapping[var.gluster["version"]]}\"",
        "server_node_count=\"${var.gluster_server["node_count"]}\"",
        "server_hostname_prefix=\"${var.gluster_server["hostname_prefix"]}\"",
"disk_size=\"${var.gluster_server["disk_size"]}\"",
"disk_count=\"${var.gluster_server["disk_count"]}\"",
#"raid_enabled=\"${var.gluster_server["raid_enabled"]}\"",
"num_of_disks_in_brick=\"${var.gluster_server["num_of_disks_in_brick"]}\"",
"replica=\"${var.gluster["replica"]}\"",
        "volume_types=\"${var.gluster["volume_types"]}\"",
        "block_size=\"${var.gluster["block_size"]}\"",
        "storage_subnet_domain_name=\"${local.storage_subnet_domain_name}\"",
        "filesystem_subnet_domain_name=\"${local.filesystem_subnet_domain_name}\"",
        "vcn_domain_name=\"${local.vcn_domain_name}\"",
        "server_filesystem_vnic_hostname_prefix=\"${local.server_filesystem_vnic_hostname_prefix}\"",
        "server_dual_nics=\"${local.server_dual_nics}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/install_gluster_cluster.sh")
      )))}"
    }

  timeouts {
    create = "120m"
  }

}


resource "oci_core_instance" "client_node" {
  count               = "${var.client_node["node_count"]}"
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[(count.index%3)]["name"]
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1]["name"]  
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.client_node["hostname_prefix"]}${format("%01d", count.index+1)}"
  hostname_label      = "${var.client_node["hostname_prefix"]}${format("%01d", count.index+1)}"
  shape               = "${var.client_node["shape"]}"
  subnet_id           = (local.server_dual_nics ? oci_core_subnet.privateb.*.id[0] : oci_core_subnet.privateb.*.id[0])
# oci_core_subnet.private.*.id[0]

  source_details {
    source_type = "image"
    source_id = "${var.images[var.region]}"
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "gluster_yum_release=\"${var.gluster_ol_repo_mapping[var.gluster["version"]]}\"",
        "mount_point=\"${var.gluster["mount_point"]}\"",
        "server_hostname_prefix=\"${var.gluster_server["hostname_prefix"]}\"",
        "storage_subnet_domain_name=\"${local.storage_subnet_domain_name}\"",
        "filesystem_subnet_domain_name=\"${local.filesystem_subnet_domain_name}\"",
        "vcn_domain_name=\"${local.vcn_domain_name}\"",
        "server_filesystem_vnic_hostname_prefix=\"${local.server_filesystem_vnic_hostname_prefix}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/install_gluster_client.sh")
      )))}"
    }

  timeouts {
    create = "120m"
  }

}



/* bastion instances */
resource "oci_core_instance" "bastion" {
  count = "${var.bastion["node_count"]}"
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1]["name"]
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.bastion["hostname_prefix"]}${format("%01d", count.index+1)}"
  shape               = "${var.bastion["shape"]}"
  hostname_label      = "${var.bastion["hostname_prefix"]}${format("%01d", count.index+1)}"

  create_vnic_details {
    subnet_id              = "${oci_core_subnet.public.*.id[0]}"
    skip_source_dest_check = true
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
  }

  launch_options {
    network_type = "VFIO"
  }

  source_details {
    source_type = "image"
    source_id   = "${var.images[var.region]}"
  }
}


