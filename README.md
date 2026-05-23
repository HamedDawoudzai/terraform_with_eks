# Hamed's Hello World API on EKS with Terraform

A containerized Node.js API deployed to **AWS EKS** using **Terraform** and **Kubernetes**.

## Overview

This project provisions cloud infrastructure on AWS and deploys a simple Express API that returns `{ "message": "hello world from Hamed's EKS cluster!" }`. Built as a hands-on project to learn Terraform, EKS, and Kubernetes from the ground up.

Everything is deployed through a single `terraform apply`: the VPC, IAM roles, EKS cluster, ECR repository, Docker image build/push, and Kubernetes deployment + service.

## Architecture

```
User Request
  -> AWS Load Balancer (:80)
    -> Kubernetes Service
      -> hello-api Pods (running on EKS Managed Nodes)

┌─────────────────────────────────────────────────────────┐
│                          AWS                            │
│                                                         │
│  ┌────────────────── VPC (10.0.0.0/16) ──────────────┐  │
│  │                                                    │  │
│  │  ┌──────────────┐          ┌──────────────┐        │  │
│  │  │ Public       │          │ Public       │        │  │
│  │  │ Subnet AZ1   │          │ Subnet AZ2   │        │  │
│  │  │ (IGW + NAT)  │          │              │        │  │
│  │  └──────┬───────┘          └──────────────┘        │  │
│  │         │                                          │  │
│  │  ┌──────┴───────┐          ┌──────────────┐        │  │
│  │  │ Private      │          │ Private      │        │  │
│  │  │ Subnet AZ1   │          │ Subnet AZ2   │        │  │
│  │  │ ┌──────────┐ │          │ ┌──────────┐ │        │  │
│  │  │ │  Worker  │ │          │ │  Worker  │ │        │  │
│  │  │ │  Node    │ │          │ │  Node    │ │        │  │
│  │  │ │(t3.med)  │ │          │ │(t3.med)  │ │        │  │
│  │  │ └──────────┘ │          │ └──────────┘ │        │  │
│  │  └──────────────┘          └──────────────┘        │  │
│  │                                                    │  │
│  │             ┌────────────────────────┐              │  │
│  │             │     EKS Cluster        │              │  │
│  │             │  ┌──────────────────┐  │              │  │
│  │             │  │  hello-api       │  │              │  │
│  │             │  │  Deployment (x2) │  │              │  │
│  │             │  └──────────────────┘  │              │  │
│  │             │  ┌──────────────────┐  │              │  │
│  │             │  │  LoadBalancer    │──┼──► :80       │  │
│  │             │  │  Service         │  │              │  │
│  │             │  └──────────────────┘  │              │  │
│  │             └────────────────────────┘              │  │
│  └────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Terraform provisions (in order):**
1. IAM roles for the EKS cluster and worker nodes
2. VPC with public and private subnets across 2 availability zones
3. Internet Gateway and NAT Gateway for network routing
4. EKS cluster with a managed node group (2x `t3.small`)
5. ECR repository for the Docker image
6. Builds and pushes the Docker image to ECR
7. Kubernetes Deployment (2 replicas) and LoadBalancer Service

## Tech Stack

| Layer          | Technology         |
|----------------|--------------------|
| Infrastructure | Terraform, AWS     |
| Orchestration  | Amazon EKS         |
| Application    | Node.js, Express   |
| Container      | Docker, Amazon ECR |
| CI/CD          | GitHub Actions     |

## Project Structure

```
.
├── terraform/                              # Infrastructure as Code
│   ├── main.tf                             # Root module: wires all child modules + K8s resources
│   ├── variables.tf                        # Root-level input variables
│   ├── outputs.tf                          # Root-level outputs (including API URL)
│   ├── provider.tf                         # AWS + Kubernetes provider configuration
│   ├── terraform.tfvars.example            # Example variable values
│   └── modules/                            # Reusable Terraform modules
│       ├── vpc/                            # VPC, subnets, IGW, NAT, route tables
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── iam/                            # IAM roles & policies for cluster + workers
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── eks/                            # EKS cluster, managed node group, security group
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
├── k8s/                                    # Kubernetes manifests (reference only)
│   ├── deployment.yaml
│   └── service.yaml
│
├── app/                                    # Application code
│   ├── index.js                            # Express API server
│   ├── package.json                        # Node.js dependencies
│   ├── Dockerfile                          # Container image definition
│   └── .dockerignore
│
├── .github/workflows/
│   └── deploy.yml                          # CI/CD pipeline
│
└── README.md
```

## Module Breakdown

| Module | Purpose |
|--------|---------|
| `vpc`  | Creates a VPC with public and private subnets across 2 AZs, an Internet Gateway, a NAT Gateway (with Elastic IP), and associated route tables. Private subnets route outbound traffic through the NAT. |
| `iam`  | Defines two IAM roles: a cluster role (with `AmazonEKSClusterPolicy`) and a worker role (with `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`). |
| `eks`  | Provisions the EKS cluster in the private subnets with a public API endpoint, a managed node group (2x `t3.small`, scaling 1-3), and a security group for worker node communication. |

The root `main.tf` also manages the ECR repository, Docker image build/push, and Kubernetes resources directly using the `kubernetes` provider.

## Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with credentials
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [Docker](https://docs.docker.com/get-docker/) (must be running locally for image builds)

## Deploy

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/hello-eks-terraform.git
cd hello-eks-terraform
```

### 2. Configure variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

### 3. Deploy everything

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

That's it. A single `terraform apply` provisions all infrastructure, builds and pushes the Docker image, and deploys the app to the cluster. Takes approximately 15-20 minutes.

### 4. Access the API

Terraform outputs the API URL when it finishes. You can also run:

```bash
terraform output api_url
```

Or configure kubectl and check manually:

```bash
$(terraform output -raw configure_kubectl)
kubectl get svc hello-api
curl http://<EXTERNAL-IP>/hello
```

Expected response:

```json
{ "message": "hello world from Hamed's EKS cluster!" }
```

## Cost Warning

> **Running a managed node EKS cluster with 2 `t3.small` nodes will cost approximately $3/day.** Remember to destroy your resources when you're done testing.

## Cleanup

A single command tears everything down:

```bash
cd terraform
terraform destroy
```

## GitHub Actions

The repo includes a GitHub Actions workflow (`.github/workflows/deploy.yml`) for CI/CD. To use it, add these secrets to your repository:

| Secret                  | Description                |
|-------------------------|----------------------------|
| `AWS_ACCESS_KEY_ID`     | Your AWS access key        |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key        |
| `AWS_REGION`            | AWS region (e.g. us-east-1)|

The workflow is triggered manually via `workflow_dispatch`.

## Lessons Learned

- Learned how to write custom Terraform modules and wire them together from a root module
- Learned Terraform state management and how `terraform plan` / `apply` / `destroy` work as a lifecycle
- Learned how to use the Kubernetes Terraform provider to deploy workloads directly from Terraform
- Learned IAM role design: separate roles for the EKS control plane vs. worker nodes, each with least-privilege policies
- Learned VPC networking: public vs. private subnets, Internet Gateway vs. NAT Gateway, and route table associations
- Learned EKS authentication and how the Kubernetes provider connects to a cluster using cluster certificates and auth tokens
- Learned infrastructure cost awareness: keeping node counts low and using `terraform destroy` to avoid surprise bills

## License

MIT
