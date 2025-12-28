# Architecture Documentation

## Overview

This document describes the architecture for the CloudOps CRM project - a production-grade cloud-native CRM application deployed on AWS EKS with complete CI/CD pipelines and full observability stack.

## Multi-Repository Structure

```
CloudOps_CRM/           # Application code (Python Flask REST API)
├── app.py              # Main Flask application
├── Dockerfile          # Container image definition
├── .github/workflows/  # CI/CD pipelines
│   ├── cicd.yml            # Continuous deployment on push to main
│   ├── full-deploy.yml     # Full stack with observability (EFK + Prometheus)
│   └── cleanup-deployment.yml  # Resource cleanup before terraform destroy
└── test_*.py           # Unit and E2E tests

CloudOps_CRM_Infra/     # Infrastructure as Code (Terraform)
├── eks.tf              # EKS cluster configuration
├── ecr.tf              # Container registry
├── ebs-csi-driver.tf   # Storage driver and gp3 StorageClass
├── github-oidc.tf      # GitHub Actions authentication
└── provider.tf         # AWS and Kubernetes providers

CloudOps_CRM_Cluster/   # Kubernetes manifests (Helm charts)
├── crm-stack/          # Umbrella Helm chart
│   ├── charts/mongodb/     # MongoDB StatefulSet subchart
│   └── charts/crm-app/     # CRM Deployment subchart
├── crm-ingress.yaml        # Ingress routing rules
├── crm-servicemonitor.yaml # Prometheus metrics scraping
├── prometheus-values.yaml  # Monitoring stack configuration
└── nginx-ingress-values.yaml  # Ingress Controller configuration
```

## Deployment Architecture

### Full Stack Deployment

3-tier architecture with Nginx Ingress and complete observability:

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Internet/Users                                │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                  AWS Network Load Balancer (NLB)                     │
│              (Single LoadBalancer for all services)                  │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│              Nginx Ingress Controller (ingress-nginx namespace)      │
│                                                                      │
│    Path-based routing:                                               │
│    /         → CRM Application                                       │
│    /kibana   → Kibana Dashboard                                      │
│    /grafana  → Grafana Dashboard                                     │
└───────┬────────────────┬────────────────────┬────────────────────────┘
        │                │                    │
        ▼                ▼                    ▼
┌─────────────┐  ┌─────────────┐      ┌─────────────┐
│ CRM App     │  │ Kibana      │      │ Grafana     │
│ (ClusterIP) │  │ (ClusterIP) │      │ (ClusterIP) │
│ :80         │  │ :5601       │      │ :80         │
└──────┬──────┘  └──────┬──────┘      └─────────────┘
       │                │                    │
       ▼                │                    │
┌─────────────┐         │                    │
│ MongoDB     │         │                    │
│ (ClusterIP) │         │                    │
│ :27017      │         │                    │
│ + EBS Vol   │         │                    │
└─────────────┘         │                    │
                        ▼                    │
              ┌─────────────────────┐        │
              │ Elasticsearch      │        │
              │ (ClusterIP, HTTPS) │◄───────┘
              │ :9200              │  Metrics
              │ + EBS Vol (5Gi)    │
              └─────────┬──────────┘
                        │
              ┌─────────┴──────────┐
              │                    │
              ▼                    ▼
      ┌─────────────┐      ┌─────────────┐
      │ Fluentd     │      │ Prometheus  │
      │ (DaemonSet) │      │             │
      │ Log collect │      │ :9090       │
      └─────────────┘      └─────────────┘
```

**Components:**
- Nginx Ingress Controller (ingress-nginx namespace)
- CRM App Deployment (ClusterIP service)
- MongoDB StatefulSet (ClusterIP service, 5Gi EBS)
- Elasticsearch (ClusterIP, HTTPS, 5Gi EBS)
- Kibana (ClusterIP, proxied via Ingress at /kibana)
- Fluentd DaemonSet (log collection)
- Prometheus/Grafana (monitoring namespace)

**Workflow:** `full-deploy.yml`

## AWS Infrastructure (Terraform)

```
┌──────────────────────────────────────────────────────────────────────┐
│                         AWS Account                                  │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │                    Default VPC (us-east-1)                     │  │
│  │                                                                │  │
│  │  ┌──────────────────────────────────────────────────────────┐  │  │
│  │  │                Public Subnets (Multi-AZ)                 │  │  │
│  │  │  us-east-1a, us-east-1b, us-east-1c, us-east-1d, us-east-1f │  │
│  │  │  (us-east-1e excluded - not supported by EKS)            │  │  │
│  │  │                                                          │  │  │
│  │  │  ┌────────────────────────────────────────────────────┐  │  │  │
│  │  │  │              EKS Cluster: develeap-eks-cluster     │  │  │  │
│  │  │  │                    Kubernetes 1.31                 │  │  │  │
│  │  │  │                                                    │  │  │  │
│  │  │  │    ┌────────────────────────────────────────────┐  │  │  │  │
│  │  │  │    │        Managed Node Group (ON_DEMAND)      │  │  │  │  │
│  │  │  │    │                                            │  │  │  │  │
│  │  │  │    │   Node 1: t3a.medium    Node 2: t3a.medium │  │  │  │  │
│  │  │  │    │   ┌─────────────────┐  ┌─────────────────┐ │  │  │  │  │
│  │  │  │    │   │ CRM App Pod    │  │ MongoDB Pod      │ │  │  │  │  │
│  │  │  │    │   │ Fluentd Pod    │  │ Elasticsearch    │ │  │  │  │  │
│  │  │  │    │   │ Kibana Pod     │  │ Ingress Ctrl     │ │  │  │  │  │
│  │  │  │    │   └─────────────────┘  └────────┬────────┘ │  │  │  │  │
│  │  │  │    │                                 │          │  │  │  │  │
│  │  │  │    └─────────────────────────────────┼──────────┘  │  │  │  │
│  │  │  │                                      │             │  │  │  │
│  │  │  │    EBS CSI Driver Addon              │             │  │  │  │
│  │  │  │    ┌─────────────────────────────────┼──────────┐  │  │  │  │
│  │  │  │    │                                 ▼          │  │  │  │  │
│  │  │  │    │   gp3 StorageClass (default)               │  │  │  │  │
│  │  │  │    │   ┌──────────┐  ┌──────────┐  ┌────────┐   │  │  │  │  │
│  │  │  │    │   │MongoDB   │  │Elastic   │  │Grafana │   │  │  │  │  │
│  │  │  │    │   │EBS 5Gi   │  │EBS 5Gi   │  │EBS 5Gi │   │  │  │  │  │
│  │  │  │    │   └──────────┘  └──────────┘  └────────┘   │  │  │  │  │
│  │  │  │    └────────────────────────────────────────────┘  │  │  │  │
│  │  │  │                                                    │  │  │  │
│  │  │  └────────────────────────────────────────────────────┘  │  │  │
│  │  │                                                          │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  │                                                                │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌────────────────────┐  ┌─────────────────────────────────────┐     │
│  │  ECR Repository    │  │  GitHub Actions OIDC Role           │     │
│  │  crm-app           │  │  github-actions-ecr-eks             │     │
│  │  - Immutable tags  │  │  - ECR PowerUser                    │     │
│  │  - Scan on push    │  │  - EKS Cluster Admin                │     │
│  └────────────────────┘  └─────────────────────────────────────┘     │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Infrastructure Components

| Component | Configuration | Description |
|-----------|---------------|-------------|
| **EKS Cluster** | Kubernetes 1.31 | Managed control plane |
| **Node Group** | 2x t3a.medium (ON_DEMAND) | 1-2 node auto-scaling |
| **VPC** | Default VPC | Public subnets only |
| **ECR** | crm-app (immutable tags) | Container registry with vulnerability scanning |
| **EBS CSI Driver** | v1.37.0 addon | Dynamic volume provisioning |
| **StorageClass** | gp3 (default) | Encrypted, WaitForFirstConsumer |
| **GitHub OIDC** | github-actions-ecr-eks | Passwordless CI/CD authentication |

### Terraform Files

| File | Purpose |
|------|---------|
| `eks.tf` | EKS cluster, node groups, access entries |
| `ecr.tf` | ECR repository configuration |
| `ebs-csi-driver.tf` | EBS CSI addon + gp3 StorageClass |
| `github-oidc.tf` | GitHub Actions IAM role + policies |
| `provider.tf` | AWS and Kubernetes provider configuration |
| `variables.tf` | Input variables with defaults |
| `outputs.tf` | Cluster endpoint, ECR URL, role ARN |

## CI/CD Pipelines

### Complete CI/CD Workflow Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                        Developer Workflow                            │
└──────────────────────────────────────────────────────────────────────┘
                               │
                               │ git push to main
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         GitHub                                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────────┐  │
│  │  CloudOps_CRM    │  │ CloudOps_CRM_    │  │ CloudOps_CRM_      │  │
│  │  (Application)   │  │ Infra (Terraform)│  │ Cluster (Helm)     │  │
│  └────────┬─────────┘  └──────────────────┘  └────────────────────┘  │
└───────────┼──────────────────────────────────────────────────────────┘
            │
            │ Triggers cicd.yml on push to main
            ▼
┌──────────────────────────────────────────────────────────────────────┐
│              GitHub Actions CI/CD Pipeline (cicd.yml)                │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐     │
│  │ Stage 1: Clone/Pull                                         │     │
│  │   - Checkout source code                                    │     │
│  └──────────────────────┬──────────────────────────────────────┘     │
│                         ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐     │
│  │ Stage 2: Build Application                                  │     │
│  │   - Setup Python 3.11                                       │     │
│  │   - Install dependencies                                    │     │
│  └──────────────────────┬──────────────────────────────────────┘     │
│                         ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐     │
│  │ Stage 3: Unit Tests                                         │     │
│  │   - Run pytest                                              │     │
│  │   - Verify core functionality                               │     │
│  └──────────────────────┬──────────────────────────────────────┘     │
│                         ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐     │
│  │ Stage 4: Package (Docker Build)                             │     │
│  │   - Build Docker image                                      │     │
│  │   - Tag with commit SHA                                     │     │
│  └──────────────────────┬──────────────────────────────────────┘     │
│                         ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐     │
│  │ Stage 5: End-to-End Testing                                 │     │
│  │   - docker-compose up (app + MongoDB)                       │     │
│  │   - Run API tests (GET, POST, PUT, DELETE)                  │     │
│  │   - docker-compose down                                     │     │
│  └──────────────────────┬──────────────────────────────────────┘     │
│                         ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐     │
│  │ Stage 6: Publish to ECR                                     │     │
│  │   - Authenticate via OIDC                                   │     │
│  │   - Check if image exists (skip if duplicate)               │     │
│  │   - Push image to ECR                                       │     │
│  └──────────────────────┬──────────────────────────────────────┘     │
│                         ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐     │
│  │ Stage 7: Deploy to Kubernetes                               │     │
│  │   - Clone cluster-resources repository                      │     │
│  │   - Build Helm dependencies                                 │     │
│  │   - helm upgrade --reuse-values (rolling update)            │     │
│  │   - Health check (supports both Ingress and LoadBalancer)   │     │
│  └─────────────────────────────────────────────────────────────┘     │
└───────────────────────────┬──────────────────────────────────────────┘
                            │
                            │ Push image
                            ▼
                  ┌───────────────────┐
                  │   AWS ECR         │
                  │ (Docker Registry) │
                  │                   │
                  │  crm-app:<sha>    │
                  │  (immutable tags) │
                  └─────────┬─────────┘
                            │
                            │ Pull image
                            ▼
                  ┌───────────────────┐
                  │   EKS Cluster     │
                  │ (Rolling Update)  │
                  └───────────────────┘
```

### Available Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `cicd.yml` | Push to main | Continuous deployment - build, test, deploy |
| `full-deploy.yml` | Manual | Full stack with EFK + Prometheus |
| `cleanup-deployment.yml` | Manual | Cleanup before terraform destroy |

### Workflow Details

**cicd.yml (Continuous Deployment):**
- Runs on every push to `main` branch
- Skips ECR push if image already exists (idempotent)
- Health check supports both Ingress mode and direct LoadBalancer mode

**full-deploy.yml (Two-Stage Deployment):**
- Stage 1: Deploy Elasticsearch first (creates TLS certificates)
- Stage 2: Deploy Kibana (requires ES certificates to exist)
- Creates ES index templates and ingest pipelines for logs
- Deploys Prometheus/Grafana monitoring stack

**cleanup-deployment.yml:**
- Deletes LoadBalancer services first (prevents orphaned AWS ELBs)
- Cleans up Kibana pre-install hooks
- Deletes ECR images (required before terraform destroy)

## Application Architecture

### REST API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | API info and available endpoints |
| GET | `/health` | Health check (used by K8s probes) |
| GET | `/metrics` | Prometheus metrics |
| GET | `/person` | Get all persons |
| GET | `/person?id=<mongodb_id>` | Get by MongoDB ObjectId |
| GET | `/person/<custom_id>` | Get by custom ID |
| POST | `/person/<custom_id>` | Create person |
| PUT | `/person/<custom_id>` | Update person |
| DELETE | `/person/<custom_id>` | Delete person |

### Application Features

- **Prometheus Metrics**: `/metrics` endpoint with Flask request metrics
- **Structured Logging**: JSON format with correlation IDs for request tracing
- **Health Checks**: Liveness and readiness probes on `/health`
- **Non-root User**: Container runs as `appuser` for security

## Observability Stack

### EFK Stack (Logging)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  CRM App    │────▶│  Fluentd    │────▶│Elasticsearch│
│  Logs       │     │  DaemonSet  │     │  (HTTPS)    │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
┌─────────────┐     ┌─────────────┐            │
│  MongoDB    │────▶│  Fluentd    │────────────┤
│  Logs       │     │  DaemonSet  │            │
└─────────────┘     └─────────────┘            ▼
                                        ┌─────────────┐
                                        │   Kibana    │
                                        │  /kibana    │
                                        └─────────────┘
```

**Log Indices:**
- `logs-crm` - CRM application logs
- `logs-mongodb` - MongoDB logs
- `logs-system` - Infrastructure logs (ES, Kibana, Fluentd)

**ECS Schema Fields:**
- `message` - Original log message
- `service.name` - Application name (crm-app, mongodb, etc.)
- `service.type` - Service type (application, database, infrastructure)
- `event.dataset` - Log dataset identifier
- `event.decoded` - Parsed JSON from message (via ingest pipeline)

### Prometheus/Grafana (Monitoring)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  CRM App    │────▶│ Prometheus  │────▶│   Grafana   │
│  /metrics   │     │  Scraping   │     │  /grafana   │
└─────────────┘     └─────────────┘     └─────────────┘
       │
       │ ServiceMonitor
       ▼
┌─────────────────────────────────┐
│  flask_http_request_total       │
│  flask_http_request_duration    │
│  process_cpu_seconds_total      │
│  process_resident_memory_bytes  │
└─────────────────────────────────┘
```

## Technology Stack

### Development
| Technology | Version | Purpose |
|------------|---------|---------|
| Python | 3.11 | Application runtime |
| Flask | 3.x | Web framework |
| PyMongo | 4.x | MongoDB driver |
| prometheus-flask-exporter | 0.23.x | Metrics collection |
| pytest | 8.x | Unit testing |

### Containerization
| Technology | Version | Purpose |
|------------|---------|---------|
| Docker | Latest | Container runtime |
| AWS ECR | - | Container registry |
| Kubernetes | 1.31 | Container orchestration |
| Helm | 3.13+ | Package manager |

### Infrastructure
| Technology | Version | Purpose |
|------------|---------|---------|
| Terraform | ~> 5.0 | Infrastructure as Code |
| AWS EKS | 1.31 | Managed Kubernetes |
| EBS CSI Driver | v1.37.0 | Volume provisioning |
| gp3 StorageClass | - | Default storage |

### Observability
| Technology | Version | Purpose |
|------------|---------|---------|
| Elasticsearch | 8.5.1 | Log storage |
| Kibana | 8.5.1 | Log visualization |
| Fluentd | 0.5.2 | Log collection |
| Prometheus | kube-prometheus-stack | Metrics collection |
| Grafana | (bundled) | Metrics visualization |

## Security Considerations

- **OIDC Authentication**: GitHub Actions uses OIDC (no long-lived credentials)
- **Non-root Container**: Application runs as `appuser` (uid 1000)
- **EKS Access Entries**: Cluster access via IAM (not aws-auth ConfigMap)
- **TLS for Elasticsearch**: Internal HTTPS with auto-generated certificates
- **ClusterIP Services**: Internal services not exposed directly
- **Immutable Image Tags**: ECR prevents tag overwrites
- **Vulnerability Scanning**: ECR scans images on push
- **Encrypted Volumes**: EBS volumes encrypted by default (gp3)

## Cost Optimization

- **Default VPC**: No NAT Gateway costs (public subnets only)
- **ON_DEMAND Instances**: More reliable than SPOT for development
- **Single LoadBalancer**: Nginx Ingress serves all services
- **t3a.medium**: Cost-optimized AMD instances
- **terraform destroy**: Always destroy when not in use
- **gp3 Volumes**: Better price/performance than gp2

## Cleanup Procedure

**IMPORTANT**: Run cleanup workflow before terraform destroy:

```bash
# 1. Run cleanup-deployment.yml workflow in GitHub Actions
#    - Deletes LoadBalancer services (prevents orphaned ELBs)
#    - Uninstalls Helm releases
#    - Deletes ECR images

# 2. Wait 2-3 minutes for AWS resource propagation

# 3. Destroy infrastructure
cd CloudOps_CRM_Infra
terraform destroy
```

## Quick Reference

### Connect to Cluster
```bash
aws eks update-kubeconfig --name develeap-eks-cluster --region us-east-1
kubectl get nodes
```

### Deploy Application
```bash
# Full stack deployment (app + MongoDB + EFK + Prometheus)
# Use full-deploy.yml workflow in GitHub Actions
```

### Access URLs
```bash
INGRESS_URL=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "CRM App:  http://$INGRESS_URL/"
echo "Kibana:   http://$INGRESS_URL/kibana"
echo "Grafana:  http://$INGRESS_URL/grafana"
```

### Check Deployment Status
```bash
helm list -n default
kubectl get all -n default
kubectl get all -n ingress-nginx
kubectl get all -n monitoring
```