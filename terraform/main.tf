data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  azs        = slice(data.aws_availability_zones.available.names, 0, 2)
  account_id = data.aws_caller_identity.current.account_id
  ecr_url    = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repo_name}"
}

# --- IAM Roles ---

module "iam" {
  source       = "./modules/iam"
  cluster_name = var.cluster_name
}

# --- VPC ---

module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr           = var.vpc_cidr
  cluster_name       = var.cluster_name
  availability_zones = local.azs
}

# --- EKS Cluster + Managed Node Group ---

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  cluster_role_arn   = module.iam.cluster_role_arn
  worker_role_arn    = module.iam.worker_role_arn
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
}

# --- ECR Repository ---

resource "aws_ecr_repository" "hello_api" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# --- Build and Push Docker Image ---

resource "null_resource" "docker_build_push" {
  depends_on = [aws_ecr_repository.hello_api, module.eks]

  triggers = {
    app_hash = sha256(join("", [
      file("${path.module}/../app/index.js"),
      file("${path.module}/../app/package.json"),
      file("${path.module}/../app/Dockerfile"),
    ]))
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      docker build --platform linux/amd64 -t ${local.ecr_url}:latest ${path.module}/../app
      docker push ${local.ecr_url}:latest
    EOT
  }
}

# --- Kubernetes Deployment ---

resource "kubernetes_deployment" "hello_api" {
  depends_on = [null_resource.docker_build_push]

  metadata {
    name = "hello-api"
    labels = {
      app = "hello-api"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "hello-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-api"
        }
      }

      spec {
        container {
          name  = "hello-api"
          image = "${local.ecr_url}:latest"

          port {
            container_port = 3000
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 10
            period_seconds        = 15
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

# --- Kubernetes Service ---

resource "kubernetes_service" "hello_api" {
  metadata {
    name = "hello-api"
    labels = {
      app = "hello-api"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "hello-api"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 3000
    }
  }
}
