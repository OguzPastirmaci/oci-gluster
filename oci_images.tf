###
## oci_images.tf for Replicating Stack Listing to other Markets
###

variable "marketplace_source_images" {
  type = map(object({
    ocid = string
    is_pricing_associated = bool
    compatible_shapes = set(string)
  }))
  default = {
    main_mktpl_image = {
      ocid = "ocid1.image.oc1..aaaaaaaaqgspr7vy2xs2xdyqqvxyrdgizkxnbmq5pqwxr4rmnnbnl6cays2a"
      is_pricing_associated = false
      compatible_shapes = []
    }
  }
}
