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
  cluster_version = "1.31"
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

  # Resource Limits and Requests
  resources = {
    limits = {
      cpu    = "4000m"     # 4 CPU cores
      memory = "16Gi"      # 16GB memory
    }
    requests = {
      cpu    = "2000m"     # 2 CPU cores
      memory = "8Gi"       # 8GB memory
    }
  }

  # Weaviate-specific configurations
  weaviate_replication_factor = 1

  # Node Affinity and Anti-Affinity (to spread pods across AZs)
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [{
          matchExpressions = [{
            key      = "worker-group"
            operator = "In"
            values   = ["weaviate-workload"]
          }]
        }]
      }
    }
    podAntiAffinity = {
      preferredDuringSchedulingIgnoredDuringExecution = [
        {
          weight = 100
          podAffinityTerm = {
            labelSelector = {
              matchExpressions = [
                {
                  key      = "app"
                  operator = "In"
                  values   = ["weaviate"]
                }
              ]
            }
            topologyKey = "topology.kubernetes.io/zone"
          }
        }
      ]
    }
  }

  # Tolerations for dedicated nodes
  tolerations = [
    {
      key      = "workload-type"
      operator = "Equal"
      value    = "weaviate"
      effect   = "NoSchedule"
    }
  ]

  # Persistent Volume Configuration
  volume_claim_templates = [{
    metadata = {
      name      = "weaviate-data"
      namespace = var.namespace
    }
    spec = {
      accessModes      = ["ReadWriteOnce"]
      storageClassName = "gp3"  # Using GP3 for better performance
      resources = {
        requests = {
          storage = "100Gi"  # Adjust based on your data size requirements
        }
      }
    }
  }]

  # Resource QoS class: Guaranteed (requests = limits)
  guaranteed_qos = true

  # Additional configurations
  env = [
    {
      name  = "ENABLE_MODULES"
      value = "backup-filesystem,text2vec-transformers"
    },
    {
      name  = "QUERY_DEFAULTS_LIMIT"
      value = "25"
    },
    {
      name  = "AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED"
      value = "false"
    },
    {
      name  = "PERSISTENCE_DATA_PATH"
      value = "/var/lib/weaviate"
    },
    {
      name  = "LIMIT_RESOURCES"
      value = "true"
    }
  ]

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

################################################################################
# Weaviate Resource Configuration
################################################################################

module "weaviate_helm" {
  source = "./modules/weaviate"

  # HA Setup
  replica_count = 2

  # Resource Limits and Requests
  resources = {
    limits = {
      cpu    = "4000m"     # 4 CPU cores
      memory = "16Gi"      # 16GB memory
    }
    requests = {
      cpu    = "2000m"     # 2 CPU cores
      memory = "8Gi"       # 8GB memory
    }
  }

  # Weaviate-specific configurations
  weaviate_replication_factor = 1

  # Node Affinity and Anti-Affinity (to spread pods across AZs)
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [{
          matchExpressions = [{
            key      = "worker-group"
            operator = "In"
            values   = ["weaviate-workload"]
          }]
        }]
      }
    }
    podAntiAffinity = {
      preferredDuringSchedulingIgnoredDuringExecution = [
        {
          weight = 100
          podAffinityTerm = {
            labelSelector = {
              matchExpressions = [
                {
                  key      = "app"
                  operator = "In"
                  values   = ["weaviate"]
                }
              ]
            }
            topologyKey = "topology.kubernetes.io/zone"
          }
        }
      ]
    }
  }

  # Tolerations for dedicated nodes
  tolerations = [
    {
      key      = "workload-type"
      operator = "Equal"
      value    = "weaviate"
      effect   = "NoSchedule"
    }
  ]

  # Persistent Volume Configuration
  volume_claim_templates = [{
    metadata = {
      name      = "weaviate-data"
      namespace = var.namespace
    }
    spec = {
      accessModes      = ["ReadWriteOnce"]
      storageClassName = "gp3"  # Using GP3 for better performance
      resources = {
        requests = {
          storage = "100Gi"  # Adjust based on your data size requirements
        }
      }
    }
  }]

  # Resource QoS class: Guaranteed (requests = limits)
  guaranteed_qos = true

  # Additional configurations
  env = [
    {
      name  = "ENABLE_MODULES"
      value = "backup-filesystem,text2vec-transformers"
    },
    {
      name  = "QUERY_DEFAULTS_LIMIT"
      value = "25"
    },
    {
      name  = "AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED"
      value = "false"
    },
    {
      name  = "PERSISTENCE_DATA_PATH"
      value = "/var/lib/weaviate"
    },
    {
      name  = "LIMIT_RESOURCES"
      value = "true"
    }
  ]

  depends_on = [
    kubernetes_namespace.weaviate-namespace
  ]
}

################################################################################
# Additional Variables
################################################################################

variable "weaviate_resources" {
  description = "Resource limits and requests for Weaviate pods"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "4000m"
      memory = "16Gi"
    }
    requests = {
      cpu    = "2000m"
      memory = "8Gi"
    }
  }
}

variable "weaviate_storage" {
  description = "Storage configuration for Weaviate"
  type = object({
    size          = string
    storage_class = string
  })
  default = {
    size          = "100Gi"
    storage_class = "gp3"
  }
}

################################################################################
# Resource Monitoring ConfigMap
################################################################################

resource "kubernetes_config_map" "weaviate_monitoring" {
  metadata {
    name      = "weaviate-monitoring-config"
    namespace = var.namespace
  }

  data = {
    "resource-monitoring.yaml" = <<-EOT
      monitoring:
        enabled: true
        prometheus:
          enabled: true
        resources:
          memory_threshold: "80"  # Alert at 80% memory usage
          cpu_threshold: "75"     # Alert at 75% CPU usage
    EOT
  }
}

################################################################################
# Horizontal Pod Autoscaling
################################################################################

resource "kubernetes_horizontal_pod_autoscaler_v2" "weaviate" {
  metadata {
    name      = "weaviate-hpa"
    namespace = var.namespace
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "StatefulSet"
      name        = "weaviate"
    }

    min_replicas = 2
    max_replicas = 5

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 75
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 300
        select_policy               = "Max"
        policies {
          type          = "Pods"
          value         = 2
          period_seconds = 300
        }
      }
      scale_down {
        stabilization_window_seconds = 300
        select_policy               = "Min"
        policies {
          type          = "Pods"
          value         = 1
          period_seconds = 300
        }
      }
    }
  }
}
