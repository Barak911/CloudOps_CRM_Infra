# Architecture Documentation

## Overview

This document describes the architecture for the Develeap Portfolio Project - a cloud-native CRM application with CI/CD pipeline.

## Stage 1: 2-Tier Architecture

### Application Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet/Users                         │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ HTTPS/HTTP
                        ▼
┌───────────────────────────────────────────────────────────┐
│              AWS Load Balancer (ELB)                      │
│          (Created by K8S LoadBalancer Service)            │
└───────────────────────┬───────────────────────────────────┘
                        │
            ┌───────────┴───────────┐
            │                       │
            ▼                       ▼
    ┌───────────────┐      ┌───────────────┐
    │   CRM App     │      │   CRM App     │
    │   Pod (1)     │      │   Pod (2)     │
    │               │      │               │
    │ Python Flask  │      │ Python Flask  │
    │ Port: 5000    │      │ Port: 5000    │
    │               │      │               │
    │ Gunicorn      │      │ Gunicorn      │
    └───────┬───────┘      └───────┬───────┘
            │                      │
            └──────────┬───────────┘
                       │
                       │ MongoDB Protocol
                       │ (Internal Service)
                       ▼
            ┌─────────────────────┐
            │   MongoDB Pod       │
            │   (StatefulSet)     │
            │                     │
            │   Port: 27017       │
            │   Database: crm_db  │
            │                     │
            │   Persistent Volume │
            │   (5Gi EBS)         │
            └─────────────────────┘
```

### Components

**Tier 1: Application Layer**
- 2x CRM App Pods (Deployment)
- Python Flask REST API
- Gunicorn WSGI server
- Health checks on /health endpoint
- Auto-scaling ready

**Tier 2: Database Layer**
- MongoDB StatefulSet (1 replica)
- Persistent storage (AWS EBS)
- Headless service for stable DNS
- Data persistence across pod restarts

## Complete CI/CD Workflow Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Developer Workflow                        │
└──────────────────────────────────────────────────────────────────┘
                               │
                               │ git push
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                         GitHub                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐  │
│  │   application    │  │  infrastructure  │  │cluster-resources│ │
│  │   repository     │  │   repository     │  │   repository   │  │
│  │  (source code)   │  │  (terraform)     │  │  (k8s yaml)    │  │
│  └────────┬─────────┘  └──────────────────┘  └────────────────┘  │
└───────────┼──────────────────────────────────────────────────────┘
            │
            │ Trigger on push to main
            ▼
┌──────────────────────────────────────────────────────────────────┐
│              GitHub Actions CI/CD Pipeline                       │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │ Stage 1: Clone/Pull                                     │     │
│  │   - Checkout source code                                │     │
│  └──────────────────────┬──────────────────────────────────┘     │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │ Stage 2: Build Application                              │     │
│  │   - Setup Python 3.11                                   │     │
│  │   - Install dependencies                                │     │
│  └──────────────────────┬──────────────────────────────────┘     │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │ Stage 3: Unit Tests                                     │     │
│  │   - Run pytest                                          │     │
│  │   - Verify core functionality                           │     │
│  └──────────────────────┬──────────────────────────────────┘     │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │ Stage 4: Package (Docker Build)                         │     │
│  │   - Build Docker image                                  │     │
│  │   - Tag with commit SHA                                 │     │
│  └──────────────────────┬──────────────────────────────────┘     │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │ Stage 5: End-to-End Testing                             │     │
│  │   - docker-compose up (app + MongoDB)                   │     │
│  │   - Run API tests (GET, POST)                           │     │
│  │   - docker-compose down                                 │     │
│  └──────────────────────┬──────────────────────────────────┘     │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │ Stage 6: Publish to ECR                                 │     │
│  │   - Authenticate with AWS                               │     │
│  │   - Push image to ECR                                   │     │
│  └──────────────────────┬──────────────────────────────────┘     │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │ Stage 7: Deploy to Kubernetes                           │     │
│  │   - Update kubeconfig                                   │     │
│  │   - kubectl set image (rolling update)                  │     │
│  │   - Verify deployment                                   │     │
│  └─────────────────────────────────────────────────────────┘     │
└───────────────────────────┬──────────────────────────────────────┘
                            │
                            │ Push image
                            ▼
                  ┌───────────────────┐
                  │   AWS ECR         │
                  │ (Docker Registry) │
                  │                   │
                  │  crm-app:latest   │
                  │  crm-app:sha-xxx  │
                  └─────────┬─────────┘
                            │
                            │ Pull image
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                    AWS Infrastructure                            │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │              VPC (10.0.0.0/16)                             │  │
│  │                                                            │  │
│  │  ┌──────────────────────┐    ┌──────────────────────┐      │  │
│  │  │  Public Subnets      │    │  Private Subnets     │      │  │
│  │  │  ┌────────────────┐  │    │  ┌────────────────┐  │      │  │
│  │  │  │   NAT Gateway  │  │    │  │                │  │      │  │
│  │  │  └────────────────┘  │    │  │  EKS Worker    │  │      │  │
│  │  │  ┌────────────────┐  │    │  │  Nodes         │  │      │  │
│  │  │  │ Load Balancer  │◄─┼────┼──│  (t3a.medium)  │  │      │  │
│  │  │  └────────────────┘  │    │  │                │  │      │  │
│  │  │                      │    │  │  ┌──────────┐  │  │      │  │
│  │  │  Internet Gateway    │    │  │  │ CRM Pods │  │  │      │  │
│  │  └──────────────────────┘    │  │  └──────────┘  │  │      │  │
│  │                              │  │  ┌──────────┐  │  │      │  │
│  │                              │  │  │ MongoDB  │  │  │      │  │
│  │                              │  │  │   Pod    │  │  │      │  │
│  │                              │  │  └────┬─────┘  │  │      │  │
│  │                              │  │       │        │  │      │  │
│  │                              │  │  ┌────▼─────┐  │  │      │  │
│  │                              │  │  │ EBS Vol  │  │  │      │  │
│  │                              │  │  │  (5Gi)   │  │  │      │  │
│  │                              │  │  └──────────┘  │  │      │  │
│  │                              │  └────────────────┘  │      │  │
│  │                              └──────────────────────┘      │  │
│  │                                                            │  │
│  │             EKS Control Plane (Managed by AWS)             │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

## Technology Stack

### Development
- **Language**: Python 3.11
- **Framework**: Flask
- **WSGI Server**: Gunicorn
- **Database**: MongoDB 7.0
- **Testing**: pytest

### Containerization
- **Runtime**: Docker
- **Registry**: AWS ECR
- **Orchestration**: Kubernetes (EKS)

### Infrastructure
- **Cloud Provider**: AWS
- **IaC Tool**: Terraform
- **Kubernetes**: Amazon EKS 1.28
- **Compute**: t3a.medium (1 node)
- **Networking**: VPC with public/private subnets

### CI/CD
- **Platform**: GitHub Actions
- **Source Control**: GitHub (3 repositories)
- **Automation**: Automated build, test, deploy

## Data Flow

### User Request Flow
1. User sends HTTP request to Load Balancer DNS
2. AWS ELB routes to healthy CRM App pod
3. Flask application processes request
4. App connects to MongoDB via internal service
5. MongoDB returns data
6. App responds to user

### CI/CD Flow
1. Developer pushes code to GitHub
2. GitHub Actions triggered on main branch
3. Code is built and tested
4. Docker image created and tested (E2E)
5. Image pushed to ECR
6. Kubernetes deployment updated
7. Rolling update with zero downtime

## Security Considerations

- Application runs as non-root user (appuser)
- Private subnets for worker nodes
- MongoDB not exposed externally (ClusterIP)
- IAM roles for EKS node permissions
- ECR image scanning enabled
- Health checks ensure only healthy pods receive traffic

## Scalability

- Application: Horizontal scaling via Deployment replicas
- Database: Vertical scaling (future: replica sets)
- Infrastructure: Can add more EKS nodes
- Load balancing: AWS ELB distributes traffic

## Cost Optimization

- Single NAT Gateway (vs one per AZ)
- t3a.medium instances (AMD-based, cheaper)
- 1 worker node minimum
- ECR lifecycle policy (keep 10 images max)
- **Always terraform destroy when not in use**

## Next Steps (Stage 2+)

- Add Nginx reverse proxy (3-tier)
- Implement GitOps with ArgoCD
- Add Helm charts
- Implement branching strategy (feature/*)
- Add semantic versioning
- Secrets management (Sealed Secrets)
- Monitoring (Prometheus/Grafana) - Stage 3
- Logging (EFK Stack) - Stage 3
