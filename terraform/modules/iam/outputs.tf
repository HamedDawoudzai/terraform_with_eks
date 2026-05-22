output "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.cluster.arn
}

output "worker_role_arn" {
  description = "ARN of the EKS worker node IAM role"
  value       = aws_iam_role.worker.arn
}
