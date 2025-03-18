
module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  version              = "5.18.1"
  name                 = "jenkins-vpc"
  cidr                 = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  azs                = data.aws_availability_zones.azs.names
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  enable_nat_gateway = true
  single_nat_gateway = true
  tags = {
    Name        = "jenkins-vpc"
    Terraform   = "true"
    Environment = "dev"
  }
  public_subnet_tags = {
    Name = "jenkins-public-subnet"
  }

}
module "security_group" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "5.3.0"
  name        = "jenkins-sg"
  description = "Security group for jenkins cluster"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "http"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 6443
      to_port     = 6443
      protocol    = "tcp"
      description = "kubernetes api server"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 30000
      to_port     = 32767
      protocol    = "tcp"
      description = "kubernetes node port"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 2379
      to_port     = 2380
      protocol    = "tcp"
      description = "etcd cluster port"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 10250
      to_port     = 10260
      protocol    = "tcp"
      description = "kubernetes"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 9000
      to_port     = 9000
      protocol    = "tcp"
      description = "sonar"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 9090
      to_port     = 9090
      protocol    = "tcp"
      description = "prometheus"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 9100
      to_port     = 9100
      protocol    = "tcp"
      description = "node exporter"
    },
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      description = "grafana"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 50000
      to_port     = 50000
      protocol    = "tcp"
      description = "jenkins"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "http"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "https"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "ssh"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 8081
      to_port     = 8081
      protocol    = "tcp"
      description = "nexus"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 8200
      to_port     = 8200
      protocol    = "tcp"
      description = "vault"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 587
      to_port     = 587
      protocol    = "tcp"
      description = "smtp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_cidr_blocks = ["0.0.0.0/0"]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  tags = {
    Name = "jenkins-sg"
  }
}

// create ec2 instance for jenkins cluster
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.7.1"
  name    = "jenkins-server"

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  monitoring                  = true
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true
  user_data                   = file("jenkins-script.sh")
  availability_zone           = data.aws_availability_zones.azs.names[0]
  tags = {
    Name        = "jenkins-server"
    Terraform   = "true"
    Environment = "dev"
  }
  root_block_device = [
    {
      volume_size = 30
      volume_type = "gp3"
      delete_on_termination = true
  }]

}
