
# Berkeley Visitor Counter

A simple Flask web application that tracks page visits using Redis as a cache for the backend counter. Each visit increments a Redis key and displays the current visitor count.

The application is containerized using Docker, deployed on Amazon EKS (Kubernetes), and uses Amazon ElastiCache for Redis as the backend to store and increment the visitor counter.

---

## Tech Stack

* Python (Flask)
* Redis
* Docker
* Kubernetes (EKS)
* Amazon ElastiCache (redis)
* Terraform (for infrastructure)

---

## How It Works

* The app connects to Redis using environment variables:

  * `REDIS_HOST`
  * `REDIS_PORT`
* Each request to `/` runs Redis `INCR` to atomically increment the counter.
* The updated visitor count is returned in the response.

Example:

```
This is the '1' visitor 
This is the '2' visitor 
```

---

## Project Structure

```
.
├── app.py
├── requirements.txt
├── Dockerfile
├── README.md
└── terraform/
    ├── provider.tf
    ├── backend.tf
    ├── variables.tf
    ├── backend-dev.hcl      
    ├── backend-nonprod.hcl  
    ├── backend-prod.hcl    
    ├── main.tf
    ├── outputs.tf
    ├── dev.tfvars
    ├── non-prod.tfvars
    └── prod.tfvars
```

---

## Environment Variables

| Variable   | Description    | Default   |
| ---------- | -------------- | --------- |
| REDIS_HOST | Redis hostname | localhost |
| REDIS_PORT | Redis port     | 6379      |

---

The environment variable values will be defined in Kubernetes Deployment files for EKS

## Run Locally

## Build Docker Image

```
docker build -t berkeley-visitor-counter:1.0 .
```

---

### Start Redis (create another container)

```
docker run -d --name redis -p 6379:6379 redis
```

### Run Application

```
docker run -d \
  -p 80:8080 \
  -e REDIS_HOST=host.docker.internal \
  -e REDIS_PORT=6379 \
  berkeley-visitor-counter:1.0
```

Open:

```
http://localhost
```

Refresh to see the counter increment.

---

## Run in Kubernetes (EKS)

In Kubernetes, pass the ElastiCache endpoint via environment variables:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: visitor-counter
  labels:
    app: visitor-counter
spec:
  replicas: 2
  selector:
    matchLabels:
      app: visitor-counter
  template:
    metadata:
      labels:
        app: visitor-counter
    spec:
      containers:
        - name: visitor-counter
          image: <ecr_image_url>
          ports:
            - containerPort: 8080
          env:
            - name: REDIS_HOST
              value: "your-elasticache-endpoint.cache.amazonaws.com"
            - name: REDIS_PORT
              value: "6379"
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 250m
              memory: 256Mi


where 
env:
  - name: REDIS_HOST
    value: your-elasticache-endpoint.cache.amazonaws.com

  - name: REDIS_PORT
    value: "6379"
```


## Infrastructure (Terraform)

All AWS infrastructure is managed with Terraform using official modules.

### Architecture

```
Users → Route 53 → IGW → ALB (Public Subnets)
                              ↓
                    EKS Workers (Private Subnets) → ElastiCache Redis (Private Subnets)
                              ↓
                    NAT Gateway → Internet (for pulling images)
```

### Resources Created

| Module | What it creates |
|--------|----------------|
| IAM | Cluster manager user (least privilege), developer role (read-only) |
| VPC | VPC,  public subnets,  private subnets, NAT Gateway, IGW, route tables |
| EKS | Kubernetes cluster, managed node group, security groups, KMS encryption |
| ElastiCache | Redis replication group, subnet group, security group |

### Terraform File Structure

```
terraform/
├── provider.tf          # AWS provider configuration
├── backend.tf           # S3 remote state configuration
├── backend-dev.hcl      # Dev backend state key
├── backend-nonprod.hcl  # Non-Prod backend state key
├── backend-prod.hcl     # Prod backend state key
├── variables.tf         # Variable definitions
├── main.tf              # IAM, VPC, EKS, ElastiCache modules
├── outputs.tf           # Resource outputs
├── dev.tfvars           # Dev environment values
├── nonprod.tfvars       # Non-Prod environment values
└── prod.tfvars          # Prod environment values
```

### Multi-Environment Support

Same code, different values per environment:

| Config | Dev | Non-Prod | Prod |
|--------|-----|----------|------|
| Node type | t3.micro | t3.medium | t3.medium |
| Node count | 1-2 | 2-5 | 2-5 |
| Redis type | cache.t3.micro | cache.t3.medium | cache.t3.medium |
| Redis replicas | 1 (no replica) | 2 (primary + replica) | 2 (primary + replica) |
| Multi-AZ failover | No | Yes | Yes |

### Deploy Infrastructure

```bash
# Prerequisites
# - AWS CLI configured
# - Terraform >= 1.5.0
# - S3 bucket for state: berkeley-tf-state

# Initialize
terraform init -backend-config=backend-dev.hcl
terraform init -backend-config=backend-prod.hcl
terraform init -backend-config=backend-non-prod.hcl

# Plan
terraform plan -var-file="dev.tfvars"

# Apply
terraform apply -var-file="dev.tfvars"

# Destroy
terraform destroy -var-file="dev.tfvars"
```

### IAM Access Model

| User/Role | AWS Permissions | EKS Access | Purpose |
|-----------|----------------|------------|---------|
| berkeley-cluster-manager | Least privilege (EKS, VPC, ElastiCache, IAM for EKS, KMS, CloudWatch, S3 state) | Cluster admin | Runs Terraform, manages infra |
| developer-role | ReadOnlyAccess | View only (dev, sit namespaces) | Dev team access |

### Security

* EKS secrets encrypted with KMS
* Node EBS volumes encrypted with KMS
* ElastiCache encryption at rest and in transit
* Redis accessible only from EKS worker nodes (security group)
* Workers in private subnets, no direct internet access
* Least privilege IAM policies
* VPC Flow Logs enabled for network auditing
* EKS API endpoint private-only in production
* Separate state files per environment to prevent cross-environment impact
