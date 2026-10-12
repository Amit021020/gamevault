# Kubernetes — GameVault

This document records the Kubernetes implementation of the GameVault project.

The goal of this phase was to deploy GameVault as a Kubernetes-based application with:

* Multiple API replicas
* PostgreSQL persistence
* Redis-based asynchronous processing
* Worker replicas
* Service discovery
* ConfigMaps and Secrets
* Health checks
* Horizontal Pod Autoscaling
* RBAC
* NetworkPolicies
* Ingress and TLS
* Prometheus monitoring

---

## 1. Kubernetes Architecture

The GameVault Kubernetes architecture is:

```text
                         Client
                           │
                           ▼
                    NGINX Ingress
                           │
                           ▼
                    api-service
                    (ClusterIP)
                           │
                ┌──────────┼──────────┐
                ▼          ▼          ▼
             API Pod    API Pod    API Pod
                │          │          │
                └──────┬───┴──────────┘
                       │
             ┌─────────┴─────────┐
             ▼                   ▼
      PostgreSQL Service    Redis Service
             │                   │
             ▼                   ▼
      PostgreSQL Pod         Redis Pod
             │                   │
             ▼                   ▼
          PVC              gamevault_queue
                                 │
                                 ▼
                         Worker Pods (3+)
                                 │
                                 ▼
                           PostgreSQL

Monitoring:

API → /metrics → Service → ServiceMonitor → Prometheus → Grafana
```

All GameVault application resources are deployed in the `gamevault` namespace.

Monitoring resources are deployed separately in the `monitoring` namespace.

---

# 2. Kind Cluster

A local Kubernetes cluster was created using Kind.

```bash
kind create cluster --name gamevault
```

The cluster was verified using:

```bash
kubectl get nodes
```

The cluster is used as a local environment for developing and testing the Kubernetes architecture before moving toward cloud infrastructure.

---

# 3. Namespace Isolation

A dedicated namespace was created for GameVault:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gamevault
```

The main application resources are isolated inside this namespace:

```text
gamevault
├── API
├── PostgreSQL
├── Redis
├── Workers
├── ConfigMap
├── Secret
├── ServiceAccount
├── RBAC
├── NetworkPolicies
├── Ingress
└── PVC
```

Monitoring resources use a separate namespace:

```text
monitoring
├── Prometheus
├── Grafana
├── Alertmanager
├── Node Exporter
└── kube-state-metrics
```

This provides logical separation between the application and monitoring infrastructure.

---

# 4. API Deployment

The GameVault API is deployed using a Kubernetes Deployment.

The Deployment manages multiple API replicas.

The target configuration uses at least three replicas:

```text
gamevault-deployment
        │
        ├── API Pod
        ├── API Pod
        └── API Pod
```

The Deployment provides:

* Replica management
* Self-healing
* Rolling updates
* Rollbacks
* Scaling

The API container listens on port `8000`.

The Kubernetes image policy is:

```yaml
imagePullPolicy: IfNotPresent
```

This allows locally built images loaded into the Kind cluster to be used without pulling them from a registry.

Images can be loaded with:

```bash
kind load docker-image gamevault-api:latest --name gamevault
```

---

# 5. Kubernetes Service

The API is exposed internally through a ClusterIP Service:

```text
api-service
```

The Service listens on:

```text
8000
```

and forwards traffic to API Pods on:

```text
8000
```

The Service selects Pods using:

```yaml
selector:
  app: gamevault-api
```

The architecture is:

```text
Ingress
   │
   ▼
api-service
   │
   ├── API Pod
   ├── API Pod
   └── API Pod
```

The Service provides stable networking even when individual Pods are replaced.

---

# 6. PostgreSQL

PostgreSQL is deployed inside Kubernetes.

Configuration:

```text
Database: gamevault
User: user
Port: 5432
Service: postgres-service
```

The PostgreSQL Deployment uses one replica.

PostgreSQL is accessed by the API and worker through the Kubernetes Service:

```text
postgres-service
```

Applications do not directly depend on the PostgreSQL Pod IP.

Instead:

```text
API / Worker
     │
     ▼
postgres-service
     │
     ▼
PostgreSQL Pod
```

---

# 7. Persistent Storage

PostgreSQL uses a PersistentVolumeClaim:

```text
gamevault-pvc
```

The PVC requests:

```text
1Gi
```

The PVC prevents database data from disappearing when the PostgreSQL Pod is recreated.

The important distinction is:

```text
Pod
  = temporary compute

PVC
  = persistent storage request
```

A PostgreSQL Pod can therefore be deleted and recreated while the database data remains on the attached persistent storage.

The PVC should not be deleted casually because deleting the storage resources can result in data loss depending on the storage configuration and reclaim policy.

---

# 8. Redis

Redis is deployed inside Kubernetes for asynchronous job processing.

```text
redis-deployment
        │
        ▼
redis-service
        │
        ▼
Redis
```

Redis listens on:

```text
6379
```

The queue used by GameVault is:

```text
gamevault_queue
```

Redis is intentionally not persistent in the current architecture because it acts as a temporary job queue rather than the source of truth for application data.

---

# 9. Background Workers

GameVault uses worker Pods to process asynchronous jobs from Redis.

The worker architecture is:

```text
API
 │
 ▼
Redis
 │
 ▼
gamevault_queue
 │
 ├── Worker Pod
 ├── Worker Pod
 └── Worker Pod
```

Multiple worker replicas provide the ability to process jobs concurrently and improve availability.

Workers do not need a Kubernetes Service because they do not receive incoming network requests.

They initiate connections to Redis and PostgreSQL themselves.

---

# 10. ConfigMap

Non-sensitive configuration is stored in a ConfigMap.

Important configuration includes:

```text
DATABASE_HOST=postgres-service
DATABASE_USER=user
DATABASE_NAME=gamevault
DATABASE_PORT=5432

REDIS_HOST=redis-service
REDIS_PORT=6379

QUEUE_NAME=gamevault_queue
```

The ConfigMap allows application configuration to be separated from the container image.

For example, the API does not need to have:

```text
postgres-service
```

hard-coded into its Docker image.

---

# 11. Kubernetes Secret

The PostgreSQL password is stored in a Kubernetes Secret.

Example:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gamevault-secret
type: Opaque
```

The password is supplied to the application using:

```yaml
secretKeyRef:
```

The important distinction is:

```text
ConfigMap → non-sensitive configuration

Secret → sensitive configuration
```

Kubernetes Secret values are commonly Base64 encoded. Base64 is encoding, not encryption.

For production environments, stronger secret-management solutions should be considered.

---

# 12. Health Probes

The GameVault API exposes:

```text
/health
```

Kubernetes uses this endpoint for health checks.

### Liveness Probe

The liveness probe determines whether the container is still alive.

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000
```

If the container repeatedly fails the liveness check, Kubernetes can restart it.

### Readiness Probe

The readiness probe determines whether the Pod should receive traffic.

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8000
```

This prevents traffic from being sent to a Pod that is not ready.

The distinction is:

```text
Liveness  → "Is the application alive?"
Readiness → "Can the application receive traffic?"
```

---

# 13. Resource Requests and Limits

The API Deployment defines CPU and memory resources.

Example:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

Requests tell Kubernetes the resources needed for scheduling.

Limits define the maximum resources the container is allowed to consume.

These values also allow Kubernetes metrics-based autoscaling to work correctly.

---

# 14. Horizontal Pod Autoscaling

GameVault uses a HorizontalPodAutoscaler.

Configuration:

```text
Minimum replicas: 3
Maximum replicas: 6
CPU target: 70%
```

Conceptually:

```text
Low CPU
   │
   ▼
3 API Pods

Higher CPU
   │
   ▼
Kubernetes increases replicas

Very high CPU
   │
   ▼
Up to 6 API Pods
```

The HPA uses the Kubernetes Metrics Server.

The HPA was tested and verified against the GameVault Deployment.

---

# 15. Self-Healing

Kubernetes automatically recreates Pods managed by a Deployment.

For example:

```bash
kubectl delete pod <pod-name> -n gamevault
```

The Deployment/ReplicaSet detects that the desired number of replicas is no longer available and creates a replacement Pod.

This demonstrates Kubernetes self-healing.

---

# 16. Scaling

The API Deployment can also be manually scaled:

```bash
kubectl scale deployment gamevault-deployment \
  --replicas=5 \
  -n gamevault
```

The number of Pods can then be verified:

```bash
kubectl get pods -n gamevault
```

Manual scaling and HPA provide two different scaling mechanisms:

```text
Manual scaling
    ↓
Administrator chooses replica count

HPA
    ↓
Kubernetes adjusts replicas based on metrics
```

---

# 17. Rolling Updates

The GameVault Deployment supports rolling updates.

A new container image can be deployed by changing the Deployment image.

The rollout can be monitored with:

```bash
kubectl rollout status deployment/gamevault-deployment -n gamevault
```

Deployment history can be viewed with:

```bash
kubectl rollout history deployment/gamevault-deployment -n gamevault
```

---

# 18. Rollback

A failed deployment can be rolled back.

Example:

```bash
kubectl rollout undo deployment/gamevault-deployment -n gamevault
```

Then verify:

```bash
kubectl rollout status deployment/gamevault-deployment -n gamevault
```

This was tested by intentionally deploying an invalid image version and then rolling back to the previous working revision.

This demonstrates Kubernetes deployment recovery.

---

# 19. ServiceAccount and RBAC

GameVault uses a dedicated ServiceAccount:

```text
gamevault-api
```

RBAC components:

```text
ServiceAccount
      │
      │ WHO?
      ▼
Role
      │
      │ WHAT permissions?
      ▼
RoleBinding
      │
      ▼
ServiceAccount receives permissions
```

The API Role was intentionally limited to:

```text
pods:
  get
  list
```

This follows the principle of least privilege.

Permissions can be tested with:

```bash
kubectl auth can-i get pods \
  --as=system:serviceaccount:gamevault:gamevault-api \
  -n gamevault
```

And:

```bash
kubectl auth can-i delete pods \
  --as=system:serviceaccount:gamevault:gamevault-api \
  -n gamevault
```

The second operation should not be allowed.

---

# 20. NetworkPolicies

NetworkPolicies were implemented to restrict internal traffic.

PostgreSQL accepts traffic from:

```text
gamevault-api
worker-gamevault
```

on:

```text
5432
```

Redis accepts traffic from:

```text
gamevault-api
worker-gamevault
```

on:

```text
6379
```

Conceptually:

```text
API ───────────────► PostgreSQL
 │
 └─────────────────► Redis

Worker ────────────► PostgreSQL
   │
   └───────────────► Redis

Random Pod ──X─────► PostgreSQL
Random Pod ──X─────► Redis
```

The policies were tested by creating temporary Pods and verifying that unauthorized traffic was blocked.

This demonstrates Kubernetes network-level access control.

---

# 21. Ingress

An NGINX Ingress Controller was installed for the Kind cluster.

The external traffic flow is:

```text
Client
  │
  ▼
NGINX Ingress Controller
  │
  ▼
GameVault Ingress
  │
  ▼
api-service
  │
  ▼
API Pods
```

The Ingress uses the hostname:

```text
gamevault.local
```

The API Service remains a ClusterIP because external traffic is handled by the Ingress.

---

# 22. TLS

TLS was configured for:

```text
gamevault.local
```

A TLS Secret was created:

```text
gamevault-tls
```

The certificate and private key are used by the NGINX Ingress Controller.

The flow is:

```text
HTTPS Client
     │
     ▼
NGINX Ingress
     │
     │ TLS termination
     ▼
api-service
     │
     ▼
API Pods
```

NGINX terminates the HTTPS connection and forwards traffic to the internal Kubernetes Service.

The certificate used for local development is self-signed.

---

# 23. Monitoring with Prometheus

The `kube-prometheus-stack` was installed using Helm.

The monitoring namespace is:

```text
monitoring
```

The stack provides components including:

* Prometheus
* Grafana
* Alertmanager
* Node Exporter
* kube-state-metrics

The application exposes Prometheus metrics through:

```text
/metrics
```

FastAPI metrics are provided using:

```text
prometheus-fastapi-instrumentator
```

---

# 24. ServiceMonitor

A Prometheus `ServiceMonitor` was created for GameVault.

The ServiceMonitor selects the GameVault API Service using:

```yaml
selector:
  matchLabels:
    app: gamevault-api-service
```

The API Service contains the same metadata label:

```yaml
labels:
  app: gamevault-api-service
```

The Service also exposes a named port:

```yaml
ports:
  - name: http
    port: 8000
    targetPort: 8000
```

The ServiceMonitor therefore uses:

```yaml
endpoints:
  - interval: 30s
    port: http
    path: /metrics
```

Prometheus is configured to accept ServiceMonitors with:

```yaml
release: monitoring
```

Therefore the ServiceMonitor contains:

```yaml
metadata:
  labels:
    release: monitoring
```

The complete discovery flow is:

```text
FastAPI
   │
   ▼
/metrics
   │
   ▼
api-service
   │
   ▼
ServiceMonitor
   │
   ▼
Prometheus
```

The GameVault endpoint was successfully discovered and became visible in the Prometheus Targets page.

---

# 25. Application Metrics Verification

The `/health` endpoint was continuously queried to generate application traffic.

Example:

```bash
while true; do
  curl -s -H "Host: gamevault.local" \
    http://172.19.0.2:31651/health > /dev/null
  sleep 0.2
done
```

This generated approximately five requests per second.

Prometheus metrics such as:

```text
http_requests_total
```

could then be used to observe the increasing request count.

This verified that the monitoring pipeline was not only discovering the endpoint but also receiving real application metrics.

---

# 26. Kubernetes Concepts Demonstrated

The GameVault Kubernetes implementation demonstrates the following concepts:

| Concept                  | GameVault implementation       |
| ------------------------ | ------------------------------ |
| Cluster                  | Kind                           |
| Namespace                | `gamevault`                    |
| Deployment               | API, PostgreSQL, Redis, Worker |
| Pods                     | Application workloads          |
| Service                  | API, PostgreSQL, Redis         |
| ClusterIP                | Internal services              |
| ConfigMap                | Application configuration      |
| Secret                   | Database password              |
| PVC                      | PostgreSQL persistence         |
| Readiness Probe          | `/health`                      |
| Liveness Probe           | `/health`                      |
| Resource Requests/Limits | API                            |
| HPA                      | API CPU scaling                |
| ReplicaSets              | Deployment management          |
| Rolling Updates          | API Deployment                 |
| Rollback                 | `kubectl rollout undo`         |
| ServiceAccount           | `gamevault-api`                |
| Role                     | API permissions                |
| RoleBinding              | RBAC association               |
| NetworkPolicy            | Redis/PostgreSQL restrictions  |
| Ingress                  | NGINX                          |
| TLS                      | `gamevault-tls`                |
| Redis                    | Asynchronous queue             |
| Worker Deployment        | Background processing          |
| Prometheus               | Application monitoring         |
| ServiceMonitor           | Prometheus discovery           |
| Metrics Endpoint         | `/metrics`                     |

---

# 27. Useful Commands

### View all GameVault resources

```bash
kubectl get all -n gamevault
```

### View Pods

```bash
kubectl get pods -n gamevault
```

### View Services

```bash
kubectl get svc -n gamevault
```

### View Deployments

```bash
kubectl get deployments -n gamevault
```

### View PVC

```bash
kubectl get pvc -n gamevault
```

### View ConfigMap

```bash
kubectl get configmap gamevault-config -n gamevault
```

### View Secrets

```bash
kubectl get secrets -n gamevault
```

### View Ingress

```bash
kubectl get ingress -n gamevault
```

### View NetworkPolicies

```bash
kubectl get networkpolicy -n gamevault
```

### View HPA

```bash
kubectl get hpa -n gamevault
```

### Check rollout

```bash
kubectl rollout status deployment/gamevault-deployment -n gamevault
```

### View logs

```bash
kubectl logs deployment/gamevault-deployment -n gamevault
```

### Check ServiceMonitor

```bash
kubectl get servicemonitor -n gamevault
```

---

# 28. Final Kubernetes Architecture

At the end of the Kubernetes phase, GameVault has the following architecture:

```text
                              Client
                                │
                                ▼
                         NGINX Ingress
                          HTTPS / TLS
                                │
                                ▼
                         api-service
                           ClusterIP
                                │
                ┌───────────────┼───────────────┐
                ▼               ▼               ▼
             API Pod         API Pod          API Pod
                │               │               │
                │               └───────┬───────┘
                │                       │
        ┌───────┴────────┐              │
        ▼                ▼              │
 PostgreSQL           Redis             │
   Service            Service           │
      │                  │              │
      ▼                  ▼              │
 PostgreSQL          Redis Queue        │
      │                  │              │
      ▼                  ▼              │
     PVC             Workers ◄──────────┘
                         │
                         ▼
                    PostgreSQL


Monitoring:

API
 │
 └── /metrics
       │
       ▼
   ServiceMonitor
       │
       ▼
   Prometheus
       │
       ▼
    Grafana
```

The Kubernetes phase establishes the infrastructure foundation for the remaining observability and cloud deployment work.
