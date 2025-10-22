# Advanced Topics & Open Questions

## Overview

This document covers advanced patterns, unsolved challenges, and future enhancements for the monorepo. These topics require further investigation or represent areas where best practices are still evolving.

---

## Open Questions & Future Work

### 1. Tailwind v4 Content Scanning Strategy

**Current Implementation (Temporary):**

Location: `packages/ui/src/styles/globals.css`

```css
@import "tailwindcss";
@source "../../apps/**/*.{ts,tsx}";
@source "../../integrations/**/*.{ts,tsx}";
@source "../../packages/features/**/*.{ts,tsx}"; /* Added for example */
@source "../**/*.{ts,tsx}";
```

**Issue:** The `@workspace/ui` package needs to know about all consumers (apps, integrations, features) to generate utilities like `w-full`.

**Problem for External Integrations:**

1. **Module location ambiguity:**
   - Integrator code could be in `node_modules/@workspace/*` (published packages)
   - Or in their own `src/` directory (local development)
   - Tailwind v4's `@source` directive needs to know where to scan

2. **Incomplete utility generation:**
   - If integrator uses `w-full` but UI package doesn't scan their code
   - Tailwind won't generate the utility
   - Button will have `w-full` class but no CSS definition

3. **Scalability concerns:**
   - UI package shouldn't need to know about all possible consumers
   - Adding `@source` for every feature package doesn't scale
   - External integrators can't modify the UI package's globals.css

**Proposed Solution (Long-term):**

Integrations control their own `globals.css`:

```css
/* integrations/my-app/app/globals.css */
@import "@workspace/ui/globals.css"; /* Import base styles + theme */

/* Add own @source directives for app-specific scanning */
@source "../**/*.{ts,tsx}"; /* Scan this integration's code */
```

**Benefits:**

- ✅ UI package doesn't need to know about consumers
- ✅ Each integration controls what gets scanned
- ✅ Works for both monorepo and external integrators
- ✅ Scales to any number of features/integrations

**Challenges to solve:**

- How does `@import "@workspace/ui/globals.css"` work with `@source` directives?
- Does Tailwind v4 merge `@source` from imported files?
- Do we need to duplicate theme variables in each integration?
- How do integrators override theme variables if they control globals.css?

**Action Items:**

- [ ] Test if Tailwind v4 merges `@source` directives from `@import`
- [ ] Validate integrator override pattern works with separate globals.css
- [ ] Document recommended pattern for external integrators
- [ ] Update example to use integrator-controlled globals.css pattern

---

### 2. TypeScript Path Aliases Pattern

**Current Example Pattern:**

The UI package uses TypeScript path aliases for internal imports:

```typescript
// packages/ui/src/components/badge.tsx
import { cn } from "../lib/utils"; // ❌ Relative import

// Could be:
import { cn } from "@/lib/utils"; // ✅ Path alias
```

**Configuration in `tsconfig.json`:**

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

**Benefits of Path Aliases:**

1. **Cleaner imports** - No `../../../` chains
2. **Refactor-friendly** - Moving files doesn't break imports
3. **Consistent** - Same pattern across all packages
4. **IDE support** - Better autocomplete and navigation
5. **Easier to read** - Clear where imports come from

**Implementation Pattern:**

Each package can define its own `@/*` alias pointing to its `src/`:

```json
// packages/features/products/frontend/tsconfig.json
{
  "extends": "@workspace/typescript-config/react-library.json",
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

**Workspace vs Internal Imports:**

```typescript
// Workspace imports for cross-package dependencies
import { Card } from "@workspace/ui/components/card"; // ✅ Workspace import

// Path aliases for internal imports within the same package
import { formatPrice } from "@/lib/utils"; // ✅ Internal alias
```

**Tooling Compatibility:**

- ✅ TypeScript type checking
- ✅ Next.js (built-in support)
- ✅ Vite (via `vite-tsconfig-paths` plugin)
- ✅ Jest/Vitest (via `moduleNameMapper`)
- ✅ tsup (resolves during build)

**When to Use Path Aliases:**

- ✅ Package has 3+ directory levels
- ✅ Many internal imports across directories
- ✅ Frequent refactoring/restructuring

**When to Skip:**

- ❌ Package is small/flat structure
- ❌ Few internal imports
- ❌ Mostly exports, minimal internal usage

---

### 3. Storybook Setup

**Decision:** Stories co-located with components (e.g., `card.stories.tsx` beside `card.tsx`)

**Storybook app location:** `packages/storybook` (centralized Storybook package)

**Dependencies:** Use pnpm catalog for Storybook versions

**Reference Implementation:** [HeroUI Storybook Package](https://github.com/heroui-inc/heroui/tree/canary/packages/storybook)

- Single `packages/storybook` package (not in `apps/`)
- Uses Vite for fast builds (`@storybook/react-vite`)
- Storybook v8.5+ with modern addons
- Tailwind CSS v4 integration
- Dark mode support via `storybook-dark-mode`
- Scripts: `dev` (port 6006), `build`, `start` (static preview)

**Type resolution:** Add Storybook types to devDependencies via catalog

```yaml
catalog:
  storybook: ^8.5.0
  "@storybook/react": ^8.5.0
  "@storybook/react-vite": ^8.5.0
  "@storybook/addon-essentials": ^8.5.0
  "@storybook/addon-a11y": ^8.5.0
  "storybook-dark-mode": ^4.0.2
```

**Architecture (HeroUI Pattern):**

```
packages/storybook/          # Single Storybook package
├── .storybook/              # Storybook config
├── vite.config.ts           # Vite config
├── tailwind.config.js       # Tailwind config
└── package.json             # Dependencies + scripts

packages/ui/                 # Stories co-located
└── src/components/
    ├── card.tsx
    └── card.stories.tsx
```

**Benefits:**

- ✅ Single Storybook instance (simpler than having multiple)
- ✅ Centralized configuration
- ✅ Fast Vite builds
- ✅ Production-proven (27k stars)
- ✅ Easy to discover all stories in one place

---

### 4. Next-gen Linters (Biome, oxlint)

**Current recommendation:** Stick with ESLint for now

**Strategic preference:** oxlint (Vite alignment) when production-ready

**Monitor adoption:** Wait for 10%+ adoption before switching

---

## Reference Implementations

### Primary Reference: HeroUI

- **Why:** npm-based distribution, granular packages, tsup, production-proven (27k stars)
- **Repo:** [heroui-inc/heroui](https://github.com/heroui-inc/heroui)
- **Learn:** Component package structure, tsup build setup, individual publishing

### Secondary References:

**Turborepo Kitchen-Sink** - Official example

- **Repo:** [vercel/turborepo](https://github.com/vercel/turborepo/tree/main/examples/kitchen-sink)
- **Learn:** Uses `Bundler` for everything, simpler but doesn't handle complex Node.js patterns

**Midday** - Granular feature packages

- **Repo:** [midday-ai/midday](https://github.com/midday-ai/midday)
- **Learn:** Feature-based package organization

**OpenStatus** - Fumadocs, Knip, peer dependencies

- **Repo:** [openstatusHQ/openstatus](https://github.com/openstatusHQ/openstatus)
- **Learn:** Fumadocs setup, Knip config, peer dep patterns

**Tailwind CSS** - pnpm catalog pattern

- **Repo:** [tailwindlabs/tailwindcss](https://github.com/tailwindlabs/tailwindcss)
- **Learn:** pnpm catalog for shared dependency versions

---

### 5. Local Development with Caddy Reverse Proxy

**Current Setup:**

- **Dev mode** (`pnpm dev`): `http://localhost:3000` (frontend), `http://localhost:4000` (backend)
- **Docker mode** (`docker:up`): Same ports - `http://localhost:3000`, `http://localhost:4000`

Only one mode can run at a time (port conflict).

**Issue:** Port numbers to remember, Docker setup doesn't feel production-like

**Desired Workflow:**

- **Dev mode** (`pnpm dev`): Continue using `http://localhost:3000` directly (no Caddy)
- **Docker mode** (`docker:up`): Use clean domains `http://demo.local` and `http://docs.local`

**Proposed Enhancement:**

Add Caddy as a reverse proxy service in Docker Compose:

```
demo.local           → frontend:3000 + backend:4000 (Docker internal network)
docs.local           → docs:3000 (when docs app added)
```

**Benefits:**

- ✅ Dev mode stays simple - just `localhost:3000`
- ✅ Docker mode gets production-like setup with clean domains
- ✅ No port numbers to remember when using Docker
- ✅ Simulates production routing (reverse proxy + clean domains)
- ✅ Easy to add local HTTPS with `mkcert`

**Implementation:**

1. **Add Caddyfile:**

   ```
   deployments/Caddyfile
   ```

2. **Update docker-compose.yaml:**
   - Add Caddy service
   - Configure reverse proxy routing to frontend/backend services
   - Expose Caddy on port 80/443 (not individual service ports)

3. **Update /etc/hosts:**
   ```
   127.0.0.1 demo.local
   127.0.0.1 docs.local
   ```

**Optional: Local HTTPS:**

```bash
# Install mkcert
brew install mkcert

# Create local CA
mkcert -install

# Generate certificates
mkcert demo.local docs.local

# Mount certificates in Caddy container
```

**Action Items:**

- [ ] Create `deployments/Caddyfile` with routing config
- [ ] Add Caddy service to `docker-compose.yaml`
- [ ] Remove port mappings from frontend/backend services (Caddy handles routing)
- [ ] Document `/etc/hosts` setup in DEPLOYMENT.md
- [ ] Add optional mkcert setup for local HTTPS

---

## Package Manager Adoption

**Survey of 14 modern SaaS repos:**

- pnpm: 71% (10/14 repos) - Overwhelming majority
- Yarn: 14% (2/14 repos)
- Bun: 7% (1/14 repos)
- npm: 7% (1/14 repos)

**Validation:** pnpm is the right choice for modern monorepo projects.
