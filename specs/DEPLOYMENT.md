# Deployment Guide

This document explains how the monorepo is containerized for deployment using Docker multi-stage builds optimized for Turborepo workspaces.

## Overview

The deployment strategy uses Docker multi-stage builds with `turbo prune` to create minimal, production-ready containers. The key optimization is **separating dependency installation from source code** to maximize Docker layer caching.

**The challenge:** In a monorepo, changes to the global lockfile (e.g., installing a package in `apps/web`) invalidate Docker's cache for unrelated apps (e.g., `apps/api`), causing unnecessary rebuilds.

**The solution:** `turbo prune` creates an isolated workspace with only the packages and dependencies needed for the target app, plus a pruned lockfile. This means changes to unrelated packages won't invalidate your Docker cache.

## Docker Multi-Stage Build Pattern

Each Dockerfile (frontend and backend) follows a four-stage pattern:

1. **Base** - Node.js base image (reused by other stages)
2. **Workspace** - Extract isolated workspace for the target app
3. **Builder** - Install dependencies and build the application
4. **Runner** - Minimal production image

---

## Stage 1: Base

**Purpose:** Define the Node.js version once and reuse it across all stages.

```dockerfile
FROM node:24 AS base
```

All other stages inherit from this base, ensuring consistency and making Node version updates simple.

All other stages use `FROM base`, so changing the Node version only requires updating one line.

---

## Stage 2: Workspace

**Purpose:** Use Turborepo to extract an isolated workspace for the target application.

```dockerfile
RUN pnpm dlx turbo prune @demo/frontend --docker
```

This analyzes the dependency graph and creates a pruned workspace in `/app/out/` with only the packages needed for the target app.

### What happens:

1. Copies the entire monorepo into the container
2. Runs `turbo prune @demo/frontend --docker` which analyzes the dependency graph
3. Creates an isolated workspace in `/app/out/` with only the packages needed

### Output structure:

```
/app/out/
├── json/                    # Metadata only (for dependency installation)
│   ├── package.json
│   ├── pnpm-lock.yaml
│   ├── pnpm-workspace.yaml
│   └── integrations/demo/frontend/
│       └── package.json     # Just the package.json, no source
│
├── full/                    # Metadata + source code (for building)
│   ├── package.json
│   ├── pnpm-workspace.yaml
│   ├── turbo.json
│   └── integrations/demo/frontend/
│       ├── package.json
│       ├── app/             # Source code
│       ├── next.config.ts   # Config files
│       └── tsconfig.json
│
└── pnpm-lock.yaml          # Pruned lockfile
```

**The split:**

- `json/` = Only package.json files (for `pnpm install`)
- `full/` = Source code + metadata (for building)
- Neither contains `node_modules/` (created in next stage)

---

## Stage 3: Builder

**Purpose:** Install dependencies and build the application.

```dockerfile
FROM base AS builder

# Copy pruned lockfile and package.json files
COPY --from=workspace /app/out/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=workspace /app/out/json/ .

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code and build
COPY --from=workspace /app/out/full/ .
RUN pnpm build --filter=@demo/frontend
```

### What happens:

1. Copies metadata from workspace's `json/` output
2. Runs `pnpm install --frozen-lockfile` to install dependencies
3. Overlays source code from workspace's `full/` output
4. Runs the build command to compile the application

### After installing dependencies:

```
/app/
├── package.json              # Root package.json
├── pnpm-lock.yaml           # Lockfile
├── pnpm-workspace.yaml      # Workspace config
├── node_modules/            # Root dependencies
│   ├── next/
│   ├── react/
│   └── ...
└── integrations/demo/frontend/
    ├── package.json         # Frontend package.json
    └── node_modules/        # Frontend dependencies (workspace links)
```

### After copying source code:

```
/app/
├── package.json
├── pnpm-lock.yaml
├── turbo.json              # Added
├── node_modules/           # From install
└── integrations/demo/frontend/
    ├── package.json
    ├── node_modules/       # From install
    ├── app/                # Added - source code
    │   ├── page.tsx
    │   ├── layout.tsx
    │   └── globals.css
    ├── next.config.ts      # Added - config
    ├── tsconfig.json       # Added - config
    └── public/             # Added - static assets
```

### After build:

```
/app/integrations/demo/frontend/
└── .next/                  # Build output
    ├── standalone/         # Self-contained production build
    ├── static/             # Static assets
    └── ...
```

**Why this order matters:** Dependencies are installed first and cached. Source code is added after, so code changes don't invalidate the dependency cache.

---

## Stage 4: Runner

**Purpose:** Create a minimal production image with only runtime dependencies.

```dockerfile
FROM base AS runner

# Don't run production as root
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
USER nextjs

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/integrations/demo/frontend/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/integrations/demo/frontend/.next/static ./integrations/demo/frontend/.next/static
COPY --from=builder --chown=nextjs:nodejs /app/integrations/demo/frontend/public ./integrations/demo/frontend/public

EXPOSE 3000

CMD ["node", "integrations/demo/frontend/server.js"]
```

### What happens:

1. Starts with the base Node.js image
2. Creates a non-root user (nextjs) for security
3. Copies only the built artifacts needed to run the app (with proper ownership)
4. Defines the startup command

### Result in `/app/`:

```
/app/
├── integrations/demo/frontend/
│   ├── .next/
│   │   ├── static/         # Static assets
│   │   └── ...
│   ├── public/             # Public assets
│   └── server.js           # Production server
├── node_modules/           # Only runtime dependencies (from standalone)
└── package.json
```

**What's included:** Built artifacts and runtime dependencies. Runs as non-root user for security.

---

## Why This Pattern Works

### Docker Layer Caching

Docker caches each layer and only rebuilds when something changes:

```
┌─────────────────────────────────────────────────────────────┐
│ Stage 1: Base                                               │
│ Changes: When Node version changes (very rare)              │
│ Cost: Low (just base image)                                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 2: Workspace                                          │
│ Changes: When monorepo structure changes (rare)             │
│ Cost: Medium (turbo prune is fast)                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 3: Builder                                            │
│ Changes: When dependencies or source code changes           │
│ Cost: HIGH (pnpm install + build, cached when possible)     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 4: Runner                                             │
│ Changes: When build output changes                          │
│ Cost: Low (just copying artifacts)                          │
└─────────────────────────────────────────────────────────────┘
```

### Performance Comparison

**Without turbo prune (naive monorepo Docker):**

```
Any monorepo change → Full pnpm install → Build → Deploy
                      ⏱️  3-5 minutes (every time)
```

**With turbo prune (isolated workspace):**

```
Unrelated change → No rebuild (different workspace)
Source code change → Build with cached dependencies → Deploy
                     ⏱️  30-60 seconds
Dependency change → pnpm install → Build → Deploy
                    ⏱️  3-5 minutes (only when needed)
```

> [!TIP]
> **The Magic of `turbo prune --docker`**
>
> The `--docker` flag tells Turborepo to split output into `json/` and `full/`:
>
> - **`json/`** = Minimal metadata for dependency installation
> - **`full/`** = Complete source code for building
>
> This separation is what enables the installer/builder split and makes Docker layer caching effective.

---

## Summary Table

Each stage has different caching characteristics and performance costs. Understanding when each stage rebuilds helps optimize your Docker workflow:

| Stage         | Input        | Output               | Cached Until          | Cost      |
| ------------- | ------------ | -------------------- | --------------------- | --------- |
| **Base**      | Node image   | Base image with pnpm | Node version changes  | 🟢 Low    |
| **Workspace** | Monorepo     | Isolated workspace   | Structure changes     | 🟡 Medium |
| **Builder**   | Workspace    | Built app            | Deps or source change | 🔴 High   |
| **Runner**    | Build output | Production image     | Builder rebuilds      | 🟢 Low    |

---

## Further Reading

- **[Turborepo Docker Guide](https://turborepo.com/docs/guides/tools/docker)** - Explains the challenges of containerizing monorepo applications and the solutions Turborepo provides
- **[turbo prune --docker Reference](https://turborepo.com/docs/reference/prune#--docker)** - Technical documentation for the `--docker` flag that enables isolated workspace extraction
