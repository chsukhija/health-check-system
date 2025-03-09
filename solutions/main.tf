terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Data Sources
data "aws_eks_cluster" "main" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "main" {
  name = var.eks_cluster_name
}

# Providers
provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

# Local Variables
locals {
  name   = var.eks_cluster_name
  region = var.region

  tags = merge(
    var.tags,
    {
      Name        = local.name
      Environment = var.environment
      Terraform   = "true"
    }
  )
}

# Weaviate Module
module "weaviate" {
  source = "./modules/weaviate"

  namespace = var.namespace
  
  config = {
    replica_count = var.weaviate.replica_count
    resources     = var.weaviate.resources
    storage       = var.weaviate.storage
    monitoring    = var.weaviate.monitoring
    env_vars     = var.weaviate.env_vars
  }

  depends_on = [
    kubernetes_namespace.weaviate
  ]
}

# Kubernetes Resources
resource "kubernetes_namespace" "weaviate" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

resource "kubernetes_config_map" "weaviate_monitoring" {
  metadata {
    name      = "weaviate-monitoring"
    namespace = kubernetes_namespace.weaviate.metadata[0].name
    labels    = local.tags
  }

  data = {
    "monitoring.yaml" = yamlencode({
      monitoring = {
        enabled = true
        prometheus = {
          enabled = true
        }
        thresholds = var.weaviate.monitoring
      }
    })
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "weaviate" {
  metadata {
    name      = "weaviate"
    namespace = kubernetes_namespace.weaviate.metadata[0].name
    labels    = local.tags
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "StatefulSet"
      name        = "weaviate"
    }

    min_replicas = var.weaviate.autoscaling.min_replicas
    max_replicas = var.weaviate.autoscaling.max_replicas

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = var.weaviate.monitoring.cpu_threshold
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = var.weaviate.monitoring.memory_threshold
        }
      }
    }

    behavior {
      scale_up   = var.weaviate.autoscaling.scale_up
      scale_down = var.weaviate.autoscaling.scale_down
    }
  }
}
