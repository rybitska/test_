variable "untagged_images" {
  default = 3
}

variable "volume_size" {
  description = "The volume size for the EBS storage that is used by EC2 which holds the Ethereum blocks"
  default = "2047"
}
