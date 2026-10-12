# Docker Compose — GameVault

## Overview

Docker Compose is used to define and run the complete GameVault application stack using a single YAML configuration file.

Instead of manually creating each container with separate `docker run` commands, Docker Compose allows all services to be defined together and started with:

```bash
docker compose up -d
```

The current GameVault stack contains four services:

```text
GameVault
│
├── gamevault-api
├── Postgres-gamevault
├── redis-gamevault
└── gamevault-worker
```

All four services communicate through the Docker Compose network.

---

## Why Docker Compose?

Before using Compose, the services had to be started manually.

For example:

```bash
docker run ...
```

had to be used separately for:

* PostgreSQL
* FastAPI
* Redis
* Worker

This becomes difficult to manage as the application grows.

Docker Compose allows the entire stack to be described in one file.

```text
docker-compose.yml
        │
        ├── PostgreSQL
        ├── FastAPI
        ├── Redis
        └── Worker
```

The main benefits are:

* One configuration file
* One command to start the application
* Automatic Docker networking
* Service discovery through service names
* Environment variable configuration
* Healthchecks
* Service dependencies
* Volume configuration

---

# Current Architecture

```text
                    USER
                      │
                      │ HTTP
                      ▼
              ┌───────────────┐
              │  gamevault-api│
              │    FastAPI    │
              └───────┬───────┘
                      │
             ┌────────┴─────────┐
             │                  │
             ▼                  ▼
      ┌─────────────┐    ┌─────────────┐
      │ PostgreSQL  │    │    Redis    │
      │             │    │    Queue    │
      └─────────────┘    └──────┬──────┘
                                 │
                                 ▼
                         ┌─────────────┐
                         │   Worker    │
                         └──────┬──────┘
                                │
                                ▼
                         ┌─────────────┐
                         │ PostgreSQL  │
                         └─────────────┘
```

The services communicate internally using the Compose network.

---

# Compose Network

Docker Compose automatically creates a network for the project.

The current network is:

```text
gamevault_default
```

All services defined in `docker-compose.yml` are automatically connected to this network.

Therefore:

```text
gamevault-api
Postgres-gamevault
redis-gamevault
gamevault-worker
```

can communicate with each other using their service/container names.

For example, FastAPI uses:

```text
Postgres-gamevault:5432
```

instead of:

```text
localhost:5432
```

Similarly, the worker connects to Redis using:

```text
redis-gamevault:6379
```

---

# PostgreSQL Service

The PostgreSQL service is responsible for persistent application data.

```yaml
Postgres-gamevault:

  image: postgres:18-alpine

  container_name: Postgres-gamevault

  environment:
    POSTGRES_USER: user
    POSTGRES_PASSWORD: mysecretpass
    POSTGRES_DB: gamevault

  volumes:
    - gamevault-volume:/var/lib/postgresql

  healthcheck:
    test: ["CMD", "pg_isready", "-U", "user", "-d", "gamevault"]
    interval: 10s
    timeout: 5s
    retries: 5
```

## Image

```yaml
image: postgres:18-alpine
```

The PostgreSQL service uses the official PostgreSQL 18 Alpine image.

---

## Environment Variables

```yaml
environment:
  POSTGRES_USER: user
  POSTGRES_PASSWORD: mysecretpass
  POSTGRES_DB: gamevault
```

These variables configure the initial PostgreSQL database.

The application connects using:

```text
user
```

as the username,

```text
mysecretpass
```

as the password, and

```text
gamevault
```

as the database.

---

# PostgreSQL Volume

PostgreSQL needs persistent storage.

The Compose configuration uses:

```yaml
volumes:
  - gamevault-volume:/var/lib/postgresql
```

The volume is defined as:

```yaml
volumes:
  gamevault-volume:
    external: true
```

The volume already exists outside the Compose project.

This is important because deleting a PostgreSQL container should not delete the database.

```text
PostgreSQL container
       │
       ▼
gamevault-volume
       │
       ▼
Persistent database data
```

The container can therefore be recreated while the database remains intact.

---

# PostgreSQL Healthcheck

PostgreSQL may start its container before it is actually ready to accept connections.

The healthcheck is:

```yaml
healthcheck:
  test: ["CMD", "pg_isready", "-U", "user", "-d", "gamevault"]
  interval: 10s
  timeout: 5s
  retries: 5
```

`pg_isready` checks whether PostgreSQL is ready to accept connections.

This is different from simply checking whether the container is running.

```text
Container running
       ≠
PostgreSQL ready
```

The healthcheck allows other services to wait until PostgreSQL is actually ready.

---

# FastAPI Service

The FastAPI application is defined as:

```yaml
gamevault-api:

  build: .

  container_name: gamevault-api

  command: uvicorn app.main:app --host 0.0.0.0 --port 8000

  environment:
    - DATABASE_URL=postgresql+psycopg2://user:mysecretpass@Postgres-gamevault:5432/gamevault

  depends_on:
    Postgres-gamevault:
      condition: service_healthy

  ports:
    - "8000:8000"
```

---

## Build

```yaml
build: .
```

The `.` means Docker should use the current project directory as the build context.

Docker looks for the project's `Dockerfile` and builds the FastAPI image.

---

## DATABASE_URL

FastAPI receives the database connection string through:

```yaml
environment:
  - DATABASE_URL=postgresql+psycopg2://user:mysecretpass@Postgres-gamevault:5432/gamevault
```

The important part is:

```text
Postgres-gamevault
```

This is the hostname FastAPI uses to reach PostgreSQL.

It does not use:

```text
localhost
```

because `localhost` inside the FastAPI container refers to the FastAPI container itself.

---

# FastAPI Port

FastAPI exposes:

```yaml
ports:
  - "8000:8000"
```

This means:

```text
Host port 8000
       │
       ▼
Container port 8000
       │
       ▼
FastAPI
```

The API can therefore be accessed from the host at:

```text
http://localhost:8000
```

---

# PostgreSQL Does Not Need a Host Port

PostgreSQL does not currently have:

```yaml
ports:
  - "5432:5432"
```

This is intentional.

FastAPI communicates with PostgreSQL through the internal Docker network:

```text
gamevault-api
      │
      │ Postgres-gamevault:5432
      ▼
PostgreSQL
```

The database does not need to be directly accessible from the host for the application to work.

This reduces unnecessary exposure.

---

# Redis Service

Redis is defined as:

```yaml
redis-gamevault:

  image: redis:latest

  container_name: redis-gamevault

  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s
    timeout: 5s
    retries: 5
```

Redis is used as the background-job queue.

---

## Redis Port

Redis normally listens on:

```text
6379
```

However, there is no host port mapping:

```yaml
ports:
  - "6379:6379"
```

This is because only containers need to communicate with Redis.

The worker can connect using:

```text
redis-gamevault:6379
```

---

# Redis Healthcheck

The healthcheck is:

```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 10s
  timeout: 5s
  retries: 5
```

Redis responds with:

```text
PONG
```

when it is available.

This allows Docker Compose to determine when Redis is ready.

---

# Worker Service

The background worker is defined as:

```yaml
gamevault-worker:

  build: ./worker

  container_name: gamevault-worker

  depends_on:
    redis-gamevault:
      condition: service_healthy

    Postgres-gamevault:
      condition: service_healthy
```

The worker image is built from:

```text
./worker
```

because the worker has its own Dockerfile.

---

# Worker Dependencies

The worker depends on:

```yaml
redis-gamevault:
  condition: service_healthy
```

and:

```yaml
Postgres-gamevault:
  condition: service_healthy
```

This means the worker waits for both services to become healthy before starting.

The relationship is:

```text
PostgreSQL
     │
     │ healthy
     ▼
   Worker

Redis
     │
     │ healthy
     ▼
   Worker
```

---

# Why `depends_on` Uses Healthchecks

A simple:

```yaml
depends_on:
  - Postgres-gamevault
```

only establishes a startup dependency.

It does not necessarily mean PostgreSQL is ready to accept connections.

Using:

```yaml
depends_on:
  Postgres-gamevault:
    condition: service_healthy
```

allows Compose to wait for the PostgreSQL healthcheck.

The same principle is used for Redis.

---

# Complete docker-compose.yml

The current GameVault Compose configuration is:

```yaml
services:

  Postgres-gamevault:

    image: postgres:18-alpine

    container_name: Postgres-gamevault

    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: mysecretpass
      POSTGRES_DB: gamevault

    volumes:
      - gamevault-volume:/var/lib/postgresql

    healthcheck:
      test: ["CMD", "pg_isready", "-U", "user", "-d", "gamevault"]
      interval: 10s
      timeout: 5s
      retries: 5


  gamevault-api:

    build: .

    container_name: gamevault-api

    command: uvicorn app.main:app --host 0.0.0.0 --port 8000

    environment:
      - DATABASE_URL=postgresql+psycopg2://user:mysecretpass@Postgres-gamevault:5432/gamevault

    depends_on:
      Postgres-gamevault:
        condition: service_healthy

    ports:
      - "8000:8000"


  redis-gamevault:

    image: redis:latest

    container_name: redis-gamevault

    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5


  gamevault-worker:

    build: ./worker

    container_name: gamevault-worker

    depends_on:
      redis-gamevault:
        condition: service_healthy

      Postgres-gamevault:
        condition: service_healthy


volumes:

  gamevault-volume:
    external: true
```

---

# Starting the Entire Stack

Start all services:

```bash
docker compose up -d
```

The `-d` flag runs the containers in detached mode.

Check their status:

```bash
docker compose ps
```

Expected services:

```text
Postgres-gamevault
gamevault-api
redis-gamevault
gamevault-worker
```

---

# Viewing Logs

View all service logs:

```bash
docker compose logs
```

Follow logs continuously:

```bash
docker compose logs -f
```

View only the worker:

```bash
docker compose logs -f gamevault-worker
```

View FastAPI logs:

```bash
docker compose logs -f gamevault-api
```

View PostgreSQL logs:

```bash
docker compose logs -f Postgres-gamevault
```

---

# Testing the Redis Queue

Open Redis CLI through Compose:

```bash
docker compose exec redis-gamevault redis-cli
```

Add a test job:

```text
LPUSH gamevault_queue "match-201"
```

The worker should receive the job and print something similar to:

```text
Processing job: match-201
```

The flow is:

```text
redis-cli
    │
    │ LPUSH
    ▼
Redis queue
    │
    │ BRPOP
    ▼
Worker
    │
    ▼
Process job
```

---

# Stopping the Stack

Stop the containers:

```bash
docker compose stop
```

This stops the services without removing the containers.

To remove the Compose containers and network:

```bash
docker compose down
```

The external PostgreSQL volume remains intact.

---

# Important Warning About Volumes

Do not use:

```bash
docker compose down -v
```

when you want to preserve the GameVault PostgreSQL data.

The `-v` option removes Compose-managed volumes.

The GameVault database uses an external volume:

```yaml
gamevault-volume:
  external: true
```

The volume should therefore be treated as important persistent data.

---

# Container Lifecycle vs Data Lifecycle

One of the important lessons from GameVault is:

```text
Container lifecycle
        ≠
Data lifecycle
```

Containers can be recreated:

```text
Container deleted
       ↓
Container recreated
       ↓
Volume reused
       ↓
Database data remains
```

This is why PostgreSQL uses:

```text
gamevault-volume
```

instead of storing important data only inside the container filesystem.

---

# Service Communication

The current communication paths are:

### FastAPI → PostgreSQL

```text
Postgres-gamevault:5432
```

### FastAPI → Redis

Redis is currently not directly used by the FastAPI application yet, but the planned connection is:

```text
redis-gamevault:6379
```

### Worker → Redis

```text
redis-gamevault:6379
```

### Worker → PostgreSQL

The worker will eventually connect to:

```text
Postgres-gamevault:5432
```

to update leaderboard and player statistics.

---

# Host Ports vs Container Ports

Only services that need to be accessed from outside Docker need host port mappings.

Current configuration:

| Service    | Container Port | Host Port | Reason                 |
| ---------- | -------------: | --------: | ---------------------- |
| FastAPI    |           8000 |      8000 | User/API access        |
| PostgreSQL |           5432 |      None | Internal communication |
| Redis      |           6379 |      None | Internal communication |
| Worker     |           None |      None | Background process     |

This demonstrates an important Docker concept:

> A container does not need a host port just because its application listens on a port.

Services can communicate through the Docker network without exposing those ports to the host.

---

# Current GameVault Compose Architecture

```text
                         Host
                          │
                          │ :8000
                          ▼
                  ┌───────────────┐
                  │ gamevault-api │
                  │    FastAPI    │
                  └───────┬───────┘
                          │
             gamevault_default network
                          │
          ┌───────────────┼────────────────┐
          │               │                │
          ▼               ▼                ▼
   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
   │ PostgreSQL  │ │    Redis    │ │   Worker    │
   │             │ │             │ │             │
   │ Port 5432   │ │ Port 6379   │ │ No port     │
   └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
          │               │                │
          │               └───────────────►│
          │                                │
          └────────────────────────────────┘
                    Database updates

                  PostgreSQL
                       │
                       ▼
              gamevault-volume
```

---

# Important Concepts Learned

Through Docker Compose, the following concepts were practiced:

* Docker Compose
* YAML configuration
* Services
* Docker networks
* Container-to-container communication
* Docker DNS
* Service names as hostnames
* Host ports
* Container ports
* Environment variables
* Docker volumes
* External volumes
* Healthchecks
* Service dependencies
* `depends_on`
* `condition: service_healthy`
* PostgreSQL persistence
* Redis queues
* Background workers
* Multi-container application architecture

---

# Current Result

GameVault can now be started as a multi-container application using:

```bash
docker compose up -d
```

The stack contains:

```text
FastAPI
   │
   ├── PostgreSQL
   │
   └── Redis
          │
          ▼
        Worker
          │
          ▼
      PostgreSQL
```

Docker Compose manages the service configuration, networking, healthchecks, dependencies, and container lifecycle.

The next major infrastructure step is **Kubernetes**, where the same multi-container architecture will be deployed using Kubernetes workloads, Services, ConfigMaps/Secrets, persistent storage, health probes, and scaling.
