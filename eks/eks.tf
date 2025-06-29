module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.name
  cluster_version = "1.31"

  # EKS Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  create_cluster_security_group            = true
  create_node_security_group               = true
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    Bankapp-node = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t2.medium"]
      capacity_type  = "SPOT"
      volume_size    = 20
      volume_type    = "gp3"
      min_size       = 3
      max_size       = 4
      desired_size   = 3
    }
  }
  tags       = local.tags
  depends_on = [module.vpc]
}

#to connect eks to kubernetes cluster
#aws eks --region us-east-1 update-kubeconfig --name cluster-name
#openID connect oidc provider for eks
#eksctl utils associate-iam-oidc-provider --region us-east-1--cluster-name cluster-name --approve
