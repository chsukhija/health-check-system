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
      api_version = "client.authentication.k8s.io/v1beta1"  # Updated to v1beta1
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

# Add EKS Cluster and VPC resources here
module "eks_cluster" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 18.0"
  cluster_name    = var.eks_cluster_name
  cluster_version = "1.21"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  # Add other necessary configurations for EKS cluster
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "${var.eks_cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  # Add other necessary configurations for VPC
}

################################################################################
# Kubernetes Namespace for Weaviate
################################################################################

resource "kubernetes_namespace" "weaviate-namespace" {
  metadata {
    name = var.namespace
  }
}

################################################################################
# High Availability Setup for Weaviate
################################################################################

module "weaviate_helm" {
  source = "./modules/weaviate"

  # HA Setup
  replica_count = 2

  # Weaviate-specific configurations
  weaviate_replication_factor = 1

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
          }
          topologyKey = "topology.kubernetes.io/zone"
        },
      ]
    }
  }

  # Tolerations (if needed based on your taints setup)
  tolerations = [
    # Tolerations configuration here
          {
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
      namespace = "weaviate-namespace" # Uncomment and set if needed
    }
    spec = {
      accessModes = ["ReadWriteOnce"]
      storageClassName = "standard" # Replace with your desired StorageClass
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

# Add additional modules and resources here as needed

################################################################################
# Variable Definitions
################################################################################

variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "eks_cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}

variable "aws_default_tags" {
  description = "Default tags to apply to AWS resources"
  type        = map(string)
  default     = {}
}

variable "namespace" {
  description = "The Kubernetes namespace for Weaviate"
  type        = string
  default     = "weaviate"
}
