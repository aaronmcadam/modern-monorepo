# Modern TypeScript Monorepo

A production-ready monorepo demonstrating best practices for TypeScript, pnpm, and Turborepo.

## 🎯 What This Demonstrates

This example validates modern monorepo patterns:

- **Publishing npm packages** from a monorepo
- **Workspace references** with `workspace:*` protocol
- **Docker deployment** with frozen dependencies
- **Mixed module systems** (ESM frontend + CommonJS backend)
- **Shared configs** (TypeScript, ESLint, Vitest)
- **Feature-based organization** (frontend + backend split)
- **Deterministic builds** (dependency fingerprinting)

## 📋 Documentation

All documentation is in `/specs/`:

- **[PLAN.md](specs/PLAN.md)** - Progress and achievements
- **[ARCHITECTURE.md](specs/ARCHITECTURE.md)** - Structure and patterns
- **[IMPLEMENTATION.md](specs/IMPLEMENTATION.md)** - Implementation details
- **[ADVANCED.md](specs/ADVANCED.md)** - Advanced topics and open questions

## 🚀 Quick Start

```bash
# Install dependencies
pnpm install

# Start dev mode for all packages
pnpm dev

# Type check all packages
pnpm check-types

# Run all tests
pnpm test

# Build Docker images
pnpm docker:build

# Verify Docker build stability
pnpm docker:verify

# Start containers in background
pnpm docker:up

# Stop containers
pnpm docker:down
```

**View the demo:** Open [http://localhost:3000](http://localhost:3000) to see the demo integration (frontend + backend working together).

## 📦 Structure

```
monorepo/
├── apps/
│   └── docs/                    # Next.js documentation site
├── integrations/
│   └── demo/
│       ├── frontend/            # Next.js demo app
│       └── backend/             # Fastify demo server
├── packages/
│   ├── ui/                      # Design system (shadcn/ui + Tailwind v4)
│   ├── features/products/       # Feature package (frontend + backend)
│   ├── lib/                     # Shared utilities
│   ├── eslint-config/           # Shared ESLint configs
│   ├── typescript-config/       # Shared TypeScript configs
│   └── frontend-testing/        # Shared Vitest config
├── deployments/                 # Docker infrastructure
├── scripts/                     # Verification scripts
└── specs/                       # Documentation
```

## ✅ Validated Patterns

**TypeScript Configuration:**

- ✅ Shared configs for different contexts (frontend, backend, apps)
- ✅ `Bundler` for frontend, `NodeNext` for backend
- ✅ No TypeScript project references needed
- ✅ All 12 packages type-check from root

**Dependency Management:**

- ✅ pnpm catalog for shared versions
- ✅ Single lockfile at root
- ✅ `--frozen-lockfile` for deterministic builds
- ✅ Workspace protocol (`workspace:*`)

**Stable Docker Builds:**

- ✅ 10/10 verification tests passing
- ✅ Dependency fingerprinting (MD5 hash of node_modules)
- ✅ Proven stable builds (same source → same image)
- ✅ No host filesystem leaks

**Build Tooling:**

- ✅ Frontend packages: source-only (Next.js transpiles)
- ✅ Backend packages: built with tsup (dual ESM + CJS)
- ✅ Turbo for task orchestration
- ✅ Vitest for testing

## 🔗 Reference Implementations

- **[HeroUI](https://github.com/heroui-inc/heroui)** - npm-based distribution, granular packages, tsup
- **[Turborepo Kitchen-Sink](https://github.com/vercel/turborepo/tree/main/examples/kitchen-sink)** - Official Turborepo example
- **[Midday](https://github.com/midday-ai/midday)** - Feature-based organization
- **[OpenStatus](https://github.com/openstatusHQ/openstatus)** - Fumadocs, Knip integration
- **[Tailwind CSS](https://github.com/tailwindlabs/tailwindcss)** - pnpm catalog pattern

See [ADVANCED.md](specs/ADVANCED.md#reference-implementations) for detailed analysis.

## 📊 Progress

**Completed:** 6/6 tasks (100%) ✅

**Key Achievements:**

- TypeScript type checking from root
- Shared configs for multiple contexts
- Docker dependency isolation
- Dependency fingerprinting
- Version locking validation
- External project integration with `pnpm link`
