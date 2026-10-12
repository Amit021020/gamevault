# Docker Security

## Overview

Docker images are scanned for known vulnerabilities before they are considered ready for CI/CD.

GameVault uses Trivy for container vulnerability scanning.

The purpose is to identify:

- Vulnerable OS packages
- Vulnerable language dependencies
- Accidentally included secrets
- Other security findings detected by the scanner

---

## Docker Image Security

The API and worker are built as separate images.

```text
GameVault API
    ↓
gamevault-api

GameVault Worker
    ↓
gamevault-worker