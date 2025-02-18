## Copyright © 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_identity_tag_namespace" "ArchitectureCenterTagNamespace" {
    compartment_id = var.compartment_ocid
    description = "ArchitectureCenterTagNamespace"
    name = "ArchitectureCenter\\deploy-glusterfs"

    provisioner "local-exec" {
       command = "sleep 10"
    }

}

resource "oci_identity_tag" "ArchitectureCenterTag" {
    description = "ArchitectureCenterTag"
    name = "release"
    tag_namespace_id = oci_identity_tag_namespace.ArchitectureCenterTagNamespace.id

    validator {
        validator_type = "ENUM"
        values         = ["release", "1.0"]
    }

    provisioner "local-exec" {
       command = "sleep 20"
    }
}