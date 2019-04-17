##################################################################################
# VARIABLES
##################################################################################

variable "name" {}
variable "owner" {}
variable "ttl" {}
variable "environment_tag" {}
variable "key_name" {}
variable "id_rsa_aws" {
  
}
variable "dns_domain" {}

variable "network_address_space" {}

variable "ssh_user" {
#  default = "ec2-user"
#  default = "ubuntu"
}

variable "tfe_node_count" {
}
variable "tfe_password" {
  
}
variable "tfe_encryption_key" {
  
}
variable "tfe_rli_vault_password" {
  
}


locals {
  modulus_az = "${length(split(",", join(", ",data.aws_availability_zones.available.names)))}"
}
