# Grafana

## Overview

Grafana is the visualization and dashboarding layer of GameVault's
monitoring system.

Prometheus stores the metrics, while Grafana turns those metrics into
readable dashboards.

The relationship is:

``` text
GameVault
   |
   v
Prometheus
   |
   | PromQL
   v
Grafana
   |
   v
Monitoring Dashboard
```

## Why Grafana is used

Raw Prometheus queries are useful for troubleshooting, but a dashboard
makes the state of the application easier to understand.

The GameVault dashboard visualizes:

-   request volume
-   HTTP error rates
-   API CPU usage
-   API memory usage
-   number of running API replicas

## Installation

Grafana was installed as part of the `kube-prometheus-stack` Helm chart:

``` bash
helm install monitoring prometheus-community/kube-prometheus-stack   --namespace monitoring
```

The stack created the Grafana deployment and service in the `monitoring`
namespace.

## Accessing Grafana

Grafana was accessed locally with:

``` bash
kubectl port-forward svc/monitoring-grafana 3000:80   -n monitoring
```

Then:

``` text
http://localhost:3000
```

## Grafana Credentials

The administrator username and password were retrieved from the
Kubernetes Secret.

Username:

``` bash
kubectl get secret monitoring-grafana   -n monitoring   -o jsonpath="{.data.admin-user}" | base64 -d
echo
```

Password:

``` bash
kubectl get secret monitoring-grafana   -n monitoring   -o jsonpath="{.data.admin-password}" | base64 -d
echo
```

## Prometheus Data Source

Grafana uses Prometheus as its data source.

Inside the Kubernetes cluster, Grafana can reach Prometheus through:

``` text
http://monitoring-kube-prometheus-prometheus:9090
```

This means Grafana does not need Prometheus to be exposed publicly.

The data flow is:

``` text
Prometheus
     |
     | PromQL queries
     v
Grafana
     |
     v
Panels
```

## GameVault Dashboard Panels

### 1. Requests --- Last 1 Minute

PromQL:

``` promql
sum(increase(http_requests_total[1m]))
```

This shows the total number of HTTP requests observed during the
previous minute.

------------------------------------------------------------------------

### 2. 4xx Error Rate

PromQL:

``` promql
sum(rate(http_requests_total{status="4xx"}[1m]))
```

This shows the rate of client-side HTTP errors.

Examples of 4xx responses include:

``` text
400 Bad Request
401 Unauthorized
404 Not Found
409 Conflict
```

The exact requests depend on the API traffic being generated.

------------------------------------------------------------------------

### 3. 5xx Error Rate

PromQL:

``` promql
sum(rate(http_requests_total{status="5xx"}[1m]))
```

This shows the rate of server-side HTTP errors.

5xx responses indicate that the server or application encountered an
error while processing a request.

------------------------------------------------------------------------

### 4. API Pod CPU Usage

PromQL:

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

This displays CPU usage separately for each GameVault API Pod.

The `* 100` converts the result to a percentage-style value.

------------------------------------------------------------------------

### 5. API Pod Memory Usage

PromQL:

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

This displays the current working-set memory usage of each API Pod.

------------------------------------------------------------------------

### 6. Running API Replicas

PromQL:

``` promql
count(
  kube_pod_status_phase{
    namespace="gamevault",
    pod=~"gamevault-deployment-.*",
    phase="Running"
  }
)
```

This counts the GameVault API Pods currently in the `Running` phase.

The project normally starts with:

``` text
3 API replicas
```

The HPA can increase this number when resource usage reaches the
configured threshold.

## Monitoring Architecture

The completed monitoring architecture is:

``` text
                 GameVault API Pods
                        |
                        | /metrics
                        v
                 Kubernetes Service
                        |
                        v
                  ServiceMonitor
                        |
                        v
                    Prometheus
                        |
                        | PromQL
                        v
                     Grafana
                        |
                        v
               GameVault Dashboard
```

## Important Concepts

  Concept       Meaning
  ------------- -------------------------------------------
  Dashboard     Collection of monitoring panels
  Panel         Individual visualization
  Data source   System providing data to Grafana
  PromQL        Query language used with Prometheus
  Time range    Period represented by a visualization
  Rate          Change in a metric over time
  Increase      Total increase of a counter over a period

## Grafana vs Prometheus

They have different responsibilities:

``` text
Prometheus = collects + stores + queries metrics

Grafana = visualizes metrics
```

Grafana does not replace Prometheus.

It uses Prometheus as a data source.

## Result

The GameVault monitoring dashboard provides a single place to observe
API traffic, errors, CPU usage, memory usage, and replica count.

This demonstrates application monitoring as well as Kubernetes/container
monitoring.
