################################################################################
# Providers
################################################################################


provider "aws" {
 region = var.region
 default_tags {
   tags = local.aws_default_tags
 }
}


provider "kubernetes" {
 host                   = data.aws_eks_cluster.main.endpoint
 cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
 exec {
   api_version = "client.authentication.k8s.io/v1beta1"
   command     = "aws"
   args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name]
 }
}


provider "helm" {
 kubernetes {
   host                   = data.aws_eks_cluster.main.endpoint
   cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
   exec {
     api_version = "client.authentication.k8s.io/v1alpha1"
     command     = "aws"
     args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name]
   }
 }
}


data "aws_eks_cluster" "main" {
 name = var.eks_cluster_name
}


################################################################################
# Local Variables
################################################################################


locals {
 aws_default_tags = merge(
   {"clusterName": var.eks_cluster_name},
   var.aws_default_tags,
 )
 customer_identifier         = trimprefix(var.eks_cluster_name, "wv-")
 customer_cluster_identifier = "prod-dedicated-enterprise"
}


################################################################################
# EKS Cluster and VPC Configuration
################################################################################

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.eks_cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway     = true
  single_nat_gateway     = false  # HA setup with NAT gateway per AZ
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # Tags required for EKS
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name                   = var.eks_cluster_name
  cluster_version               = var.kubernetes_version
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Enable encryption for secrets
  cluster_encryption_config = [{
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }]

  # EKS Managed Node Group
  eks_managed_node_groups = {
    general = {
      desired_size = 3
      min_size     = 3
      max_size     = 5

      instance_types = ["t3.xlarge"]
      capacity_type  = "ON_DEMAND"

      # Enable node-to-node encryption
      enable_bootstrap_user_data = true
      bootstrap_extra_args      = "--enable-docker-bridge true --kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=normal'"

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type          = "gp3"
            iops                 = 3000
            encrypted           = true
            delete_on_termination = true
          }
        }
      }

      tags = {
        "k8s.io/cluster-autoscaler/enabled" = "true"
        "k8s.io/cluster-autoscaler/${var.eks_cluster_name}" = "owned"
      }
    }
  }

  # IRSA for cluster autoscaler
  enable_irsa = true

  # Node security group additional rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }
}

# KMS key for EKS cluster encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.eks_cluster_name}-eks-encryption-key"
  }
}

# Cluster Autoscaler IAM Role
module "cluster_autoscaler_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                        = "cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_ids   = [module.eks.cluster_id]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
}

# CloudWatch Log Group for EKS cluster logs
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.eks_cluster_name}/cluster"
  retention_in_days = 30
}

# Additional security group rules for control plane
resource "aws_security_group_rule" "eks_api_private" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = module.eks.node_security_group_id
  description             = "Allow nodes to communicate with the cluster API Server"
}

# Outputs
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}


################################################################################
# High Availability Setup for Weaviate
################################################################################


module "weaviate_helm" {
 source                        = "./modules/weaviate"
  # ... (existing configuration)


 # HA Setup
 replica_count                 = 2 


 # Weaviate-specific configurations
 weaviate_replication_factor   = 1 


 # Node Affinity and Anti-Affinity (to spread pods across AZs)
 affinity = {
   podAntiAffinity = {
     requiredDuringSchedulingIgnoredDuringExecution = [
       {
         labelSelector = {
           matchExpressions = [
             {
               key      = "app"
               operator = "In"
               values   = ["weaviate"]
             },
           ]
         },
         topologyKey = "topology.kubernetes.io/zone"
       },
     ]
   }
 }


 # Tolerations (if needed based on your taints setup)
 tolerations = [
   # Tolerations configuration here
         `{
             key      = "example-key"
             operator = "Equal"
             value    = "example-value"
             effect   = "NoSchedule"
           },
 
           # Example: Tolerate any taint with key "another-key" and effect "NoExecute" for 1 hour
           {
             key                = "another-key"
             operator           = "Exists"
             effect             = "NoExecute"
             toleration_seconds = 3600
           }
 ]


 # Persistent Volume Claim Issue
 volume_claim_templates = [{
   metadata = {
     name = "weaviate-data"
   }
   spec = {
     accessModes = ["ReadWriteOnce"]
     resources = {
       requests = {
         storage = "10Gi"
       }
     }
   }
 }]


 depends_on = [
   kubernetes_namespace.weaviate-namespace
 ]
}


################################################################################
# Additional Modules and Resources
################################################################################


# What additional modules should be added here?


################################################################################
# Kubernetes Namespace for Weaviate
################################################################################


resource "kubernetes_namespace" "weaviate-namespace" {
 metadata {
   name = var.namespace
 }
}


















