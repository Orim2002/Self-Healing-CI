# Self-Healing CI/CD Pipeline

A self-healing deployment system built on AWS. When a service starts failing health checks in production, the system automatically detects it, rolls back to the last known good version, and sends you a Telegram alert — all without human intervention.

## How it works

Every deployment gets recorded in a PostgreSQL registry. A watchdog process runs inside the Kubernetes cluster and hits the service's `/health` endpoint every 2 seconds. If the service passes three thresholds — running for at least 5 minutes, serving at least 100 requests, and staying below a 0.001% error rate — it gets marked as safe. That record becomes the rollback target for future failures.

When the watchdog detects 5 consecutive failed health checks, it triggers a Jenkins rollback job via API. Jenkins looks up the last safe build from the registry, deploys it to Kubernetes, updates the watchdog config to monitor the restored version, and sends a Telegram message with the details.

## Architecture

```
GitHub Push
    └── GitHub Actions
            ├── Run tests
            ├── Build Docker image
            ├── Push to ECR
            └── Trigger Jenkins (via HTTPS API)
                    └── Jenkins (deploy job)
                            ├── Update kubeconfig
                            ├── Apply Kubernetes secrets
                            ├── Update watchdog config
                            ├── Deploy image to EKS
                            └── Record deployment in RDS

EKS Cluster
    ├── sample-app pod
    └── health-watchdog pod
            ├── Checks /health every 2 seconds
            ├── Updates build registry with metrics
            └── On 5 failures: triggers Jenkins rollback job
                    └── Jenkins (rollback job)
                            ├── Look up last safe build
                            ├── Deploy safe image to EKS
                            ├── Update watchdog config
                            └── Send Telegram alert
```

## Infrastructure

Everything is provisioned with Terraform and organized into modules:

- **EC2** — Jenkins server with Elastic IP, nginx reverse proxy, Let's Encrypt SSL
- **EKS** — Kubernetes cluster with 2 t3.medium worker nodes
- **RDS** — PostgreSQL database (the build registry)
- **ECR** — Docker image repositories

Jenkins is accessible at `https://jenkins.orimatest.com`. The EC2 instance uses an IAM instance profile instead of stored credentials, so AWS access is handled automatically via rotating temporary tokens.

## Repository structure

```
├── build_registry.py       # DB layer: record deployments, mark safe builds, query rollback targets
├── health_watchdog.py      # Monitors service health, updates metrics, triggers rollbacks
├── rollback_engine.py      # Calls Jenkins rollback API
├── telegram_alerter.py     # Sends Telegram notifications
├── watchdog.yaml           # Watchdog config: grace period, interval, thresholds
├── Dockerfile              # Watchdog container image
├── requirements.txt
├── k8s/
│   ├── health-watchdog.yaml
│   └── sample-app.yaml
├── Jenkinsfile.deploy      # Deploy pipeline
├── Jenkinsfile.rollback    # Rollback pipeline
└── terraform/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── bootstrap.sh        # Creates S3 bucket + DynamoDB for Terraform state
    ├── teardown.sh         # Reverses bootstrap.sh
    └── modules/
        ├── ec2/
        ├── eks/
        ├── rds/
        └── ecr/
```

## Build registry

The registry tracks every deployment with three metrics:

| Field | Description |
|---|---|
| `running_time` | Minutes the build has been running |
| `requests` | Total requests served since deployment |
| `error_rate` | Fraction of requests that returned errors |
| `is_safe` | True once all thresholds are crossed |

Once a build is marked safe, it stays safe. The registry uses `GREATEST()` in updates so metrics never go backwards if the watchdog restarts.

## Jenkins credentials required

The following credentials must be configured in Jenkins before running pipelines:

- `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_PORT`
- `JENKINS_TOKEN`
- `TELEGRAM_TOKEN`, `TELEGRAM_CHAT_ID`
- `github-token`

## Terraform setup

```bash
# Bootstrap state backend (run once)
cd terraform
bash bootstrap.sh

# Initialize and deploy
terraform init
terraform apply
```

After `apply`, configure your DNS A record to point your domain at the Elastic IP shown in the outputs. Then SSH into Jenkins and run certbot for SSL:

```bash
sudo certbot --nginx -d your-domain.com
```

## Watchdog configuration

Edit `watchdog.yaml` to adjust monitoring behavior:

```yaml
watchdog:
  grace_period: 45      # seconds before first health check
  interval: 2           # seconds between checks
  max_failures: 5       # consecutive failures before rollback

services:
  - name: sample-app
    url: http://sample-app/health
    image: <ecr-url>/sample-app:<tag>
    thresholds:
      min_requests: 100
      min_running_time: 5
      max_error_rate: 0.001
```

Changes to `watchdog.yaml` take effect on the next deployment, when Jenkins rebuilds the ConfigMap and restarts the watchdog pod.