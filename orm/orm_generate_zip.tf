variable "save_to" {
    default = ""
}

data "archive_file" "generate_zip" {
  type        = "zip"
  output_path = (var.save_to != "" ? "${var.save_to}/glusterfs.zip" : "${path.module}/dist/glusterfs.zip")
  source_dir = "../"
  excludes    = [".gitignore" , "terraform.tfstate" , "terraform.tfstate.backup" , "terraform.tfvars.template", "terraform.tfvars", "provider.tf", ".terraform", "images" , "orm" , ".git" , "RM_Mktpce_public_oci_gluster.xcworkspace" , "gluster_mdtest_ior_perf_results"  , "localonly.ior_mpiio_setup.tf" , "scripts/passwordless_ssh.sh" , "scripts/vdbench_install.sh" , "scripts/ior_install.sh" , "local_only" ]
}


