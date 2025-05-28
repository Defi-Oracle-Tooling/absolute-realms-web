# Absolute Realms Web

## Overview

Absolute Realms Web is a monorepo project that includes:

- **Public Website**: A Next.js application hosted on Azure Static Web Apps.
- **DID-Web Resolver**: A Node.js + TypeScript Azure Function implementing the `did:absoluterealms:` method.
- **Infrastructure**: Managed via Terraform, covering DNS, certificates, hosting, and monitoring.

## Quickstart

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd absolute-realms-web
   ```

2. Install dependencies:
   ```bash
   pnpm install
   ```

3. Start development servers:
   - Website: `pnpm dev:website`
   - DID Resolver: `pnpm dev:did`

4. Manage infrastructure:
   - Plan: `pnpm tf:plan-dev`
   - Apply: `pnpm tf:apply-prod`

## Monorepo Structure

```
/
├── apps/
│   ├── website/                # Next.js public site
│   └── did-resolver/           # Node.js/TS Azure Function (HTTP trigger)
├── libs/
│   ├── ui/                     # shared React components
│   ├── config/                 # environment & feature flags
│   └── utils/                  # helper modules
├── infra/
│   ├── dns/                    # Terraform modules: zones & records
│   ├── certs/                  # Terraform + ACME for `*.absoluterealms.world`
│   ├── hosting/                # Terraform for Static Web Apps & Function App
│   └── monitoring/             # Terraform for App Insights & Alerts
├── docs/
│   ├── architecture.md         # high-level diagram & overview
│   ├── contributing.md         # how to contribute + code of conduct
│   └── api/                    # OpenAPI specs & Swagger UI config
├── .github/
│   ├── workflows/
│   │   ├── website-ci.yml
│   │   └── did-ci.yml
│   ├── ISSUE_TEMPLATE.md
│   └── PULL_REQUEST_TEMPLATE.md
├── package.json                # root workspaces config & scripts
├── tsconfig.base.json          # base TS config + path aliases
├── .eslintrc.js                # lint rules
├── .prettierrc                 # format rules
├── .husky/                     # pre-commit hooks
├── dependabot.yml              # dependency updates
└── CODEOWNERS                  # ownership per directory
```

## CI/CD

- **Lint → Test → Build → Deploy**
- Review apps for PRs
- GitHub Actions workflows:
  - `website-ci.yml`: Deploys the public website.
  - `did-ci.yml`: Deploys the DID resolver.

## Governance

- Semantic commits + semantic-release for automated releases.
- Pre-commit hooks for linting, formatting, and type-checking.
- Secrets managed via GitHub Secrets and Azure Key Vault.

## Verifying GitHub Secrets

Ensure the following secrets are configured in your GitHub repository settings:

- `AZURE_STATIC_WEB_APPS_API_TOKEN`: Token for deploying the website to Azure Static Web Apps.
- `AZURE_FUNCTION_APP_NAME`: Name of the Azure Function App for the DID resolver.
- `AZURE_FUNCTION_APP_PUBLISH_PROFILE`: Publish profile for the Azure Function App.

To add or update secrets:
1. Go to your GitHub repository.
2. Navigate to **Settings** > **Secrets and variables** > **Actions**.
3. Add or update the required secrets.
