# Hamed's Hello World API on AWS EKS with Terraform

> Inspired by [Robert D'Ippolito](https://github.com/robertdippolito/eks-infrastructure-iac). This repo is a learning-oriented adaptation of his production-grade EKS setup, simplified to focus on understanding the IaC workflow end-to-end.

A containerized Node.js API deployed to **AWS EKS** using **Terraform**. Everything (networking, the cluster, the Docker image build, and the Kubernetes deployment) is handled by Terraform through `terraform apply`.

## Why I Built This

I already had hands-on experience with Kubernetes and had worked with both AKS (Azure) and EKS (AWS) before. What I wanted to build was a project that wires it all together using **Infrastructure as Code**, specifically Terraform, so that the entire stack is version-controlled, repeatable, and deployable from a single command rather than a mix of console clicks and manual `kubectl` commands.

## What the App Does

A simple Express API with two endpoints:

| Endpoint  | Response |
|-----------|----------|
| `/hello`  | `{ "message": "hello world from Hamed's EKS cluster!" }` |
| `/health` | `{ "status": "healthy" }` (used by Kubernetes health checks) |

## Key Terms (Beginner Friendly)

If you're new to AWS or cloud infrastructure, these terms come up a lot:

| Term | What it means |
|------|---------------|
| **Terraform** | A tool that lets you describe cloud infrastructure in code (`.tf` files) and create/destroy it with simple commands |
| **IaC** | Infrastructure as Code: managing servers, networks, and services through code instead of clicking around a cloud console |
| **VPC** | Virtual Private Cloud: your own private, isolated network inside AWS |
| **Subnet** | A segment of your VPC. Public subnets are internet-facing; private subnets are internal only |
| **IGW** | Internet Gateway: the connection between your VPC and the public internet |
| **NAT Gateway** | Lets resources in private subnets reach the internet without being reachable from it |
| **IAM** | Identity and Access Management: AWS's permission system, defines what each service is allowed to do |
| **EKS** | Elastic Kubernetes Service: AWS's managed Kubernetes, AWS runs the control plane so you only manage the worker nodes |
| **ECR** | Elastic Container Registry: AWS's private Docker image registry |
| **Managed Node Group** | A group of EC2 virtual machines that EKS uses as worker nodes, with auto-scaling built in |

## Architecture

```
Internet
   |
   v
AWS Load Balancer  (port 80)
   |
   v
Kubernetes Service
   |
   v
hello-api Pods  (2 replicas, running on EKS worker nodes)
```

### What Terraform Creates Inside AWS

```
+----------------------------------------------------------+
|                          AWS                             |
|                                                          |
|  +----------------- VPC (10.0.0.0/16) ----------------+ |
|  |                                                     | |
|  |  Public Subnets (AZ1 + AZ2)                         | |
|  |  +-----------------------------------------------+  | |
|  |  |  Internet Gateway  -->  NAT Gateway           |  | |
|  |  +-----------------------------------------------+  | |
|  |                                                     | |
|  |  Private Subnets (AZ1 + AZ2)                         | |
|  |  +-----------------------------------------------+  | |
|  |  |  Worker Node (t3.small)  Worker Node (t3.small)|  | |
|  |  |                                               |  | |
|  |  |  EKS Cluster                                  |  | |
|  |  |  +------------------------------------------+ |  | |
|  |  |  |  hello-api Pod    hello-api Pod          | |  | |
|  |  |  |  LoadBalancer Service  -->  port 80      | |  | |
|  |  |  +------------------------------------------+ |  | |
|  |  +-----------------------------------------------+  | |
|  +-----------------------------------------------------+ |
|                                                          |
|  ECR Repository  (stores the Docker image)               |
+----------------------------------------------------------+
```

## Tech Stack

| Layer          | Technology           |
|----------------|----------------------|
| Infrastructure | Terraform, AWS       |
| Networking     | AWS VPC, NAT Gateway |
| Orchestration  | Amazon EKS           |
| Application    | Node.js, Express     |
| Container      | Docker, Amazon ECR   |
| CI/CD          | GitHub Actions       |

## Project Structure

```
.
├── app/
│   ├── index.js                  # Express server (/hello + /health)
│   ├── package.json
│   ├── Dockerfile
│   └── .dockerignore
│
├── terraform/
│   ├── main.tf                   # Root: wires modules + ECR + Docker build + K8s resources
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── backend.tf                # Remote state: S3 bucket + DynamoDB lock table
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── vpc/                  # VPC, subnets, IGW, NAT Gateway, route tables
│       ├── iam/                  # IAM roles for EKS control plane + worker nodes
│       └── eks/                  # EKS cluster, managed node group, security group
│
├── k8s/                          # Raw Kubernetes YAML (reference only, Terraform manages these)
│   ├── deployment.yaml
│   └── service.yaml
│
├── bootstrap.sh                  # One-time script to create S3 bucket + DynamoDB table
├── .github/workflows/
│   └── deploy.yml                # GitHub Actions: validate + apply or destroy
└── README.md
```

## How It Works

Terraform handles the full stack in one apply, in this order:

1. **IAM roles** - cluster role (for EKS control plane) and worker node role (for EC2 instances), each with the minimum required AWS policies
2. **VPC + networking** - VPC, public/private subnets across 2 AZs, Internet Gateway, NAT Gateway, route tables
3. **EKS cluster** - control plane + managed node group (`t3.small`, 1-3 nodes), workers sit in private subnets
4. **ECR repository** - private Docker registry for the API image
5. **Docker build + push** - runs as a local-exec provisioner, builds and pushes to ECR
6. **Kubernetes Deployment + Service** - 2 replicas with health probes, exposed via an AWS LoadBalancer on port 80

## Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with credentials
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [Docker](https://docs.docker.com/get-docker/) running locally

## Deploy

### 1. Bootstrap remote state (one-time only)

Before running Terraform for the first time, create the S3 bucket and DynamoDB table it uses to store state:

```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

Terraform stores a state file to track what it has already created. Without it, Terraform has no memory between runs and will try to recreate existing resources. The S3 bucket holds that state file and the DynamoDB table prevents concurrent applies from corrupting it. These need to be created manually before anything else.

### 2. Clone and configure

```bash
git clone https://github.com/hameddawoudzai/terraform_with_aks.git
cd terraform_with_aks
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform.tfvars` with your values if needed.

### 3. Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Takes approximately 15-20 minutes. Terraform will output the API URL when it finishes.

### 4. Test it

```bash
curl http://<EXTERNAL-IP>/hello
```

Expected response:

```json
{ "message": "hello world from Hamed's EKS cluster!" }
```

You can also get the URL directly:

```bash
terraform output api_url
```

Or configure kubectl and inspect the service:

```bash
$(terraform output -raw configure_kubectl)
kubectl get svc hello-api
```

## GitHub Actions

The repo includes a manual CI/CD workflow at `.github/workflows/deploy.yml`. Trigger it from the GitHub Actions tab with either `deploy` or `destroy`.

Required secrets:

| Secret                  | Value               |
|-------------------------|---------------------|
| `AWS_ACCESS_KEY_ID`     | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `AWS_REGION`            | e.g. `us-east-1`   |

## Cost Warning

> Running 2 `t3.small` EKS nodes costs roughly **$2-3/day**. Run `terraform destroy` when you're done to avoid unexpected charges.

## Cleanup

```bash
cd terraform
terraform destroy
```

## What I Got Out of This

- Got a grasp of how Terraform modules work and how a root module wires child modules together
- Started to understand how Terraform state works: why remote state in S3 matters, and why the DynamoDB lock table exists
- Got a better sense of the IAM role separation between the EKS control plane and worker nodes, and roughly which policies each needs
- Began to get a feel for VPC design: why workers go in private subnets, and what the NAT Gateway is actually doing for them
- Became familiar with how Terraform's `kubernetes` provider connects to a cluster using a short-lived token
