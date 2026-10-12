# Terraform Infrastructure

## Overview

GameVault's AWS infrastructure was provisioned using Terraform. The configuration defines the AWS resources required for the deployment and organizes them into reusable modules.

Terraform was used to manage the network, container image repositories, EKS cluster, IAM permissions, and AWS Load Balancer Controller integration. The configuration can be reviewed and reused to recreate the infrastructure when required.

## Why Terraform?

Terraform was used for the following reasons:

- Infrastructure as Code (IaC)
- Reusable modules
- Version-controlled infrastructure configuration
- Resource dependency management
- Configuration formatting and validation
- Reviewing changes before deployment
- Recreating and removing infrastructure through code

## AWS Services Used

| AWS service | Purpose |
|---|---|
| Amazon VPC | Provides the network for the deployment |
| Public and private subnets | Separate internet-facing resources from worker nodes |
| Internet Gateway | Provides internet connectivity to public subnets |
| Amazon EKS | Hosts the Kubernetes control plane |
| EKS Managed Node Group | Provides EC2 worker nodes |
| Amazon ECR | Stores container images |
| AWS IAM | Manages roles and permissions |
| AWS Load Balancer Controller | Connects Kubernetes Ingress resources with AWS load balancers |
| Application Load Balancer | Routes incoming HTTP traffic |
| Amazon EBS | Provides persistent block storage |
| EBS CSI Driver | Allows Kubernetes to provision and use EBS volumes |

## Terraform Directory Structure

```text
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── versions.tf
├── terraform.tfvars
└── modules/
    ├── network/
    ├── ecr/
    ├── eks/
    ├── alb-controller/
    └── gamevault-kubernetes/
```

## Root Terraform Files

### `main.tf`

Connects the Terraform modules and defines the overall infrastructure configuration. It passes variables and outputs between modules and establishes dependencies between AWS and Kubernetes resources.

### `variables.tf`

Defines configurable infrastructure values, including:

- AWS region
- Environment name
- VPC and subnet CIDRs
- Availability Zones
- EKS cluster name and Kubernetes version
- Worker node count and EC2 instance type
- ECR repository names
- Kubernetes namespace
- Application infrastructure settings

### `terraform.tfvars`

Provides the values used for the GameVault environment.

The deployment used the following configuration:

```hcl
environment          = "dev"
aws_region           = "ap-south-1"
vpc_name             = "gamevault-vpc"
vpc_cidr             = "10.0.0.0/16"
eks_cluster_name     = "gamevault-eks"
kubernetes_namespace = "gamevault"
```

Keep this example consistent with the actual variable names and values in your configuration. AWS credentials and sensitive information should never be committed to GitHub.

### `outputs.tf`

Defines useful information returned by Terraform, such as:

- VPC and subnet IDs
- EKS cluster name and endpoint
- EKS node group information
- ECR repository URLs
- IAM role information
- Kubernetes namespace
- Ingress hostname

The available outputs depend on the resources and output definitions in the modules.

### `providers.tf`

Configures the providers used to manage AWS infrastructure and Kubernetes resources, including AWS, Kubernetes, Helm, and TLS.

### `versions.tf`

Defines Terraform and provider version requirements to help maintain consistent behavior across deployments.

# Terraform Modules

## 1. Network Module

**Location:** `modules/network/`

The network module defines the AWS networking resources used by GameVault.

Its configuration covers:

- VPC
- Internet Gateway
- Public and private subnets
- Route tables
- Route table associations
- Security group for the Application Load Balancer

### Network Layout

```text
                  Internet
                     |
                     v
              Internet Gateway
                     |
                 GameVault VPC
                     |
             +-------+-------+
             |               |
        Public Subnets   Private Subnets
             |               |
          AWS ALB         EKS Nodes
```

The public subnets support internet-facing infrastructure, while the private subnets are used for the EKS worker nodes.

Private subnet access to the internet or AWS APIs depends on the configured NAT Gateway or VPC endpoints.

## 2. ECR Module

**Location:** `modules/ecr/`

The ECR module manages the Amazon Elastic Container Registry repositories used by GameVault.

The configuration includes repository settings and, where defined, image tag mutability, image scanning, lifecycle policies, and resource tags.

The ECR repositories used by the deployment include:

- `gamevault-api`
- `gamevault-worker`

ECR allows the EKS workloads to pull their container images from a private registry.

## 3. EKS Module

**Location:** `modules/eks/`

The EKS module defines the Kubernetes cluster and worker infrastructure.

Its resources include:

- Amazon EKS cluster
- Cluster IAM role
- Managed node group
- Worker-node IAM role
- Required IAM policy attachments
- EKS Pod Identity Agent
- AWS EBS CSI Driver add-on

### EKS Layout

```text
                 Amazon EKS
                     |
          +----------+----------+
          |                     |
     Control Plane        Managed Node Group
                                 |
                         +-------+-------+
                         |               |
                      EC2 Node        EC2 Node
```

AWS manages the EKS control plane, while the managed node group provides the compute capacity for Kubernetes workloads.

The cluster used for the GameVault deployment was named `gamevault-eks`, with the managed node group `gamevault-eks-nodes`.

## 4. AWS Load Balancer Controller Module

**Location:** `modules/alb-controller/`

The AWS Load Balancer Controller connects Kubernetes Ingress resources to AWS Elastic Load Balancing.

The module configures the IAM permissions and Kubernetes integration required by the controller, including the resources defined for OIDC integration, the Kubernetes ServiceAccount, and the Helm release.

### Traffic Flow

```text
Internet
   |
   v
Application Load Balancer
   |
   v
Kubernetes Ingress
   |
   v
Kubernetes Service
```

The controller manages the AWS load balancer associated with the Kubernetes Ingress configuration.

## 5. GameVault Kubernetes Module

**Location:** `modules/gamevault-kubernetes/`

This module defines the Kubernetes resources deployed to the EKS cluster.

It contains the application-layer infrastructure configuration, including Deployments, Services, storage resources, autoscaling configuration, and Ingress.

Keeping these resources in a separate module makes the Kubernetes configuration easier to maintain independently from the AWS network and EKS cluster definitions.

# Persistent Storage with Amazon EBS

The EBS CSI Driver integrates Amazon EBS storage with Kubernetes.

The storage flow is:

```text
Kubernetes PersistentVolumeClaim
              |
              v
         StorageClass
              |
              v
        EBS CSI Driver
              |
              v
        Amazon EBS Volume
```

This allows Kubernetes to provision EBS storage for workloads that require persistent volumes. Data persistence depends on the volume lifecycle and the configured reclaim policy; deleting a pod alone does not necessarily delete its volume.

# Infrastructure Dependencies

The main infrastructure dependency flow is:

```text
VPC
 |
 +---- ECR
 |
 +---- EKS Cluster
          |
          +---- Managed Node Group
          |
          +---- EBS CSI Driver
          |
          +---- AWS Load Balancer Controller
          |
          +---- Kubernetes Resources
```

The VPC and subnets provide the networking required by EKS. The cluster must be available before its Kubernetes resources can be managed. The Load Balancer Controller must also be configured before the Ingress can be used to manage the associated AWS load balancer.

# Terraform Workflow

The following commands are used to initialize, validate, and manage the infrastructure.

### Initialize Terraform

```bash
terraform init
```

Downloads the required providers and initializes the working directory.

### Format the configuration

```bash
terraform fmt -recursive
```

Formats Terraform files consistently, including files inside modules.

### Validate the configuration

```bash
terraform validate
```

Checks the Terraform configuration for syntax and internal consistency.

### Review infrastructure changes

```bash
terraform plan
```

Shows the proposed changes before they are applied.

### Create or update infrastructure

```bash
terraform apply
```

Applies the reviewed infrastructure changes after confirmation.

# AWS Authentication

Terraform needs valid AWS credentials and appropriate IAM permissions to manage the configured resources.

Configure the AWS CLI with:

```bash
aws configure
```

Check the active AWS identity with:

```bash
aws sts get-caller-identity
```

The IAM identity must have the permissions required by the Terraform configuration. Credentials should be stored securely and must not be committed to GitHub.

# AWS Networking Considerations

EKS worker nodes in private subnets require access to the AWS services needed by their workloads, including ECR for pulling images.

Depending on the network design, connectivity may be provided through a NAT Gateway or suitable VPC endpoints.

Before recreating the infrastructure, check:

- Private subnet routing
- ECR image-pull connectivity
- Required AWS API access
- Security group rules
- IAM permissions for the EKS cluster and controllers

These settings affect whether the worker nodes can initialize and run workloads correctly.

# AWS Costs and Resource Cleanup

The infrastructure uses AWS resources that may incur charges, including:

- Amazon EKS cluster
- EC2 worker nodes
- EBS volumes
- Application Load Balancer
- Public IPv4 addresses
- NAT Gateway, if configured
- ECR image storage

The AWS environment was used to deploy the infrastructure and capture project screenshots. The Terraform configuration was retained so it can be reviewed and used for future deployments without keeping the environment running unnecessarily.

## Destroying the Infrastructure

Before removing the infrastructure, preview the resources Terraform plans to destroy:

```bash
terraform plan -destroy
```

After reviewing the plan, remove the resources managed by the current Terraform state:

```bash
terraform destroy
```

Confirm the proposed removals before proceeding. This operation can remove Kubernetes workloads and infrastructure, and may affect persistent storage.

Afterwards, check the AWS Console for any remaining billable resources that were created outside Terraform or were not removed successfully.

# Security Considerations

The following practices are important when managing the infrastructure:

- Never commit AWS access keys or database passwords.
- Use IAM roles with least-privilege permissions.
- Keep worker nodes in private subnets where appropriate.
- Review security groups and routing rules.
- Protect Terraform state because it may contain sensitive information.
- Review plans before applying or destroying resources.
- Keep providers and infrastructure dependencies updated.
- Review the permissions granted to Kubernetes controllers.

# Summary

The Terraform configuration for GameVault demonstrates how AWS infrastructure can be defined and managed through reusable modules.

The infrastructure covers VPC networking, ECR repositories, an EKS cluster, managed worker nodes, IAM permissions, the AWS Load Balancer Controller, and persistent storage integration with Amazon EBS.

The deployment provided practical experience with Terraform module design, AWS resource dependencies, Kubernetes infrastructure, and cloud resource management. The Terraform files remain available for inspection and redeployment.