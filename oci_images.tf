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
      compatible_shapes = [BM.Standard1.36, BM.Standard.B1.44, BM.Standard2.52, BM.DenseIO2.52, BM.GPU2.2, BM.GPU3.8, BM.HPC2.36, VM.Standard1.1, VM.Standard1.2, VM.Standard.B1.1, VM.Standard.B1.2, VM.Standard2.1, VM.Standard2.2, VM.Standard2.4, VM.Standard2.8, VM.Standard2.24, VM.Standard.E2.1, VM.Standard.E2.2, VM.Standard.E2.4, VM.Standard.E2.8, VM.DenseIO1.4, VM.DenseIO2.8, VM.DenseIO2.16, VM.DenseIO2.24, VM.GPU2.1, VM.GPU3.1, VM.GPU3.2, VM.GPU3.4]
    }
  }
}
