resource "tls_private_key" "public_private_key_pair" {
  algorithm   = "RSA"
}


resource "oci_core_instance" "gluster_server" {
  count               = var.gluster_server_node_count
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[(count.index%3)]["name"]
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1]["name"]
  availability_domain = local.ad

  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.gluster_server_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.gluster_server_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = var.gluster_server_shape
  #subnet_id           = "${oci_core_subnet.private.*.id[0]}"
  subnet_id           = local.storage_subnet_id


  source_details {
    source_type = "image"
    source_id = (var.use_marketplace_image ? var.mp_listing_resource_id : var.images[var.region])
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.public_private_key_pair.public_key_openssh
      ]
    )
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "gluster_yum_release=\"${var.gluster_ol_repo_mapping[var.gluster_version]}\"",
        "server_node_count=\"${var.gluster_server_node_count}\"",
        "server_hostname_prefix=\"${var.gluster_server_hostname_prefix}\"",
        "disk_size=\"${var.gluster_server_disk_size}\"",
        "disk_count=\"${var.gluster_server_disk_count}\"",
        "num_of_disks_in_brick=\"${var.gluster_server_num_of_disks_in_brick}\"",
        "replica=\"${var.gluster_replica}\"",
        "volume_types=\"${var.gluster_volume_types}\"",
        "block_size=\"${var.gluster_block_size}\"",
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
  count               = var.client_node_count
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[(count.index%3)]["name"]
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1]["name"]
  availability_domain = local.ad
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.client_node_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.client_node_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = var.client_node_shape
  #subnet_id           = (local.server_dual_nics ? oci_core_subnet.privateb.*.id[0] : oci_core_subnet.privateb.*.id[0])
  subnet_id           = local.client_subnet_id


  source_details {
    source_type = "image"
    source_id = (var.use_marketplace_image ? var.mp_listing_resource_id : var.images[var.region])
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.public_private_key_pair.public_key_openssh
      ]
    )
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "gluster_yum_release=\"${var.gluster_ol_repo_mapping[var.gluster_version]}\"",
        "mount_point=\"${var.gluster_mount_point}\"",
        "server_hostname_prefix=\"${var.gluster_server_hostname_prefix}\"",
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
  count = var.bastion_node_count
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1]["name"]
  availability_domain = local.ad
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.bastion_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = var.bastion_shape
  hostname_label      = "${var.bastion_hostname_prefix}${format("%01d", count.index+1)}"

  create_vnic_details {
    subnet_id              = local.bastion_subnet_id
# "${oci_core_subnet.public.*.id[0]}"
    skip_source_dest_check = true
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.public_private_key_pair.public_key_openssh
      ]
    )
  }

  launch_options {
    network_type = "VFIO"
  }

  source_details {
    source_type = "image"
    source_id   = (var.use_marketplace_image ? var.mp_listing_resource_id : var.images[var.region])
  }
}

# Run on 1st Gluster Server node only.
resource "null_resource" "create_gluster_volumes" {
  depends_on = [ oci_core_instance.gluster_server ]
  count      = 1


  provisioner "file" {
    source      = "${var.scripts_directory}/"
    destination = "/tmp/"
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.gluster_server.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.public_private_key_pair.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.public_private_key_pair.private_key_pem
    }
  }

  provisioner "remote-exec" {
    inline = [
      "set -x",
      "echo about to run /tmp/nodes-cloud-init-complete-status-check.sh",
      "sudo -s bash -c 'set -x && chmod 777 /tmp/*.sh'",
      "sudo -s bash -c 'set -x && /tmp/nodes-cloud-init-complete-status-check.sh'",
      "sudo -s bash -c \"set -x && /tmp/create_gluster_volumes.sh  ${var.gluster_server_node_count} ${local.server_filesystem_vnic_hostname_prefix} ${local.filesystem_subnet_domain_name} ${var.gluster_volume_types} ${var.gluster_replica} \"",
    ]
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.gluster_server.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.public_private_key_pair.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.public_private_key_pair.private_key_pem
    }
  }
}

