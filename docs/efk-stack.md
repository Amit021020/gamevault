# EFK Stack

## Overview

GameVault uses the EFK-style logging stack to collect, store, search,
and visualize Kubernetes logs.

The stack consists of:

``` text
Fluent Bit
Elasticsearch
Kibana
```

The data flow is:

``` text
GameVault Pods
      |
      | container logs
      v
 Fluent Bit
      |
      | log records
      v
Elasticsearch
      |
      | search/query
      v
    Kibana
      |
      v
 Logging Dashboard
```

## Why logging is needed

Metrics tell us numerical information such as:

-   CPU usage
-   memory usage
-   request rate
-   error rate
-   replica count

Logs provide detailed event information.

For example:

``` text
Application started
Request received
User created
Database connection failed
Worker processed job
Exception occurred
```

Logs are especially useful when investigating why something happened.

## Fluent Bit

Fluent Bit is the log collector.

It runs as a Kubernetes **DaemonSet**, which means a Fluent Bit Pod runs
on each Kubernetes node.

Its job is to:

1.  Read container logs.
2.  Parse/enrich the logs.
3.  Add Kubernetes metadata.
4.  Forward logs to Elasticsearch.

The simplified flow is:

``` text
Node
 |
 +-- GameVault Pod logs
 |
 +-- Other Pod logs
 |
 v
Fluent Bit
```

## Installation

Fluent Bit was installed with Helm:

``` bash
kubectl create namespace logging

helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

helm install fluent-bit fluent/fluent-bit   --namespace logging
```

## Kubernetes Metadata

Fluent Bit enriches log records with Kubernetes information.

Fields observed in Kibana include:

``` text
kubernetes.namespace_name
kubernetes.pod_name
kubernetes.pod_name.keyword
kubernetes.pod_id
kubernetes.labels.*
```

This allows logs to be filtered by Kubernetes namespace or Pod.

For example, filtering:

``` text
kubernetes.namespace_name = gamevault
```

shows logs belonging to the GameVault namespace.

## Elasticsearch

Elasticsearch is the storage and search engine for the logs.

Fluent Bit sends log records to Elasticsearch, where they are indexed
and made searchable.

Elasticsearch was installed with Helm.

For the local development cluster, it was configured as a single-node
deployment with reduced CPU and memory requests to keep resource usage
manageable.

Example resource configuration:

``` yaml
replicas: 1
minimumMasterNodes: 1
resources:
  requests:
    cpu: "100m"
    memory: "512Mi"
  limits:
    cpu: "500m"
    memory: "1Gi"
```

## Elasticsearch Security

The Elasticsearch deployment uses HTTPS and authentication.

The Elasticsearch `elastic` password was retrieved from:

``` bash
kubectl get secret elasticsearch-master-credentials   -n logging   -o jsonpath="{.data.password}" | base64 -d
echo
```

Authenticated access was tested with:

``` bash
curl -k -u elastic:PASSWORD   https://localhost:9200
```

The `-k` option was needed because the local Elasticsearch setup uses a
certificate that is not trusted by the local system.

## Elasticsearch Index Verification

The logging pipeline was verified by checking Elasticsearch indices:

``` bash
curl -k -u elastic:PASSWORD   "https://localhost:9200/_cat/indices?v"
```

A log index similar to:

``` text
logstash-2026.09.25
```

was present with documents.

This confirmed:

``` text
Kubernetes logs
    -> Fluent Bit
    -> Elasticsearch
```

was working.

A `yellow` health status is expected in this local single-node setup
because Elasticsearch cannot allocate replica shards to another node
when only one node exists.

## Fluent Bit to Elasticsearch Configuration

Elasticsearch required HTTPS and authentication.

The Fluent Bit Elasticsearch output therefore uses settings equivalent
to:

``` ini
[OUTPUT]
    Name        es
    Match       kube.*
    Host        elasticsearch-master
    Port        9200
    HTTP_User   elastic
    HTTP_Passwd <ELASTIC_PASSWORD>
    tls         On
    tls.verify  Off
    Suppress_Type_Name On
    Logstash_Format On
    Retry_Limit False
```

The same approach was applied to the host log output.

### Why `Suppress_Type_Name` was required

Modern Elasticsearch versions removed the older document type mechanism.

Fluent Bit initially generated requests containing `_type`.

Elasticsearch rejected this with an error similar to:

``` text
unknown parameter [_type]
```

Adding:

``` ini
Suppress_Type_Name On
```

prevented Fluent Bit from sending the obsolete type information.

## Kibana

Kibana is the visualization and exploration interface for Elasticsearch.

The installation was:

``` bash
helm install kibana elastic/kibana   -n logging
```

Kibana was accessed using:

``` bash
kubectl port-forward svc/kibana-kibana 5601:5601   -n logging
```

Then:

``` text
http://localhost:5601
```

The Kibana login used the Elasticsearch `elastic` account and password.

## Kibana Data View

A Kibana data view was created:

``` text
Name: GameVault Logs
Pattern: logstash-*
```

This tells Kibana which Elasticsearch indices should be searched.

## Discover

Kibana Discover was used to inspect raw log documents.

A useful filter was:

``` text
kubernetes.namespace_name = gamevault
```

This restricted the results to GameVault logs.

Other useful fields included:

``` text
kubernetes.pod_name
kubernetes.pod_name.keyword
level.keyword
log.keyword
```

## Kibana Dashboard

A GameVault logging dashboard was created with the following
visualizations.

### 1. GameVault - Total Logs

This visualization displays the total number of log records.

Metric:

``` text
Count of records
```

It provides a quick view of the amount of logging activity.

------------------------------------------------------------------------

### 2. GameVault - Logs Over Time

A line visualization was created using:

``` text
X-axis: @timestamp
Y-axis: Records
```

This shows how log volume changes over time.

------------------------------------------------------------------------

### 3. GameVault - Logs by Pod

A horizontal bar visualization was created.

Configuration:

``` text
Visualization: Bar horizontal
Vertical axis: kubernetes.pod_name.keyword
Horizontal axis: Count of records
```

This shows which GameVault Pods are generating logs.

------------------------------------------------------------------------

### 4. GameVault - Logs by Level

A horizontal bar visualization was created.

Configuration:

``` text
Visualization: Bar horizontal
Vertical axis: level.keyword
Horizontal axis: Count of records
```

The current data contained levels such as:

``` text
info
warn
```

The visualization therefore shows the number of log records at each
observed level.

## Why `.keyword` fields are useful

Fields such as:

``` text
kubernetes.pod_name.keyword
level.keyword
```

are keyword fields.

Keyword fields are useful for exact grouping, filtering, and
aggregation.

For example, Kibana can group logs by:

``` text
gamevault-deployment-...
```

or:

``` text
info
warn
```

without treating the values as analyzed text.

## EFK vs ELK

The traditional ELK stack is:

``` text
Logstash
Elasticsearch
Kibana
```

GameVault uses Fluent Bit instead of Logstash:

``` text
Fluent Bit
Elasticsearch
Kibana
```

This is commonly referred to as an **EFK stack**.

Fluent Bit is lightweight and well suited to Kubernetes environments.

## Troubleshooting Performed

Several real problems were encountered and fixed during implementation.

### Elasticsearch DNS/connection problem

Fluent Bit initially could not connect to:

``` text
elasticsearch-master
```

because Elasticsearch was not yet available.

After Elasticsearch was installed and running, the connection could be
established.

### HTTPS authentication

Elasticsearch required:

``` text
HTTPS
username
password
```

Fluent Bit was updated accordingly.

### Elasticsearch `_type` error

Elasticsearch rejected the old `_type` parameter.

The Fluent Bit configuration was updated with:

``` ini
Suppress_Type_Name On
```

After restarting the Fluent Bit DaemonSet, logs successfully reached
Elasticsearch.

Restart command:

``` bash
kubectl rollout restart daemonset/fluent-bit   -n logging
```

## Useful Commands

Check Fluent Bit:

``` bash
kubectl get pods -n logging
```

Check Fluent Bit logs:

``` bash
kubectl logs -n logging   -l app.kubernetes.io/name=fluent-bit
```

Check Elasticsearch:

``` bash
kubectl get pods -n logging
```

Check Elasticsearch indices:

``` bash
kubectl port-forward svc/elasticsearch-master 9200:9200   -n logging
```

Then:

``` bash
curl -k -u elastic:PASSWORD   "https://localhost:9200/_cat/indices?v"
```

Access Kibana:

``` bash
kubectl port-forward svc/kibana-kibana 5601:5601   -n logging
```

## Key Concepts

  Concept         Meaning
  --------------- ------------------------------------------------------------
  Log             Record of an event
  Fluent Bit      Lightweight log collector
  DaemonSet       Runs a Pod on Kubernetes nodes
  Elasticsearch   Stores and searches log data
  Index           Elasticsearch collection of documents
  Document        Individual Elasticsearch record
  Kibana          Interface for searching and visualizing Elasticsearch data
  Data view       Defines which indices Kibana searches
  Discover        Kibana interface for exploring raw documents
  Keyword field   Field optimized for exact values and aggregation
  EFK             Elasticsearch + Fluent Bit + Kibana

## Final Logging Architecture

``` text
                         Kubernetes Cluster
                                |
            +-------------------+-------------------+
            |                   |                   |
       GameVault API        Worker Pods        Other Pods
            |                   |                   |
            +-------------------+-------------------+
                                |
                         Container Logs
                                |
                                v
                         Fluent Bit
                       (DaemonSet)
                                |
                                v
                         Elasticsearch
                                |
                                v
                            Kibana
                                |
                                v
                    GameVault Logging Dashboard
```

## Result

The GameVault project now has a complete Kubernetes logging pipeline:

``` text
Collect -> Enrich -> Store -> Search -> Visualize
```

This demonstrates practical centralized logging rather than simply
installing the individual tools.
