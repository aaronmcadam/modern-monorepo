# Architecture & Design Decisions

## Workspace Structure

**Distribution Model:** npm-based publishing (like HeroUI), not copy-paste (like shadcn/ui)

**Semantic organization pattern:**

```
apps/                    # Public, deployed applications
integrations/            # Private, internal testing/examples
packages/                # Publishable framework packages
  ├── ui/                # Design system components (Card, Button, Input)
  ├── blocks/            # Composite components (SidebarLayout, Header, Footer)
  ├── lib/               # Grouped libraries by runtime
  └── features/          # Business features (frontend/backend split)
deployments/             # Infrastructure (NOT in workspace)
```

**Package hierarchy example:**

```
@workspace/ui            → Card, Button, Input (primitives)
@workspace/blocks        → AdminPage, CustomerPage (page layouts)
@workspace/products-frontend → ProductCard, AdminProductsPage, CustomerProductsPage
```

**Dependency flow:**

```
features → blocks → ui
(AdminProductsPage uses AdminPage uses Card)
(CustomerProductsPage uses CustomerPage uses Card)
```

**Why this structure:**

- Semantic naming for different package types
- Clear public/private boundary
- Frontend/backend split reflects deployment model (Next.js + Fastify)
- Solves deployment infrastructure problem
- Clear component hierarchy: ui → blocks → features

**Reference Implementation:** HeroUI (27k stars)

- npm-based distribution ✅
- Granular component packages ✅
- Uses tsup for building ✅
- Standard `apps/` + `packages/` structure ✅
- Production-proven ✅

---

## Dependency Management

### pnpm Catalog

Centralized version management for shared dependencies across all packages.

**Configuration:**

```yaml
catalog:
  typescript: 5.9.2
  vitest: ^2.1.8
  "@types/node": ^24.0.0
  next: ^16.0.0
```

**Usage in package.json:**

```json
{
  "devDependencies": {
    "typescript": "catalog:",
    "vitest": "catalog:",
    "next": "catalog:"
  }
}
```

**Benefits:**

- Centralized version management
- Consistent versions across packages
- Easy to update (change once, update everywhere)
- Works with `--frozen-lockfile` for deterministic builds

### Peer Dependencies Strategy

**Decision:** Packages declare peer dependencies, applications install them.

**Why:**

- Prevents multiple instances of React/Next.js in the bundle
- Clear ownership: applications control framework versions
- Packages declare compatibility requirements
- Works with pnpm's strict dependency resolution

**Pattern:**

```json
// UI packages declare React as peer dependency
// packages/ui/package.json
{
  "peerDependencies": {
    "react": "^19.0.0"
  }
}

// Feature packages declare both React and Next.js
// packages/features/products/frontend/package.json
{
  "peerDependencies": {
    "next": ">=16.0.0",
    "react": "^19.0.0"
  }
}

// Applications install the actual versions
// integrations/demo/frontend/package.json
{
  "dependencies": {
    "next": "catalog:",
    "react": "catalog:",
    "@workspace/ui": "workspace:*",
    "@workspace/products-frontend": "workspace:*"
  }
}
```

**Result:**

- Single instance of React across entire application
- Applications control framework versions
- Packages declare compatibility requirements
- No version conflicts or duplicate instances

---

## TypeScript Configuration Strategy

**Base configs:**

- `base.json` - Uses `ESNext` + `Bundler` (modern default)
- `server.json` - Overrides to `NodeNext` (for Node.js server code)
- `react-library.json` - Extends base, adds JSX (for frontend packages)
- `nextjs.json` - Extends base, adds Next.js specifics (for Next.js apps)

**Why this works:**

- Backend packages explicitly opt into `NodeNext` (correct for Node.js)
- Frontend packages use `Bundler` (correct for bundled code)
- No `.js` extension errors in frontend code
- Proper module resolution for each context

**Pattern:**

```typescript
// packages/typescript-config/base.json
{
  "compilerOptions": {
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "erasableSyntaxOnly": true
  }
}

// packages/typescript-config/server.json
{
  "extends": "./base.json",
  "compilerOptions": {
    "module": "NodeNext",
    "moduleResolution": "NodeNext"
  }
}

// packages/typescript-config/react-library.json
{
  "extends": "./base.json",
  "compilerOptions": {
    "jsx": "react-jsx"
  }
}

// packages/features/products/frontend/tsconfig.json
{
  "extends": "@workspace/typescript-config/react-library.json"
}
```

**Config hierarchy:**

```
base.json (ESNext + Bundler) ← Modern default
├── react-library.json       ← Frontend packages
├── nextjs.json              ← Next.js apps
└── server.json (NodeNext)   ← Backend packages (explicit opt-in)
```

---

## Library Organization

### No Isomorphic Packages

**Decision:** Separate frontend and backend utilities rather than creating isomorphic packages.

**Why:**

- Most utilities are context-specific (Node.js APIs vs browser APIs)
- Simpler mental model - clear separation of concerns
- No conditional exports complexity for most packages
- Easier to optimize builds for each context

**Pattern:**

```
packages/lib/
├── backend-server/      # Fastify utilities (built for deployment)
├── backend-utils/       # Backend utilities (built for deployment)
└── frontend-testing/    # Vitest config (source-only)
```

**Benefits:**

- Frontend packages stay source-only (great DX, jump to source works)
- Backend packages are clearly backend-only (no confusion)
- Each package optimized for its runtime environment

---

## Package Organization Patterns

### Component Hierarchy

**File naming convention:** kebab-case (e.g., `admin-page.tsx`, not `AdminPage.tsx`)

**Intended usage example:**

```tsx
// @workspace/ui - Primitives
// File: packages/ui/src/components/card.tsx
export { Card, CardHeader, CardContent } from "./components/card";
export { Button } from "./components/button";

// @workspace/blocks - Page layouts for different contexts
// File: packages/blocks/src/components/admin-page.tsx
import { Card } from "@workspace/ui/components/card";

// Admin context: sidebar navigation + content area
export function AdminPage({ children, navigation }) {
  return (
    <div className="flex min-h-screen">
      <aside className="w-64 border-r">{navigation}</aside>
      <main className="flex-1">{children}</main>
    </div>
  );
}

// File: packages/blocks/src/components/customer-page.tsx
// Customer context: header + content + footer
export function CustomerPage({ children, header, footer }) {
  return (
    <div className="flex flex-col min-h-screen">
      <header className="border-b">{header}</header>
      <main className="flex-1">{children}</main>
      <footer className="border-t">{footer}</footer>
    </div>
  );
}

// @workspace/products-frontend - Feature components
// File: packages/features/products/frontend/src/components/admin-products-page.tsx
import { Card } from "@workspace/ui/components/card";
import { AdminPage } from "@workspace/blocks/components/admin-page";

// Admin view: Products management with sidebar
export function AdminProductsPage() {
  return (
    <AdminPage navigation={<AdminNav />}>
      <ProductList />
    </AdminPage>
  );
}

// File: packages/features/products/frontend/src/components/customer-products-page.tsx
// Customer view: Products catalog with header/footer
export function CustomerProductsPage() {
  return (
    <CustomerPage header={<SiteHeader />} footer={<SiteFooter />}>
      <ProductGrid />
    </CustomerPage>
  );
}
```

### Frontend Packages (Source-only)

Frontend packages are **not built** - they're consumed as source by Next.js via `transpilePackages`.

**Structure:**

```
src/
├── components/     # Exported components (kebab-case filenames)
│   ├── product-card.tsx
│   └── product-card.stories.tsx
├── hooks/          # Exported hooks (kebab-case filenames)
│   └── use-products.ts
└── lib/            # Internal utilities (not exported)
    ├── utils.ts
    └── utils.test.ts
```

**Package exports:**

```json
{
  "exports": {
    "./components/*": "./src/components/*.tsx",
    "./hooks/*": "./src/hooks/*.ts"
  }
}
```

**Key points:**

- **Filenames:** kebab-case (e.g., `product-card.tsx`, not `ProductCard.tsx`)
- Internal modules (`lib/`) are not exported
- Tests are co-located with implementation
- Uses `ESNext` + `Bundler` module resolution

### Backend Packages (Built with tsup)

Backend packages are **built** for production deployment.

**Structure:**

```
src/
├── index.ts        # Main entry point
└── *.ts            # Other modules
```

**Package exports:**

```json
{
  "exports": {
    "./format": {
      "import": {
        "types": "./dist/format.d.ts",
        "default": "./dist/format.js"
      },
      "require": {
        "types": "./dist/format.d.cts",
        "default": "./dist/format.cjs"
      }
    }
  }
}
```

**Key points:**

- Built with tsup to both ESM (`.js`) and CommonJS (`.cjs`)
- Conditional exports for dual-mode support
- Uses `NodeNext` module resolution
- Source-only in development (run with `tsx`)

---

## Build Verification Strategy

### Dependency Fingerprinting

**Decision:** Use MD5 hash of node_modules instead of Docker layer digests to verify build reproducibility.

**Why:**

- Docker layer digests include timestamps, causing false failures
- What matters is whether the same packages are installed, not build timestamps
- Simpler to understand and debug
- Provides clear pass/fail signal

**How it works:**

1. Build twice from scratch (no cache, `--no-cache` flag)
2. Hash the list of installed packages in `node_modules/.pnpm/`
3. Compare fingerprints between builds

**Implementation:**

```bash
# Generate fingerprint
find node_modules/.pnpm -mindepth 1 -maxdepth 1 | sort | md5sum

# Compare two builds
if [ "$fingerprint1" = "$fingerprint2" ]; then
  echo "✅ Builds are deterministic"
else
  echo "❌ Builds differ"
fi
```

**What this proves:**

- Same lockfile → same installed packages
- No host filesystem leaks
- Reproducible builds across machines and time
- Permissive version ranges don't cause drift (locked by `pnpm-lock.yaml`)

**Example:**

```
Frontend fingerprint: cc9abf0d8372574015d9dda4becdbb53
Backend fingerprint: 62cc3a4d36a0539e89cff6e08263acce

Build 1 = Build 2 ✅ (identical fingerprints)
```

---

## Testing Strategy

**Shared Vitest config:**

- `@workspace/frontend-testing` exports `vitest.config.ts`
- Packages extend this config
- Tests co-located with implementation
- Explicit imports (no `globals: true`)

**Running tests:**

```bash
# Run all tests
pnpm turbo test

# Run specific package tests
pnpm --filter=@workspace/products-frontend test
```

---

## Current Example Structure

```
monorepo/
├── apps/
│   └── docs/                    # Next.js documentation site
├── integrations/
│   └── demo/
│       ├── frontend/            # Next.js demo app (localhost:3000)
│       └── backend/             # Fastify demo server (localhost:4000)
├── packages/
│   ├── ui/                      # shadcn/ui + Tailwind v4 (primitives)
│   ├── blocks/                  # Composite components (e.g., SidebarLayout)
│   ├── eslint-config/           # Shared ESLint configs
│   ├── typescript-config/       # Shared TypeScript configs
│   │   ├── base.json            # ESNext + Bundler (modern default)
│   │   ├── nextjs.json          # ESNext + Bundler
│   │   ├── react-library.json   # ESNext + Bundler (for React packages)
│   │   └── server.json          # NodeNext (for backend packages)
│   ├── lib/
│   │   ├── backend-utils/       # Backend utilities (built with tsup)
│   │   ├── backend-server/      # Fastify utilities + CORS
│   │   └── frontend-testing/    # Shared Vitest config
│   └── features/
│       └── products/
│           ├── frontend/        # Product UI components + hooks
│           └── backend/         # Product API routes
└── deployments/                 # Docker infrastructure
```

---

## File Naming Conventions

### React Components

**Use kebab-case for all React component files:**

✅ **Correct:**

```
components/
├── product-card.tsx
├── product-card.stories.tsx
├── admin-page.tsx
└── customer-page.tsx
```

❌ **Incorrect:**

```
components/
├── ProductCard.tsx
├── AdminPage.tsx
└── CustomerPage.tsx
```

### Hooks

**Use kebab-case with `use-` prefix:**

✅ **Correct:**

```
hooks/
├── use-products.ts
├── use-auth.ts
└── use-local-storage.ts
```

### Utilities

**Use kebab-case:**

✅ **Correct:**

```
lib/
├── format-price.ts
├── validate-email.ts
└── api-client.ts
```

### Tests

**Co-locate with implementation, use `.test.ts` suffix:**

✅ **Correct:**

```
lib/
├── utils.ts
└── utils.test.ts

components/
├── product-card.tsx
└── product-card.test.tsx
```

### Stories

**Co-locate with component, use `.stories.tsx` suffix:**

✅ **Correct:**

```
components/
├── product-card.tsx
└── product-card.stories.tsx
```

### Component Names

**Use PascalCase for component names (not filenames):**

```tsx
// File: admin-page.tsx
export function AdminPage() { ... }  // ✅ PascalCase component name

// File: use-products.ts
export function useProducts() { ... }  // ✅ camelCase hook name
```

### Why Kebab-Case?

1. **Consistency with web standards** - URLs, CSS classes, HTML attributes all use kebab-case
2. **Case-insensitive filesystems** - Avoids issues on macOS/Windows
3. **Import clarity** - Clear distinction between filename and component name
4. **Industry trend** - Modern frameworks (Next.js App Router, Remix) use kebab-case
5. **Easier to read** - `admin-products-page.tsx` vs `AdminProductsPage.tsx`

**References:**

- Next.js App Router uses kebab-case for routes
- Remix uses kebab-case for routes
- shadcn/ui uses kebab-case for component files
- Tailwind CSS uses kebab-case for utilities

---

## Clean Scripts

### Root Clean Scripts

**Modular cleanup strategy (inspired by HeroUI):**

```json
{
  "scripts": {
    "clean": "pnpm clean:turbo && pnpm clean:node-modules && pnpm install",
    "clean:turbo": "turbo clean && rimraf .turbo",
    "clean:node-modules": "rimraf node_modules apps/**/node_modules packages/**/node_modules integrations/**/node_modules"
  }
}
```

**What each script does:**

- `clean` - Nuclear option: cleans everything and reinstalls
- `clean:turbo` - Cleans turbo cache and build artifacts
- `clean:node-modules` - Removes all node_modules directories

### Individual Package Clean Scripts

**Packages that build:**

```json
{
  "scripts": {
    "clean": "rimraf dist .turbo"
  }
}
```

**Packages that don't build:**

```json
{
  "scripts": {
    "clean": "rimraf .turbo"
  }
}
```

**Next.js apps:**

```json
{
  "scripts": {
    "clean": "rimraf .next .turbo"
  }
}
```
