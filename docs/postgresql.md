# PostgreSQL — GameVault

## Overview

PostgreSQL is the primary relational database used by GameVault.

It stores persistent application data such as user accounts and will eventually store match, leaderboard, and player-statistics data.

GameVault runs PostgreSQL in a Docker container.

Current PostgreSQL configuration:

```text
Database: gamevault
User: user
Password: mysecretpass
Image: postgres:18-alpine
Internal port: 5432
Persistent volume: gamevault-volume
```

---

# Why PostgreSQL?

GameVault needs persistent storage for application data.

For example:

```text
Users
Matches
Scores
Leaderboards
Player statistics
```

If application data were stored only in memory, restarting the application would remove it.

PostgreSQL provides persistent relational storage.

---

# SQLAlchemy

GameVault uses SQLAlchemy to communicate with PostgreSQL from Python.

SQLAlchemy is a Python SQL toolkit and ORM.

ORM stands for:

```text
Object-Relational Mapping
```

It allows Python classes to represent database tables.

The basic relationship is:

```text
Python Model
     ↓
SQLAlchemy ORM
     ↓
SQL queries
     ↓
PostgreSQL
```

For example, the GameVault `User` model represents the `users` database table.

---

# Database Configuration

GameVault uses a `DATABASE_URL` environment variable.

The application reads it with:

```python id="e9smq3"
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://gamevault:gamevault@localhost:5432/gamevault"
)
```

Inside Docker Compose, the actual database URL is:

```text id="8ekx6m"
postgresql+psycopg2://user:mysecretpass@Postgres-gamevault:5432/gamevault
```

The URL contains:

```text id="9m7vsh"
postgresql+psycopg2://
        │
        ├── user
        ├── password
        ├── hostname
        ├── port
        └── database
```

More specifically:

```text id="9v7f6d"
postgresql+psycopg2://
user
:
mysecretpass
@
Postgres-gamevault
:
5432
/
gamevault
```

---

# Why `localhost` Initially Failed

When FastAPI was running directly on the Ubuntu host, this worked:

```text id="5r3h9e"
localhost:5432
```

because PostgreSQL's container port was published to the host.

The architecture was:

```text id="q7fjc5"
Ubuntu host
│
├── FastAPI
│
└── PostgreSQL container
        │
        └── published port 5432
```

After FastAPI was moved into its own container, `localhost` changed meaning.

Inside the FastAPI container:

```text id="a8p4c3"
localhost
```

means:

```text id="l7v1d9"
FastAPI container itself
```

It does not mean the PostgreSQL container.

Therefore this failed:

```text id="2k8r6p"
localhost:5432
```

The containers were instead connected through a Docker network.

The PostgreSQL hostname became:

```text id="4l5xgk"
Postgres-gamevault
```

So the architecture became:

```text id="xk7q3m"
FastAPI container
      │
      │ Postgres-gamevault:5432
      ↓
PostgreSQL container
```

---

# PostgreSQL Model

The initial GameVault database model contains a `User` table.

```python id="1m3w9b"
from datetime import datetime
from sqlalchemy import Column, DateTime, Integer, String
from .database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
```

The model maps to:

```text id="i4x6sh"
users
├── id
├── username
├── email
├── password_hash
└── created_at
```

---

# Database Session

GameVault creates SQLAlchemy database sessions using:

```python id="e0b1gk"
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)
```

The FastAPI dependency:

```python id="9y3t4c"
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

provides a database session to API endpoints.

The basic flow is:

```text id="y8x6mv"
HTTP Request
     ↓
FastAPI endpoint
     ↓
Database session
     ↓
SQLAlchemy
     ↓
PostgreSQL
     ↓
Response
```

---

# Creating the Database Tables

The current application creates tables using:

```python id="8s6gqv"
Base.metadata.create_all(bind=engine)
```

This creates the database tables represented by the SQLAlchemy models if they do not already exist.

This approach is useful for the current learning stage.

A production application would normally use a database migration system such as Alembic to manage schema changes.

---

# PostgreSQL Docker Container

PostgreSQL is currently defined in Docker Compose as:

```yaml id="3h9w9m"
Postgres-gamevault:

  image: postgres:18-alpine

  container_name: Postgres-gamevault

  environment:

    POSTGRES_USER: user

    POSTGRES_PASSWORD: mysecretpass

    POSTGRES_DB: gamevault
```

The environment variables tell the PostgreSQL image which initial database configuration to create.

---

# PostgreSQL Port

PostgreSQL listens on:

```text id="f3t4p7"
5432
```

When FastAPI and PostgreSQL communicate inside Docker, the internal port is used:

```text id="y6q7xc"
Postgres-gamevault:5432
```

A host port mapping is not required when PostgreSQL is only accessed by other containers.

---

# PostgreSQL Persistence Experiment

Initially, PostgreSQL was run without a Docker volume.

The database was created inside the PostgreSQL container.

When the container was deleted, the database data disappeared.

This demonstrated:

```text id="0m7y2c"
Container storage is not automatically persistent.
```

A Docker volume was then created:

```bash id="6g4f6y"
docker volume create gamevault-volume
```

PostgreSQL was configured to use the volume.

---

# Docker Volume

The PostgreSQL Compose configuration uses:

```yaml id="z6m9sy"
volumes:
  - gamevault-volume:/var/lib/postgresql
```

The volume is declared as an external volume:

```yaml id="b9z2sw"
volumes:
  gamevault-volume:
    external: true
```

This tells Docker Compose to use the existing Docker volume rather than creating a new project-scoped volume.

---

# Why `external: true` Was Important

A manually created volume existed:

```text id="5r4w0n"
gamevault-volume
```

When Compose was initially configured without:

```yaml id="x0h9k2"
external: true
```

Compose created another volume:

```text id="8q7j3s"
gamevault_gamevault-volume
```

This was a different volume.

As a result, PostgreSQL started with different storage and the previously existing database data was not visible.

Using:

```yaml id="t4x8m6"
volumes:
  gamevault-volume:
    external: true
```

ensures that Compose uses the existing:

```text
gamevault-volume
```

---

# PostgreSQL 18 Data Directory

During the persistence troubleshooting, the existing volume was inspected.

Its structure was:

```text id="q7x8nc"
gamevault-volume
└── 18/
    └── docker/
        ├── PG_VERSION
        ├── base/
        ├── global/
        └── pg_wal/
```

The `PG_VERSION` file contained:

```text id="f4k1b7"
18
```

This confirmed that the existing PostgreSQL cluster was PostgreSQL 18.

The PostgreSQL 18 image uses:

```text id="n4g8tq"
/var/lib/postgresql/18/docker
```

as its PostgreSQL data directory.

Because the Docker volume already contained:

```text id="0j7m5h"
18/docker
```

the volume is mounted at:

```text id="o5j6x4"
/var/lib/postgresql
```

rather than directly at:

```text id="x4v8z1"
/var/lib/postgresql/18/docker
```

This results in:

```text id="3g7p5s"
Docker volume
    │
    └── 18/docker
            ↓
Container
    │
    └── /var/lib/postgresql/18/docker
```

---

# PostgreSQL Image Version

The existing database cluster is PostgreSQL 18.

Therefore the Compose configuration uses:

```yaml id="b5f8q1"
image: postgres:18-alpine
```

This avoids trying to use an incompatible major PostgreSQL version with the existing database cluster.

An important database operations lesson was learned here:

```text id="p7w4x8"
Database storage has version compatibility requirements.
```

A PostgreSQL major-version change should not be treated as simply changing an image tag.

---

# PostgreSQL Healthcheck

PostgreSQL has a Compose healthcheck:

```yaml id="w3q9x5"
healthcheck:

  test: ["CMD", "pg_isready", "-U", "user", "-d", "gamevault"]

  interval: 10s

  timeout: 5s

  retries: 5
```

The command:

```bash id="x4n7k2"
pg_isready -U user -d gamevault
```

checks whether PostgreSQL is accepting connections.

This is different from merely checking whether the PostgreSQL container process exists.

---

# Startup Readiness

Initially, FastAPI sometimes started before PostgreSQL was ready.

The result was a connection error similar to:

```text id="n6r2q8"
connection to server at "Postgres-gamevault"
port 5432 failed: Connection refused
```

Docker DNS was working, but PostgreSQL had not finished starting.

This demonstrated:

```text id="j7w3p9"
Container started
       ≠
Application ready
```

The PostgreSQL healthcheck was introduced to solve this startup-readiness problem.

---

# Compose Dependency

FastAPI waits for PostgreSQL to become healthy:

```yaml id="v2k8x5"
depends_on:

  Postgres-gamevault:

    condition: service_healthy
```

The worker also waits for PostgreSQL:

```yaml id="r4m9y2"
depends_on:

  Postgres-gamevault:

    condition: service_healthy
```

This prevents dependent services from immediately attempting database connections while PostgreSQL is still initializing.

---

# Testing PostgreSQL

Enter the PostgreSQL container:

```bash id="q5r7s3"
docker exec -it Postgres-gamevault psql -U user -d gamevault
```

Useful PostgreSQL commands:

```text id="f3k8q1"
\conninfo
```

Shows the current connection.

```text id="a8m4z6"
\dt
```

Lists tables.

```text id="w5q2n9"
\l
```

Lists databases.

```text id="h7p3x4"
\du
```

Lists database roles/users.

```text id="k9s5v2"
\d users
```

Shows the structure of the `users` table.

```text id="c4m8q7"
SELECT * FROM users;
```

Displays users stored in the table.

Exit with:

```text id="n2x6p8"
\q
```

---

# Persistence Verification

The persistence test was:

1. Create a user.
2. Stop/remove the PostgreSQL container.
3. Recreate the PostgreSQL container.
4. Connect to the same Docker volume.
5. Query the `users` table.
6. Confirm that the user still exists.

The successful result demonstrated:

```text id="g8r4k1"
Container replacement
        ↓
Same persistent volume
        ↓
Same PostgreSQL data
```

---

# Important PostgreSQL Concepts Learned

## Database

A collection of structured data managed by PostgreSQL.

## Table

A structured collection of rows and columns.

Example:

```text id="w6x9p2"
users
```

## Row

One record in a table.

## Column

A field describing part of a record.

## Primary Key

A column used to uniquely identify a row.

The `users` table uses:

```text id="z7m3q8"
id
```

as its primary key.

## Unique Constraint

Prevents duplicate values.

The username and email fields are unique.

## ORM

Object-Relational Mapping allows Python objects/classes to represent relational database structures.

## Database Session

A SQLAlchemy session provides a context for interacting with the database.

## Database URL

A connection string containing the database driver, credentials, hostname, port, and database name.

## Persistent Storage

Storage that survives container replacement.

---

# Current PostgreSQL Architecture

```text id="y4q8m1"
                 FastAPI
                    │
                    │ SQLAlchemy
                    ↓
          Postgres-gamevault
                    │
                    ↓
             PostgreSQL 18
                    │
                    ↓
          gamevault-volume
                    │
                    ↓
          Persistent database
```

PostgreSQL is currently the persistent stateful component of the GameVault application.

FastAPI and the background worker can be replaced or recreated while the database remains available through the persistent volume.
