variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Weaviate"
  type        = string
  default     = "weaviate"
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "weaviate" {
  description = "Weaviate configuration"
  type = object({
    replica_count = number
    resources = object({
      limits = object({
        cpu    = string
        memory = string
      })
      requests = object({
        cpu    = string
        memory = string
      })
    })
    storage = object({
      size          = string
      storage_class = string
    })
    monitoring = object({
      memory_threshold = number
      cpu_threshold    = number
    })
    env_vars = map(string)
    autoscaling = object({
      min_replicas = number
      max_replicas = number
      scale_up = object({
        stabilization_window_seconds = number
        select_policy               = string
        policies = list(object({
          type           = string
          value         = number
          period_seconds = number
        }))
      })
      scale_down = object({
        stabilization_window_seconds = number
        select_policy               = string
        policies = list(object({
          type           = string
          value         = number
          period_seconds = number
        }))
      })
    })
  })
  default = {
    replica_count = 2
    resources = {
      limits = {
        cpu    = "4000m"
        memory = "16Gi"
      }
      requests = {
        cpu    = "2000m"
        memory = "8Gi"
      }
    }
    storage = {
      size          = "100Gi"
      storage_class = "gp3"
    }
    monitoring = {
      memory_threshold = 80
      cpu_threshold    = 75
    }
    env_vars = {
      ENABLE_MODULES                         = "backup-filesystem,text2vec-transformers"
      QUERY_DEFAULTS_LIMIT                   = "25"
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED = "false"
      PERSISTENCE_DATA_PATH                  = "/var/lib/weaviate"
      LIMIT_RESOURCES                        = "true"
    }
    autoscaling = {
      min_replicas = 2
      max_replicas = 5
      scale_up = {
        stabilization_window_seconds = 300
        select_policy               = "Max"
        policies = [{
          type           = "Pods"
          value         = 2
          period_seconds = 300
        }]
      }
      scale_down = {
        stabilization_window_seconds = 300
        select_policy               = "Min"
        policies = [{
          type           = "Pods"
          value         = 1
          period_seconds = 300
        }]
      }
    }
  }
}