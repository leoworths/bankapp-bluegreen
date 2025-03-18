data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu*-amd64-server-*"] # This will match any version
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


    