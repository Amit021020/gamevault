# Docker — GameVault

## Overview

Docker is used to package GameVault applications and their dependencies into containers.

The main goal is to make the application environment reproducible and separate the application from the host system.

GameVault currently uses Docker for:

* FastAPI
* PostgreSQL
* Redis
* Background Worker

---

# Docker Image

A Docker image is a packaged template used to create containers.

For example, the FastAPI image contains:

```text
Python
├── Python runtime
├── Installed dependencies
├── GameVault application code
└── Uvicorn
```

An image itself is not the running application.

A container is created from an image.

```text
Docker Image
     │
     ↓
 Container
     │
     ↓
Running application
```

---

# Docker Container

A container is a running instance of an image.

For example:

```text
gamevault-api
```

is a container created from the:

```text
gamevault-api
```

Docker image.

Containers are designed to be replaceable.

This led to an important distinction during the project:

```text
Container lifecycle ≠ Data lifecycle
```

A container can be deleted and recreated without losing persistent data when the data is stored in a Docker volume.

---

# Dockerfile

A Dockerfile describes how to build an image.

The FastAPI Dockerfile is:

```dockerfile
FROM python:3.14-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

# Understanding the FastAPI Dockerfile

## `FROM`

```dockerfile
FROM python:3.14-slim
```

Provides the base image.

It gives the container a Python 3.14 environment without requiring Python to be installed manually on the host.

The `slim` variant is used to keep the image smaller than the full Python image.

---

## `WORKDIR`

```dockerfile
WORKDIR /app
```

Sets the working directory inside the container.

Commands that follow operate relative to:

```text
/app
```

---

## `COPY`

```dockerfile
COPY requirements.txt .
```

Copies `requirements.txt` from the build context into the container.

Dependencies can then be installed.

Later:

```dockerfile
COPY . .
```

copies the application source code into the container.

---

## `RUN`

```dockerfile
RUN pip install --no-cache-dir -r requirements.txt
```

Installs the Python dependencies required by GameVault.

`--no-cache-dir` prevents pip from keeping its package cache inside the image.

---

## `EXPOSE`

```dockerfile
EXPOSE 8000
```

Documents that the application listens on port `8000`.

`EXPOSE` by itself does not publish the port to the host.

Host publishing is done when the container is run or through Docker Compose.

For example:

```yaml
ports:
  - "8000:8000"
```

---

## `CMD`

```dockerfile
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Defines the default command executed when the container starts.

The application runs using Uvicorn.

---

# Building a Docker Image

The FastAPI image was built with:

```bash
docker build -t gamevault-api .
```

The parts mean:

```text
docker build
```

Build an image.

```text
-t gamevault-api
```

Give the image the name `gamevault-api`.

```text
.
```

Use the current directory as the build context.

---

# Docker Build Context

The final `.` in:

```bash
docker build -t gamevault-api .
```

specifies the build context.

Docker can access files inside this context when executing instructions such as:

```dockerfile
COPY . .
```

This is why the Dockerfile, application files, and `requirements.txt` are available during the build.

---

# Running a Container

Before Docker Compose was introduced, the FastAPI container was started manually.

Example:

```bash
docker run -d \
  --network gamevault-network \
  -e DATABASE_URL="postgresql+psycopg2://user:mysecretpass@Postgres-gamevault:5432/gamevault" \
  --name gamevault-api \
  -p 8000:8000 \
  gamevault-api:latest
```

Important options:

| Option                 | Purpose                               |
| ---------------------- | ------------------------------------- |
| `-d`                   | Run container in background           |
| `--network`            | Connect container to a Docker network |
| `-e`                   | Set an environment variable           |
| `--name`               | Assign a container name               |
| `-p`                   | Publish a host port                   |
| `gamevault-api:latest` | Image used to create the container    |

---

# Container Ports

GameVault FastAPI listens on:

```text
8000
```

The host mapping:

```text
8000:8000
```

means:

```text
Host port 8000
       ↓
Container port 8000
       ↓
FastAPI
```

This allows the application to be accessed from the host.

---

# Container Networking

Initially, FastAPI attempted to connect to PostgreSQL using:

```text
localhost:5432
```

This failed after FastAPI was placed inside a container.

The reason is that `localhost` inside a container refers to the container itself.

It does not refer to the host or another container.

The architecture was:

```text
FastAPI container
      │
      │ localhost:5432
      ↓
FastAPI container itself
```

There was no PostgreSQL server there.

---

# Docker Network

A Docker network was created so containers could communicate:

```bash
docker network create gamevault-network
```

PostgreSQL and FastAPI were connected to the same network.

Containers on the same user-defined Docker network can communicate using container names.

Therefore, the database hostname became:

```text
Postgres-gamevault
```

and the connection became:

```text
postgresql+psycopg2://user:mysecretpass@Postgres-gamevault:5432/gamevault
```

The important concept is:

```text
localhost
```

means the current container.

Whereas:

```text
Postgres-gamevault
```

identifies another container on the Docker network.

---

# Container DNS

Docker provides name resolution between containers on a user-defined network.

For example:

```text
FastAPI
   │
   │ Postgres-gamevault:5432
   ↓
PostgreSQL
```

The application does not need to know PostgreSQL's container IP address.

Docker resolves the container/service name.

This is more reliable than manually using container IP addresses.

---

# Environment Variables

The database connection was passed to FastAPI using:

```bash
-e DATABASE_URL="postgresql+psycopg2://user:mysecretpass@Postgres-gamevault:5432/gamevault"
```

The application reads it with:

```python
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://gamevault:gamevault@localhost:5432/gamevault"
)
```

This allows the same application image to be used with different database configurations.

The image does not need to contain a hardcoded production database address.

---

# Docker Volumes

PostgreSQL data needs to survive container replacement.

A Docker volume was created:

```bash
docker volume create gamevault-volume
```

The PostgreSQL container uses this persistent volume.

Conceptually:

```text
PostgreSQL container
        │
        ↓
gamevault-volume
        │
        ↓
Persistent database data
```

Deleting the PostgreSQL container does not automatically delete the volume.

This allows the database container to be recreated while preserving the database data.

---

# Container Lifecycle vs Data Lifecycle

This was an important learning point in GameVault.

Without a volume:

```text
Container
   ↓
Database data
   ↓
Delete container
   ↓
Data lost
```

With a volume:

```text
Container
   ↓
Volume
   ↓
Database data

Delete container
   ↓
Volume remains
   ↓
New container
   ↓
Same database data
```

Therefore:

```text
Containers are replaceable.
Persistent data requires persistent storage.
```

---

# PostgreSQL Container

The PostgreSQL container uses:

```text
postgres:18-alpine
```

It stores its database data in the Docker volume.

The PostgreSQL 18 data layout discovered during the project was:

```text
gamevault-volume
└── 18/
    └── docker/
        ├── PG_VERSION
        ├── base/
        ├── global/
        └── pg_wal/
```

The PostgreSQL version stored in the cluster was:

```text
18
```

This demonstrated why the database image version and existing database storage need to be compatible.

---

# Redis Container

Redis is also containerized.

Current image:

```text
redis:latest
```

Redis is used for background job processing.

It does not need a host port mapping because FastAPI and the worker access it through the Docker/Compose network.

Its internal port is:

```text
6379
```

---

# Worker Container

The background worker has its own Dockerfile.

It uses:

```dockerfile
FROM python:3.14-slim

WORKDIR /worker

RUN pip install --no-cache-dir redis

COPY worker.py .

CMD ["python", "worker.py"]
```

The worker does not expose a port because it does not provide an HTTP server.

It continuously waits for jobs from Redis.

---

# Why Containers Do Not All Need Host Ports

Only services that need to receive connections from outside the Docker network need host port mappings.

Current GameVault architecture:

```text
FastAPI       → 8000:8000
PostgreSQL    → internal only
Redis         → internal only
Worker        → no port
```

FastAPI needs a host port because users access the API.

Redis and PostgreSQL are internal dependencies.

The worker consumes jobs rather than accepting incoming network requests.

---

# Useful Docker Commands

List running containers:

```bash
docker ps
```

List all containers:

```bash
docker ps -a
```

List images:

```bash
docker images
```

View container logs:

```bash
docker logs gamevault-api
```

Follow logs:

```bash
docker logs -f gamevault-api
```

Inspect a container:

```bash
docker inspect gamevault-api
```

Inspect a network:

```bash
docker network inspect gamevault-network
```

List volumes:

```bash
docker volume ls
```

Inspect a volume:

```bash
docker volume inspect gamevault-volume
```

Stop a container:

```bash
docker stop gamevault-api
```

Remove a container:

```bash
docker rm gamevault-api
```

Remove an image:

```bash
docker rmi gamevault-api
```

---

# Important Docker Concepts Learned

## Image

A packaged template used to create containers.

## Container

A running instance of an image.

## Dockerfile

Instructions used to build an image.

## Build Context

The files available to Docker during an image build.

## Port Publishing

Mapping a host port to a container port.

```text
8000:8000
```

## Docker Network

Allows containers to communicate with each other.

## Container DNS

Allows containers to find each other by name on a user-defined network.

## Environment Variable

Configuration supplied to a container at runtime.

## Volume

Persistent storage that exists independently from a container.

## Disposable Container

A container that can be deleted and recreated without treating the container itself as the source of persistent state.

---

# GameVault Docker Architecture

```text
                         Docker
                           │
            ┌──────────────┼──────────────┐
            │              │              │
            ↓              ↓              ↓
        FastAPI        PostgreSQL       Redis
        Container      Container       Container
            │              │              │
            │              ↓              │
            │       gamevault-volume      │
            │                             ↓
            │                           Queue
            │                             │
            │                             ↓
            └──────────────────────── Worker
                                      Container
```

Docker provides the packaging, isolation, networking, and container lifecycle management required to run the GameVault components consistently.

Docker Compose is then used to orchestrate these containers as one application stack.
