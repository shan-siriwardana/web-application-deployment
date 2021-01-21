####### provider  #######

provider "aws" {
  profile = "default"
  shared_credentials_file = "/var/credentials"
  region  = "ap-southeast-1"
}

####### s3 bucket #######

resource "aws_s3_bucket" "s3_file_upload" {
  bucket = "web-user-file-upload-bucket-121231"
  acl    = "private"
  tags = {
    "Terraform" : "true"
  }
}
