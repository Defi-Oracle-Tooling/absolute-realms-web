# Architecture Overview

This document provides a high-level overview of the architecture for the Absolute Realms project.

## Components

### Public Website
- **Framework**: Next.js
- **Hosting**: Azure Static Web Apps
- **Domain**: `https://absoluterealms.world`

### DID-Web Resolver
- **Framework**: Node.js + TypeScript
- **Hosting**: Azure Function (HTTP Trigger)
- **Domain**: `https://did.absoluterealms.world`

### Infrastructure
- **IaC**: Terraform
- **State**: Remote state in Azure Storage
- **Components**:
  - DNS
  - Certificates
  - Hosting
  - Monitoring

## CI/CD
- **Tool**: GitHub Actions
- **Pipeline**:
  1. Lint
  2. Test
  3. Build
  4. Deploy

## Additional Subdomains
- `api.absoluterealms.world`
- `docs.absoluterealms.world`
- `portal.absoluterealms.world`
- `data.absoluterealms.world`
- `blog.absoluterealms.world`
- `identity.absoluterealms.world`

## Terraform Validation

To validate the Terraform configuration, run the following commands:

```bash
cd infra
terraform init
terraform validate
```

## Diagram

![Architecture Diagram](./architecture-diagram.png)
