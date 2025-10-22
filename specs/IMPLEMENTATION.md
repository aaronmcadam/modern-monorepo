# Implementation Tasks

## Overview

**Goal:** Demonstrate modern monorepo patterns for a UI framework with publishable packages, applications, and shared utilities.

**Context:** This project is a modern UI framework, containing Next.js apps, publishable packages, internal utilities, demo integrations, and docs.

---

## Task 1: Initialize Example Structure ✅

**Status:** Complete

**Goal:** Create basic monorepo structure and configure pnpm workspace.

**Results:**

- ✅ All folders created
- ✅ `pnpm-workspace.yaml` configured with workspace paths
- ✅ `turbo.json` configured with dev, build, check-types, test tasks
- ✅ Root `package.json` has `"private": true` and Turborepo scripts
- ✅ Structure demonstrates semantic organization ("integrations" for internal demos)
- ✅ Demo integration has both frontend and backend

---

## Task 2: Test Publishing + Workspace References ✅

**Status:** Complete

**Goal:** Validate that `workspace:*` references work with publishing workflow.

**Findings:**

✅ **Pattern A (Conditional Exports) WORKS!**

**Implementation:**

- Built `@workspace/backend-utils` with tsup in both ESM (`.js`) and CommonJS (`.cjs`) formats
- Configured package.json exports with `import` and `require` conditions
- Backend correctly resolves to `.cjs` files via `require` condition

**Results:**

- ✅ Backend imports from `@workspace/backend-utils/format` successfully
- ✅ TypeScript type checking passes for all backend packages
- ✅ No need for `clean-package` or package.json rewriting
- ✅ Clean solution with conditional exports

---

## Task 3: Shared TypeScript Configs for Different Contexts ✅

**Status:** Complete (validated during Tasks 1 & 2)

**Goal:** Validate shared configs work for mixed module systems (ESM + CommonJS).

**Implementation:**

Created `@workspace/typescript-config` with four configs:

1. **`base.json`** - Shared settings, uses `ESNext` + `Bundler`
2. **`nextjs.json`** - Extends base, adds Next.js specifics
3. **`react-library.json`** - Extends base, adds JSX
4. **`server.json`** - Overrides to `NodeNext`

**Results:**

- ✅ Frontend packages (ESM) type-check successfully
- ✅ Backend packages (CommonJS) type-check successfully
- ✅ Each package extends the appropriate config via `workspace:*` reference
- ✅ All 12 packages pass `pnpm check-types`

**Key Learnings:**

1. **One base config CAN support both ESM and CommonJS** - Just override `module` and `moduleResolution` in context-specific configs
2. **Workspace package references work for configs** - `"extends": "@workspace/typescript-config/base.json"` resolves via pnpm
3. **No root tsconfig needed** - Each package is independent

---

## Task 4: Shared Libraries (Frontend: Vitest config, Backend: utilities) ✅

**Status:** Complete

**Goal:** Validate Vitest works with the shared TypeScript configs and ESM.

**Implementation:**

Created `@workspace/frontend-testing` package with shared Vitest configuration:

- Exports `vitest.config.ts` for reuse across frontend packages
- Uses explicit imports (no `globals: true`)
- Works with ESM TypeScript config

Added tests to `@workspace/products-frontend`:

- Created `src/lib/utils.test.ts` co-located with implementation
- 3 tests for `formatPrice` function
- All tests passing ✅

**Key Findings:**

1. **Vitest works perfectly with shared TypeScript configs**
   - No issues with `ESNext` + `Bundler` module resolution
   - Explicit imports from vitest work well
   - Co-located tests (beside implementation) work great

2. **Running tests from monorepo root works via Turbo**
   - `pnpm turbo test` runs tests across all packages
   - Tests depend on `^build` in turbo.json
   - Turbo caching works correctly

3. **Module resolution issue discovered and fixed**
   - `base.json` initially used `NodeNext` which requires `.js` extensions
   - Frontend packages need `Bundler` resolution for Next.js/Vite
   - **Solution:** Updated base to use `ESNext` + `Bundler`, backend opts into `NodeNext`

**Package Structure Best Practice:**

```
src/
├── components/
│   └── product-card.tsx
├── hooks/
│   └── use-products.ts
└── lib/
    ├── utils.ts
    └── utils.test.ts
```

**File naming convention:** kebab-case (e.g., `product-card.tsx`, `use-products.ts`)

**Package exports:**

```json
"exports": {
  "./components/*": "./src/components/*.tsx",
  "./hooks/*": "./src/hooks/*.ts"
}
```

Internal modules (`lib/`) are not exported - used via relative imports within the package.

**Results:**

- ✅ All 12 packages pass type checking
- ✅ All tests pass (3 tests in products-frontend)
- ✅ Next.js transpilePackages works correctly with internal imports
- ✅ No `.js` extension errors
- ✅ Turbo orchestration works for test task

---

## Task 5: Stable Docker Builds ✅

**Status:** Complete

**Goal:** Verify Docker builds are stable and predictable across time and machines.

**Implementation:** `pnpm docker:verify` (runs `scripts/verify-stable-builds.sh`)

**Test Results:** 10/10 tests passing

1. ✅ **Single Lockfile** - Only one `pnpm-lock.yaml` at root
2. ✅ **Clean Docker Environment** - Fresh build environment
3. ✅ **Build from Scratch** - `--no-cache` builds successfully
4. ✅ **Turbo Prune Output** - 7 package.json, 5 workspace packages
5. ✅ **Container Filesystem** - Next.js standalone, no broken symlinks
6. ✅ **Next.js Version Match** - Lockfile 16.0.0 = Container 16.0.0
7. ✅ **Dependency Version Locking** - TypeScript 5.9.2, TanStack Table locked to 8.20.6
8. ✅ **Containers Start** - Both frontend and backend start successfully
9. ✅ **Frozen Lockfile** - `--frozen-lockfile` flag used in Dockerfile
10. ✅ **Build Stability** - MD5 hash matches between builds

### Key Achievement: TanStack Table Version Locking

Proved that `@tanstack/react-table@~8.20.1` (permissive range allowing 8.20.1-8.20.999) is locked to exactly `8.20.6` via pnpm-lock.yaml with integrity hash.

**The Guarantee:**

```
GIVEN: pnpm-lock.yaml says @tanstack/react-table@8.20.6
WHEN: Build on any machine, any time
THEN: Container will have EXACTLY 8.20.6

Even if:
- 8.20.7, 8.20.8, 8.20.9 are released
- Build runs 6 months later
- Different developer builds it
- Different CI server builds it

Result: ALWAYS 8.20.6 (until lockfile is manually updated)
```

### Dependency Fingerprint Approach

Instead of comparing Docker layer digests (which include timestamps), we:

1. Build twice from scratch (no cache)
2. Hash the list of installed packages in `node_modules/.pnpm/`
3. Compare fingerprints to verify identical dependencies

**Why not layer digests?**

- Build timestamps cause layer differences
- But dependencies remain identical
- Fingerprinting proves what matters: same packages installed

**Fingerprint Results:**

```
Frontend fingerprint: cc9abf0d8372574015d9dda4becdbb53
Backend fingerprint: 62cc3a4d36a0539e89cff6e08263acce

Build 1 = Build 2 ✅ (identical fingerprints)
```

**What This Proves:**

- ✅ **Stable** - Same lockfile → same installed packages
- ✅ **Isolated** - No host filesystem leaks
- ✅ **Reproducible** - Same source → same dependencies
- ✅ **Locked** - Permissive ranges don't cause drift

---

## Task 6: Linking for Projects External to Monorepo ✅

**Status:** Complete

**Goal:** Validate pnpm linking workflow for external projects.

**Implementation:**

Created `external-integration/` Next.js app outside monorepo to test linking workflow:

1. ✅ Created external Next.js 16 app with TypeScript and Tailwind
2. ✅ Linked `@workspace/ui` package via `pnpm link ../modern-monorepo/packages/ui`
3. ✅ Configured Next.js transpilation and Turbopack root
4. ✅ Imported and rendered Card components from linked package
5. ✅ Verified hot reload works across monorepo boundary
6. ✅ Verified production build works with linked packages

**Critical Discovery: Turbopack Root Configuration Required**

**Problem:**

Next.js 16 uses Turbopack by default, which guards against importing files outside the detected project root. Turbopack auto-detects the root by finding lock files (`pnpm-lock.yaml`). In this example:

- Turbopack found `external-integration/pnpm-lock.yaml`
- Assumed `external-integration/` was the project root
- Blocked access to `../modern-monorepo/packages/ui` (outside detected root)
- Result: `Module not found: Can't resolve '@workspace/ui/globals.css'`

**Solution:**

Configure `turbopack.root` to point to the parent directory containing both projects:

```typescript
// external-integration/next.config.ts
import type { NextConfig } from "next";
import { join } from "path";

const nextConfig: NextConfig = {
  transpilePackages: ["@workspace/ui"],
  turbopack: {
    root: join(__dirname, ".."),
  },
};

export default nextConfig;
```

**Why This Works:**

- Tells Turbopack the actual project root is one level up
- Allows access to both `external-integration/` and `modern-monorepo/`
- Enables Turbopack to resolve symlinked packages outside the detected root

**Reference:** [GitHub Issue #77562](https://github.com/vercel/next.js/issues/77562#issuecomment-2786578176)

**Webpack Fallback:**

Webpack (Next.js pre-16 default) resolves symlinked packages without additional configuration. Added fallback script for debugging:

```json
// package.json
"dev:webpack": "next dev --webpack"
```

**Test Results:**

- ✅ **Linking:** Symlink created in `node_modules/@workspace/ui`
- ✅ **CSS Imports:** `@workspace/ui/globals.css` resolves correctly
- ✅ **Component Imports:** `@workspace/ui/components/card` works
- ✅ **TypeScript:** Types resolve in editor (Neovim)
- ✅ **Tailwind Styling:** Styles from UI package apply correctly
- ✅ **Hot Reload:** Changes in monorepo reflect immediately in external app
- ✅ **Production Build:** `pnpm build` succeeds with linked packages
- ✅ **Turbopack:** Works with `turbopack.root` configuration
- ✅ **Webpack:** Works as fallback without additional config

**Key Learnings:**

1. **Turbopack Symlink Resolution**
   - Requires explicit `turbopack.root` for packages outside detected root
   - This is a security feature to prevent accidental file access
   - Well-documented in Next.js 16 upgrade guide

2. **pnpm Link Workflow**
   - `pnpm link <path>` creates symlink and updates package.json
   - Works identically to `yarn link` / `npm link`
   - No blockers for local development workflow

3. **Hot Reload Across Boundaries**
   - Turbopack HMR works correctly with symlinked packages
   - Changes in monorepo packages trigger immediate reload in external apps
   - Great developer experience for testing packages locally

4. **Production Safety**
   - `turbopack.root` setting is safe for production builds
   - When packages are installed normally (from registry), they're in `node_modules`
   - The root setting only matters for symlinked packages during development

**Detailed Documentation:** External project integration validated - packages can be linked via pnpm link for local development.

---

## Progress Summary

**Completed Tasks:** 6/6 (100%)

1. ✅ Initialize Example Structure
2. ✅ Publishing + Workspace References
3. ✅ Shared TypeScript Configs for Different Contexts
4. ✅ Shared Libraries (Frontend: Vitest config, Backend: utilities)
5. ✅ Stable Docker Builds (10/10 verification tests)
6. ✅ Linking for Projects External to Monorepo (pnpm link + Turbopack configuration)

**All core patterns validated and documented!** 🎯
