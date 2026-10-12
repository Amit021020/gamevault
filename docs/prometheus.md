# Prometheus

## Overview

Prometheus is the metrics collection and monitoring system used in
GameVault.

It periodically collects numerical metrics from monitored targets and
stores them as time-series data. In GameVault, Prometheus monitors the
FastAPI application running inside Kubernetes.

The monitoring flow is:

``` text
GameVault FastAPI
       |
       | /metrics
       v
api-service
       |
       v
ServiceMonitor
       |
       v
Prometheus
       |
       v
Grafana
```

## Why Prometheus is used

Prometheus helps us answer questions such as:

-   How many requests is the API receiving?
-   How many 4xx and 5xx responses are occurring?
-   How much CPU are API Pods using?
-   How much memory are API Pods using?
-   How many API Pods are currently running?

This makes application and Kubernetes behavior measurable instead of
relying only on logs.

## FastAPI Metrics

GameVault uses `prometheus-fastapi-instrumentator` to expose application
metrics.

The application exposes:

``` text
/metrics
```

The endpoint is not included in the normal FastAPI API documentation.

Example configuration:

``` python
from prometheus_fastapi_instrumentator import Instrumentator

Instrumentator().instrument(app).expose(
    app,
    endpoint="/metrics",
    include_in_schema=False
)
```

The instrumentator automatically records useful HTTP metrics.

One metric used in the project is:

``` text
http_requests_total
```

Example labels observed in Prometheus include:

``` text
handler="/health"
instance="10.244.0.27:8000"
pod="gamevault-deployment-..."
status="2xx"
```

The status labels are grouped as:

``` text
2xx
4xx
5xx
```

rather than individual numeric HTTP status codes.

## Kubernetes ServiceMonitor

Prometheus needs to know where the application metrics endpoint is
located.

GameVault uses a Kubernetes `ServiceMonitor`:

``` yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: gamevault-service-monitor
  namespace: gamevault
  labels:
    release: monitoring
spec:
  selector:
    matchLabels:
      app: gamevault-api-service
  endpoints:
    - interval: 30s
      port: http
      path: /metrics
```

The ServiceMonitor selects:

``` text
api-service
```

The Service exposes port:

``` text
8000
```

with the named port:

``` text
http
```

Prometheus then periodically requests:

``` text
http://api-service:8000/metrics
```

through the Kubernetes service discovery mechanism.

## Prometheus Operator

GameVault uses the `kube-prometheus-stack` Helm chart.

It provides several monitoring components, including:

-   Prometheus
-   Grafana
-   Alertmanager
-   kube-state-metrics
-   node-exporter
-   Prometheus Operator

The stack was installed with:

``` bash
helm install monitoring prometheus-community/kube-prometheus-stack   --namespace monitoring
```

Prometheus was configured to discover ServiceMonitors across namespaces
while selecting ServiceMonitors with:

``` yaml
release: monitoring
```

This is why the GameVault ServiceMonitor contains that label.

## Useful PromQL queries

### Requests in the last minute

``` promql
sum(increase(http_requests_total[1m]))
```

### 4xx error rate

``` promql
sum(rate(http_requests_total{status="4xx"}[1m]))
```

### 5xx error rate

``` promql
sum(rate(http_requests_total{status="5xx"}[1m]))
```

### API Pod CPU usage

``` promql
sum by (pod) (
  rate(container_cpu_usage_seconds_total{
    namespace="gamevault",
    pod=~"gamevault-deployment-.*",
    container!="POD",
    container!="",
  }[1m])
) * 100
```

### API Pod memory usage

``` promql
sum by (pod) (
  container_memory_working_set_bytes{
    namespace="gamevault",
    pod=~"gamevault-deployment-.*",
    container!="POD",
    container!="",
  }
)
```

### Running API replicas

``` promql
count(
  kube_pod_status_phase{
    namespace="gamevault",
    pod=~"gamevault-deployment-.*",
    phase="Running"
  }
)
```

## Prometheus Verification

The GameVault endpoint was verified in the Prometheus UI.

This confirmed the complete metrics path:

``` text
FastAPI
  -> /metrics
  -> Kubernetes Service
  -> ServiceMonitor
  -> Prometheus
```

## Useful Commands

Check ServiceMonitor:

``` bash
kubectl get servicemonitor -n gamevault
```

Describe it:

``` bash
kubectl describe servicemonitor gamevault-service-monitor   -n gamevault
```

Check Prometheus:

``` bash
kubectl get pods -n monitoring
```

Port-forward Prometheus when direct access is needed:

``` bash
kubectl port-forward   svc/monitoring-kube-prometheus-prometheus   9090:9090   -n monitoring
```

Then open:

``` text
http://localhost:9090
```

## Key Concepts

  -----------------------------------------------------------------------
  Concept                             Meaning
  ----------------------------------- -----------------------------------
  Metric                              Numerical measurement

  Time series                         Metric values recorded over time

  PromQL                              Prometheus query language

  Exporter                            Component exposing metrics

  `/metrics`                          HTTP endpoint containing metrics

  ServiceMonitor                      Kubernetes resource describing what
                                      Prometheus should scrape

  Scrape                              Prometheus collecting metrics

  Prometheus Operator                 Kubernetes operator managing
                                      Prometheus resources
  -----------------------------------------------------------------------

## GameVault Result

Prometheus provides the metrics layer for GameVault.

It collects both application-level metrics from FastAPI and
Kubernetes/container metrics exposed through the monitoring stack.
Grafana then uses these metrics to create dashboards.
