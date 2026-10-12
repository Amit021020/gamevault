# Redis — GameVault

## Overview

Redis is used in GameVault as a temporary, fast data store for background job processing.

The main use of Redis in the current architecture is a **job queue** between FastAPI and the background worker.

The basic flow is:

```text id="r3k7p1"
FastAPI
   │
   ↓
Redis Queue
   │
   ↓
Worker
   │
   ↓
PostgreSQL
```

Redis allows FastAPI to submit background work without making the user wait for the worker to finish.

---

# Why Redis?

Suppose a player finishes a match.

The application may need to:

* Calculate the winner
* Update player statistics
* Update the leaderboard
* Update ratings
* Perform other background processing

Doing all of this directly inside the HTTP request could make the request slower.

Instead:

```text id="j7m2q4"
User finishes match
        ↓
FastAPI
        ↓
Create background job
        ↓
Return response
        ↓
Redis Queue
        ↓
Worker processes job
```

This separates the user-facing request from background processing.

---

# Redis in GameVault

The current architecture is:

```text id="v5x9n3"
                 USER
                   │
                   ↓
                FastAPI
                   │
             Create Job
                   │
                   ↓
             Redis Queue
          ┌────────┼────────┐
          ↓        ↓        ↓
       Worker   Worker   Worker
          │        │        │
          └────────┼────────┘
                   ↓
              PostgreSQL
```

Multiple workers can consume jobs from the same queue.

This allows background processing to scale separately from the API.

---

# Redis Container

Redis currently runs using:

```text id="j2q8m6"
redis:latest
```

The container is:

```text id="k4p7x1"
redis-gamevault
```

Its internal port is:

```text id="s9w3n5"
6379
```

Redis does not currently require a host port mapping because FastAPI and the worker communicate with it through the Docker/Compose network.

---

# Redis CLI

The Redis command-line interface can be opened with:

```bash id="q8m4z2"
docker compose exec redis-gamevault redis-cli
```

This provides an interactive Redis shell.

---

# Redis Lists

A Redis List was used as the initial implementation of the GameVault job queue.

The queue name is:

```text id="c5n8v1"
gamevault_queue
```

A Redis List can hold multiple values in an ordered sequence.

For example:

```text id="d7x2m9"
gamevault_queue
│
├── job-1
├── job-2
└── job-3
```

---

# Adding a Job

A job can be added using:

```text id="p4k7s2"
LPUSH gamevault_queue "match-101"
```

`LPUSH` means:

```text id="z6m3q8"
Left Push
```

It adds the value to the left side of the list.

For example:

```text id="w5n9c4"
LPUSH queue "job-1"
LPUSH queue "job-2"
LPUSH queue "job-3"
```

The list becomes conceptually:

```text id="b2v7x5"
job-3  job-2  job-1
 ↑
left
```

---

# Removing a Job

The worker can use:

```text id="k8m4q1"
RPOP gamevault_queue
```

`RPOP` means:

```text id="n7x3c9"
Right Pop
```

It removes the value from the right side.

Because jobs are added using `LPUSH` and removed using `RPOP`, the oldest job is consumed first.

This creates FIFO behavior:

```text id="p6y2w8"
First In
   ↓
First Out
```

Example:

```text id="m4q9s1"
LPUSH queue "job-1"
LPUSH queue "job-2"
LPUSH queue "job-3"
```

Consumption:

```text id="v7k3x5"
RPOP → job-1
RPOP → job-2
RPOP → job-3
```

---

# Checking the Queue

The contents of the queue can be inspected using:

```text id="q5n8m2"
LRANGE gamevault_queue 0 -1
```

`LRANGE` retrieves a range of values from a Redis List.

The following:

```text id="a9x4c7"
0
```

means the beginning of the list.

The following:

```text id="r3m7p1"
-1
```

means the end of the list.

Therefore:

```text id="z6k2w8"
LRANGE gamevault_queue 0 -1
```

shows the entire list.

---

# Checking Queue Length

The number of jobs currently waiting can be checked with:

```text id="n4q8x2"
LLEN gamevault_queue
```

For example:

```text id="j7m3c9"
(integer) 3
```

means three jobs are currently stored in the list.

If the worker consumes all jobs:

```text id="p8x5v2"
LLEN gamevault_queue
(integer) 0
```

This does not mean that Redis failed.

It means the queue is currently empty.

---

# Blocking Queue Consumption

The worker uses:

```python id="c4n7x9"
job = redis_client.brpop(QUEUE_NAME, timeout=0)
```

`BRPOP` means:

```text id="w5m2q8"
Blocking Right Pop
```

Unlike `RPOP`, `BRPOP` waits when the queue is empty.

For example:

```text id="s8k3v1"
Worker
  │
  ↓
BRPOP gamevault_queue
  │
  ├── Job exists → consume job
  │
  └── Queue empty → wait
```

This means the worker does not need to repeatedly poll Redis.

---

# Why Blocking Is Useful

Without blocking:

```text id="r6x2m8"
Check queue
   ↓
Empty
   ↓
Check again
   ↓
Empty
   ↓
Check again
```

This can create unnecessary repeated requests.

With `BRPOP`:

```text id="n7k4p2"
Worker
   ↓
Wait for job
   ↓
Job arrives
   ↓
Consume job
```

The worker can remain idle while waiting for work.

---

# Worker and Redis Connection

The Dockerized worker connects to Redis using the Redis container name:

```python id="m8q3x7"
redis_client = redis.Redis(
    host="redis-gamevault",
    port=6379,
    decode_responses=True,
    socket_timeout=None
)
```

The important part is:

```text id="x4v9c2"
host="redis-gamevault"
```

The worker does not use:

```text id="q5m7z1"
localhost
```

because Redis is running in a separate container.

Docker's network DNS resolves:

```text id="p3k8w6"
redis-gamevault
```

to the Redis container.

---

# `decode_responses`

The worker uses:

```python id="f7n2x5"
decode_responses=True
```

This makes Redis return strings instead of raw byte values.

Without it, a value might be returned as:

```text id="m9q4v2"
b'match-101'
```

With it, the worker receives:

```text id="c6x8p3"
match-101
```

which is easier to work with in Python.

---

# Redis Connection Timeout

The worker uses:

```python id="w2k7m4"
socket_timeout=None
```

This is important because the worker intentionally waits for Redis when using a blocking command.

A finite socket timeout could cause the Redis connection to time out while the worker is legitimately waiting for a new job.

The worker therefore uses an indefinite socket wait.

---

# Redis Healthcheck

Redis has a Docker Compose healthcheck:

```yaml id="q8m3x7"
healthcheck:

  test: ["CMD", "redis-cli", "ping"]

  interval: 10s

  timeout: 5s

  retries: 5
```

The command:

```bash id="k4v9p2"
redis-cli ping
```

should return:

```text id="s7n2m5"
PONG
```

This confirms that Redis is responding.

---

# Worker Dependency on Redis

The worker waits for Redis to become healthy:

```yaml id="x5q8v3"
depends_on:

  redis-gamevault:

    condition: service_healthy
```

This is better than only specifying:

```yaml id="j6m2r9"
depends_on:
  - redis-gamevault
```

because a container being started does not necessarily mean that the service inside it is ready.

The relationship is:

```text id="v8k4p1"
Redis starts
    ↓
Redis healthcheck
    ↓
PONG
    ↓
Redis becomes healthy
    ↓
Worker starts
```

---

# Testing Redis and the Worker

Start the complete stack:

```bash id="b5n8x2"
docker compose up -d
```

Open Redis CLI:

```bash id="y7m3q9"
docker compose exec redis-gamevault redis-cli
```

Add a test job:

```text id="p4k8v1"
LPUSH gamevault_queue "match-201"
```

The worker should consume the job.

Check worker logs:

```bash id="m6q2x8"
docker compose logs gamevault-worker
```

Expected output:

```text id="z9v3c5"
Processing job: match-201
```

This verifies:

```text id="x8k2m7"
Redis
 ↓
gamevault_queue
 ↓
Worker
```

---

# Job Payload

The planned GameVault background job contains the information required to process a completed match.

Current conceptual payload:

```json id="n5q8v2"
{
  "match_id": 101,
  "player1_id": 12,
  "player1_score": 5,
  "player2_id": 27,
  "player2_score": 3
}
```

The worker should calculate the result from the scores rather than trusting a client-provided winner.

For example:

```text id="k3m7x9"
player1_score > player2_score
        ↓
player 1 wins
```

If the scores are equal:

```text id="r6p2v8"
player1_score == player2_score
        ↓
draw
```

The current design allows draws.

---

# Redis vs PostgreSQL

Redis and PostgreSQL have different responsibilities.

| Redis                     | PostgreSQL                       |
| ------------------------- | -------------------------------- |
| Fast temporary data store | Persistent database              |
| Background job queue      | Permanent application data       |
| Jobs waiting for workers  | Users, matches, statistics, etc. |
| Optimized for fast access | Relational data and transactions |

The current architecture is:

```text id="w4m8q2"
                FastAPI
                   │
                   ↓
                Redis
              Job Queue
                   │
                   ↓
                Worker
                   │
                   ↓
             PostgreSQL
```

Redis should not be treated as the permanent source of truth for GameVault's application data.

---

# Scaling Workers

One advantage of using a queue is that workers can be scaled independently.

For example:

```text id="c7x3m9"
                 Redis
                   │
        ┌──────────┼──────────┐
        ↓          ↓          ↓
     Worker 1   Worker 2   Worker 3
        │          │          │
        └──────────┼──────────┘
                   ↓
              PostgreSQL
```

All workers consume jobs from the same queue.

If background workload increases, additional workers can process jobs concurrently.

The queue does not necessarily "send" a job to a particular worker.

Instead, workers compete to consume available jobs.

---

# Job Reliability Concept

A worker can fail while processing a job.

For example:

```text id="m5q8x2"
Worker receives job
       ↓
Worker crashes
       ↓
Processing incomplete
```

This introduces an important distributed-systems problem:

```text id="v3k7p1"
How do we know whether the job was successfully processed?
```

The eventual design needs to consider:

* Acknowledgment
* Retries
* Duplicate processing
* Idempotency
* Failed jobs
* Stuck jobs

These concerns become increasingly important when multiple workers are running.

The current Redis implementation is intentionally simple and focuses on understanding the basic queue architecture first.

---

# Important Redis Concepts Learned

## Redis

An in-memory data store commonly used for fast data access, caching, queues, and other workloads.

## Redis List

An ordered collection of values.

## `LPUSH`

Adds a value to the left side of a Redis List.

## `RPOP`

Removes a value from the right side.

## `LRANGE`

Reads a range of values from a Redis List.

## `LLEN`

Returns the number of values currently in a Redis List.

## `BRPOP`

Blocking version of `RPOP`.

It waits for a value when the list is empty.

## Queue

A structure used to hold jobs until they can be processed.

## Worker

A process that consumes and processes jobs from a queue.

## FIFO

First In, First Out.

Using:

```text id="z8m4x2"
LPUSH + RPOP
```

provides FIFO behavior for the GameVault queue.

---

# Current Redis Architecture

```text id="q7x3m9"
                         FastAPI
                            │
                            │
                            ↓
                    gamevault_queue
                         Redis
                            │
                ┌───────────┼───────────┐
                ↓           ↓           ↓
             Worker      Worker      Worker
                │           │           │
                └───────────┼───────────┘
                            ↓
                       PostgreSQL
```

Redis acts as the intermediary between user-facing API requests and background processing.

The current implementation provides the foundation for eventually implementing reliable background job processing and horizontally scalable workers.
