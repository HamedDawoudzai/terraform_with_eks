output "vpc_id" {
  description = "Hamed's VPC"
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "Hamed's first EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Hamed's endpoint for the EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Hamed's command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_repository_url" {
  description = "Hamed's ECR repository URL"
  value       = aws_ecr_repository.hello_api.repository_url
}

output "api_url" {
  description = "Hamed's API endpoint (hit /hello)"
  value       = "http://${kubernetes_service.hello_api.status[0].load_balancer[0].ingress[0].hostname}/hello"
}
