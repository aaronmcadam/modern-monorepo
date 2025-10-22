# Plan

## What This Example Validates

Modern monorepo patterns for TypeScript projects:

1. **Publishing npm packages** from a monorepo
2. **Workspace references** (`workspace:*` protocol)
3. **Docker deployment** with frozen dependencies
4. **Mixed module systems** (ESM + CommonJS)
5. **Shared configurations** (TypeScript, ESLint, Vitest)
6. **Feature-based organization** (frontend + backend split)
7. **Peer dependencies** for framework packages (React, Next.js)
8. **pnpm catalog** for centralized dependency version management

---

## Progress: 100% Complete (6/6 Tasks)

### Task 1: Initialize Example Structure ✅

**Validated:**
- Basic monorepo structure with pnpm workspaces
- Turborepo configuration for task orchestration
- Semantic organization (apps, integrations, packages)

### Task 2: Publishing + Workspace References ✅

**Validated:**
- `workspace:*` protocol works with publishing workflow
- Conditional exports for dual ESM + CommonJS builds
- No need for package.json rewriting tools

### Task 3: Shared TypeScript Configs ✅

**Validated:**
- Single source of truth for TypeScript configs
- Different configs for different contexts (frontend vs backend)
- `Bundler` module resolution for frontend, `NodeNext` for backend

### Task 4: Shared Libraries ✅

**Validated:**
- Frontend packages can share Vitest configuration
- Backend packages can share built utilities
- Tests co-located with implementation work correctly

### Task 5: Repeatable Docker Builds ✅

**Validated:**
- Deterministic builds with frozen lockfile (10/10 tests passing)
- Dependency fingerprinting proves build stability
- No host filesystem leaks or version drift

### Task 6: External Project Integration ✅

**Validated:**
- pnpm link workflow for local package testing
- Turbopack configuration for symlinked packages
- Hot reload works across monorepo boundary



## Future Considerations

- [ ] Set up Storybook
- [ ] Tailwind v4 content scanning for external consumers
- [ ] TypeScript path aliases analysis
- [ ] Modern ESLint configuration
- [ ] Unused code detection tools
