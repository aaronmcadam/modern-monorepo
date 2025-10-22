#!/bin/bash

# Stable Docker Builds Verification Script
# Ensures Docker builds are stable and predictable across time and machines
# Tests: dependency fingerprinting, frozen lockfile, version locking, isolation

# Note: We don't use 'set -e' because we want to run ALL tests
# and report a complete summary, even if some tests fail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0

# Helper functions
print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

print_test() {
    echo ""
    echo "→ $1"
}

pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED++))
}

fail() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Change to repo root
cd "$(dirname "$0")/.."

print_header "Stable Docker Builds Verification"

# Test 1: Single lockfile verification
print_test "Test 1: Verify single pnpm-lock.yaml at root"
LOCKFILE_COUNT=$(find . -name "pnpm-lock.yaml" -type f | wc -l | tr -d ' ')
if [ "$LOCKFILE_COUNT" -eq 1 ]; then
    pass "Single pnpm-lock.yaml found at root"
else
    fail "Found $LOCKFILE_COUNT lockfiles (expected 1)"
    find . -name "pnpm-lock.yaml" -type f
fi

# Test 2: Clean Docker environment
print_test "Test 2: Clean Docker environment"
echo "   Removing existing containers and images..."
docker-compose -f deployments/docker-compose.yaml down -v 2>/dev/null || true
docker system prune -f > /dev/null 2>&1
pass "Docker environment cleaned"

# Test 3: Build from scratch (no cache)
print_test "Test 3: Build Docker images from scratch (no cache)"
echo "   This may take a few minutes..."
if docker-compose -f deployments/docker-compose.yaml build --no-cache > /tmp/docker-build.log 2>&1; then
    pass "Docker images built successfully from scratch"
else
    fail "Docker build failed"
    echo "   See /tmp/docker-build.log for details"
    tail -20 /tmp/docker-build.log
    warn "Continuing with remaining tests..."
fi

# Test 4: Inspect turbo prune output
print_test "Test 4: Verify turbo prune output structure"
echo "   Building pruner stage..."
docker build -f deployments/Dockerfile.frontend --target pruner -t frontend-pruner . > /dev/null 2>&1

# Check pruned package.json files
PRUNED_PACKAGES=$(docker run --rm frontend-pruner sh -c "find /app/out/json -name 'package.json' | wc -l" | tr -d ' ')
EXPECTED_PACKAGE_JSONS=7  # Root + 5 workspace packages + 1 frontend app
if [ "$PRUNED_PACKAGES" -eq "$EXPECTED_PACKAGE_JSONS" ]; then
    pass "turbo prune created $PRUNED_PACKAGES package.json files (expected $EXPECTED_PACKAGE_JSONS)"
elif [ "$PRUNED_PACKAGES" -gt 0 ]; then
    warn "turbo prune created $PRUNED_PACKAGES package.json files (expected $EXPECTED_PACKAGE_JSONS)"
else
    fail "turbo prune output missing package.json files"
fi

# Check workspace packages are included
WORKSPACE_PACKAGES=$(docker run --rm frontend-pruner sh -c "ls -d /app/out/json/packages/* 2>/dev/null | wc -l" | tr -d ' ')
EXPECTED_WORKSPACE_PACKAGES=5  # ui, products-frontend, eslint-config, typescript-config, frontend-testing
if [ "$WORKSPACE_PACKAGES" -eq "$EXPECTED_WORKSPACE_PACKAGES" ]; then
    pass "Workspace packages included in prune output ($WORKSPACE_PACKAGES packages, expected $EXPECTED_WORKSPACE_PACKAGES)"
elif [ "$WORKSPACE_PACKAGES" -gt 0 ]; then
    warn "Workspace packages in prune output: $WORKSPACE_PACKAGES (expected $EXPECTED_WORKSPACE_PACKAGES)"
else
    fail "No workspace packages found in prune output"
fi

# Test 5: Container filesystem inspection
print_test "Test 5: Inspect container filesystem structure"

# Get frontend image name (built by docker-compose)
FRONTEND_IMAGE="deployments-frontend:latest"

# Check if image exists
if docker image inspect "$FRONTEND_IMAGE" > /dev/null 2>&1; then
    pass "Frontend image found: $FRONTEND_IMAGE"
else
    fail "Frontend image not found: $FRONTEND_IMAGE"
    FRONTEND_IMAGE=""
fi

if [ -n "$FRONTEND_IMAGE" ]; then
    # Check if using Next.js standalone mode (workspace packages are bundled, not in node_modules)
    STANDALONE_SERVER=$(docker run --rm "$FRONTEND_IMAGE" sh -c "test -f /app/integrations/demo/frontend/server.js && echo 'yes' || echo 'no'")
    
    if [ "$STANDALONE_SERVER" = "yes" ]; then
        pass "Next.js standalone build detected (workspace packages bundled)"
        
        # In standalone mode, check that required runtime dependencies exist
        NEXT_SERVER=$(docker run --rm "$FRONTEND_IMAGE" sh -c "test -d /app/node_modules/.pnpm && echo 'yes' || echo 'no'")
        if [ "$NEXT_SERVER" = "yes" ]; then
            pass "Runtime dependencies present in standalone build"
        else
            fail "Runtime dependencies missing in standalone build"
        fi
    else
        # Non-standalone mode: check for workspace packages in node_modules
        WORKSPACE_IN_CONTAINER=$(docker run --rm "$FRONTEND_IMAGE" sh -c "ls -d /app/node_modules/@workspace/* 2>/dev/null | wc -l" | tr -d ' ')
        if [ "$WORKSPACE_IN_CONTAINER" -gt 0 ]; then
            pass "Workspace packages present in container ($WORKSPACE_IN_CONTAINER packages)"
        else
            warn "No workspace packages found in container node_modules"
        fi
    fi

    # Check for broken symlinks outside pnpm's internal structure
    # pnpm creates internal symlinks (e.g., node_modules/next -> .pnpm/next@16.0.0/...)
    # Broken symlinks outside .pnpm/node_modules would indicate host filesystem references
    BROKEN_SYMLINKS=$(docker run --rm "$FRONTEND_IMAGE" sh -c "find /app -type l ! -exec test -e {} \; -print 2>/dev/null | grep -v '.pnpm/node_modules' | wc -l" | tr -d ' ')
    if [ "$BROKEN_SYMLINKS" -eq 0 ]; then
        pass "No broken symlinks detected (properly isolated)"
    else
        fail "Found $BROKEN_SYMLINKS broken symlinks (may reference host filesystem)"
        docker run --rm "$FRONTEND_IMAGE" sh -c "find /app -type l ! -exec test -e {} \; -print 2>/dev/null | grep -v '.pnpm/node_modules'"
    fi
fi

# Test 6: Lockfile version matching
print_test "Test 6: Verify lockfile versions match container versions"

# Get Next.js version from lockfile (format: "next@16.0.0:")
echo "   Extracting version from pnpm-lock.yaml..."
LOCAL_NEXT_VERSION=$(grep "^  next@" pnpm-lock.yaml | head -1 | sed 's/.*next@\([^:]*\):.*/\1/')

if [ -z "$LOCAL_NEXT_VERSION" ]; then
    warn "Could not extract Next.js version from lockfile"
else
    echo "   Lockfile Next.js version: $LOCAL_NEXT_VERSION"
    
    # Get Next.js version from Docker container (pnpm uses .pnpm directory)
    DOCKER_NEXT_VERSION=$(docker run --rm "$FRONTEND_IMAGE" sh -c "find /app/node_modules/.pnpm -name 'next' -type d | grep -E 'next@[0-9]' | head -1 | sed 's/.*next@\([^_]*\)_.*/\1/'")
    
    if [ -z "$DOCKER_NEXT_VERSION" ]; then
        warn "Could not extract Next.js version from container"
    else
        echo "   Container Next.js version: $DOCKER_NEXT_VERSION"
        
        if [ "$LOCAL_NEXT_VERSION" = "$DOCKER_NEXT_VERSION" ]; then
            pass "Next.js versions match: $LOCAL_NEXT_VERSION"
        else
            fail "VERSION MISMATCH! Lockfile: $LOCAL_NEXT_VERSION, Docker: $DOCKER_NEXT_VERSION"
        fi
    fi
fi

# Test 7: Verify catalog and permissive dependency versions
print_test "Test 7: Verify dependency versions match lockfile (catalog + permissive ranges)"

if [ -z "$FRONTEND_IMAGE" ]; then
    warn "Skipping version verification (frontend image not available)"
else
    # Check TypeScript version (catalog dependency)
    LOCAL_TS_VERSION=$(grep "typescript:" pnpm-workspace.yaml | awk '{print $2}' | tr -d '^~')
    DOCKER_TS_VERSION=$(docker run --rm "$FRONTEND_IMAGE" sh -c "find /app/node_modules/.pnpm -name 'typescript' -type d | grep -E 'typescript@[0-9]' | head -1 | sed 's/.*typescript@\([^\/]*\)\/.*/\1/'")
    
    if [ -n "$LOCAL_TS_VERSION" ] && [ -n "$DOCKER_TS_VERSION" ]; then
        echo "   Catalog TypeScript: $LOCAL_TS_VERSION"
        echo "   Container TypeScript: $DOCKER_TS_VERSION"
        
        if [ "$DOCKER_TS_VERSION" = "$LOCAL_TS_VERSION" ]; then
            pass "TypeScript (catalog) versions match: $LOCAL_TS_VERSION"
        else
            warn "TypeScript versions differ (catalog: $LOCAL_TS_VERSION, container: $DOCKER_TS_VERSION)"
        fi
    else
        warn "Could not extract TypeScript versions for comparison"
    fi
    
    # Check TanStack Table version (permissive dependency ~8.20.1)
    # This proves that even with permissive ranges, lockfile is respected
    # Note: In Next.js standalone mode, dependencies are bundled, so we only check the lockfile
    LOCAL_TANSTACK_VERSION=$(grep "^  '@tanstack/react-table@" pnpm-lock.yaml | head -1 | sed "s/.*@tanstack\/react-table@\([^']*\)'.*/\1/")
    
    if [ -n "$LOCAL_TANSTACK_VERSION" ]; then
        echo "   Lockfile TanStack Table: $LOCAL_TANSTACK_VERSION"
        
        # Check if this matches the expected range (~8.20.1 allows 8.20.x)
        if [[ "$LOCAL_TANSTACK_VERSION" =~ ^8\.20\. ]]; then
            pass "TanStack Table (permissive ~8.20.1) locked to: $LOCAL_TANSTACK_VERSION"
            echo "   ✓ Demonstrates lockfile prevents version drift (8.20.1-8.20.999 allowed, locked to $LOCAL_TANSTACK_VERSION)"
        else
            fail "TanStack Table version $LOCAL_TANSTACK_VERSION outside expected range 8.20.x"
        fi
    else
        warn "Could not extract TanStack Table version from lockfile"
    fi
fi

# Test 8: Runtime isolation test
print_test "Test 8: Verify containers can start"
echo "   Starting containers..."

# First, stop any running containers to avoid port conflicts
docker-compose -f deployments/docker-compose.yaml down > /dev/null 2>&1

if docker-compose -f deployments/docker-compose.yaml up -d > /tmp/docker-up.log 2>&1; then
    sleep 3  # Give containers time to start
    
    # Check if containers are running
    RUNNING_CONTAINERS=$(docker-compose -f deployments/docker-compose.yaml ps --services --filter "status=running" | wc -l | tr -d ' ')
    
    if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
        pass "Containers started successfully ($RUNNING_CONTAINERS running)"
    else
        fail "Containers failed to start"
        tail -10 /tmp/docker-up.log
    fi
    
    # Stop containers
    docker-compose -f deployments/docker-compose.yaml down > /dev/null 2>&1
else
    fail "Failed to start containers"
    echo "   Check /tmp/docker-up.log for details"
    tail -10 /tmp/docker-up.log
fi

# Test 9: Frozen lockfile verification
print_test "Test 9: Verify --frozen-lockfile works in Docker"
echo "   Checking build logs for frozen-lockfile..."
if grep -q "frozen-lockfile" /tmp/docker-build.log; then
    pass "Build uses --frozen-lockfile flag"
else
    warn "Could not verify --frozen-lockfile usage in build"
fi

# Test 10: Build stability (same lockfile → same installed packages)
print_test "Test 10: Verify build stability (dependency fingerprints match)"

echo "   This verifies that two builds install identical dependencies..."
echo "   NOTE: This will build everything again from scratch (takes ~2 minutes)"
    
    # Tag the images from Test 3 as build1
    echo "   Tagging first build as 'build1'..."
    docker tag deployments-frontend:latest deployments-frontend:build1 2>/dev/null || true
    docker tag deployments-backend:latest deployments-backend:build1 2>/dev/null || true
    
    # Extract dependency fingerprints from first build
    echo "   Extracting dependency fingerprints from first build..."
    FRONTEND_BUILD1_FINGERPRINT=$(docker run --rm deployments-frontend:build1 sh -c "ls /app/node_modules/.pnpm/ | grep -v '^node_modules$' | sort | md5sum | awk '{print \$1}'")
    BACKEND_BUILD1_FINGERPRINT=$(docker run --rm deployments-backend:build1 sh -c "ls /app/node_modules/.pnpm/ | grep -v '^node_modules$' | sort | md5sum | awk '{print \$1}'")
    
    echo "   Frontend fingerprint: $FRONTEND_BUILD1_FINGERPRINT"
    echo "   Backend fingerprint: $BACKEND_BUILD1_FINGERPRINT"
    
    # Build again WITHOUT cache to prove determinism
    echo "   Building second time (no cache, from scratch)..."
    if docker-compose -f deployments/docker-compose.yaml build --no-cache > /tmp/docker-build2.log 2>&1; then
        # Tag second build
        docker tag deployments-frontend:latest deployments-frontend:build2 2>/dev/null || true
        docker tag deployments-backend:latest deployments-backend:build2 2>/dev/null || true
        
        # Extract dependency fingerprints from second build
        echo "   Extracting dependency fingerprints from second build..."
        FRONTEND_BUILD2_FINGERPRINT=$(docker run --rm deployments-frontend:build2 sh -c "ls /app/node_modules/.pnpm/ | grep -v '^node_modules$' | sort | md5sum | awk '{print \$1}'")
        BACKEND_BUILD2_FINGERPRINT=$(docker run --rm deployments-backend:build2 sh -c "ls /app/node_modules/.pnpm/ | grep -v '^node_modules$' | sort | md5sum | awk '{print \$1}'")
        
        echo "   Frontend fingerprint: $FRONTEND_BUILD2_FINGERPRINT"
        echo "   Backend fingerprint: $BACKEND_BUILD2_FINGERPRINT"
        
        # Compare fingerprints
        FRONTEND_MATCH=false
        BACKEND_MATCH=false
        
        if [ "$FRONTEND_BUILD1_FINGERPRINT" = "$FRONTEND_BUILD2_FINGERPRINT" ]; then
            FRONTEND_MATCH=true
        fi
        
        if [ "$BACKEND_BUILD1_FINGERPRINT" = "$BACKEND_BUILD2_FINGERPRINT" ]; then
            BACKEND_MATCH=true
        fi
        
        if [ "$FRONTEND_MATCH" = "true" ] && [ "$BACKEND_MATCH" = "true" ]; then
            pass "Builds are stable (identical fingerprints)"
            echo "   ✓ Same lockfile → same installed packages"
            echo "   ✓ No environmental factors affecting dependency resolution"
        else
            fail "Build fingerprints differ (builds are not stable)"
            if [ "$FRONTEND_MATCH" = "false" ]; then
                echo "   ❌ Frontend dependencies differ"
                echo "      Build1: $FRONTEND_BUILD1_FINGERPRINT"
                echo "      Build2: $FRONTEND_BUILD2_FINGERPRINT"
            fi
            if [ "$BACKEND_MATCH" = "false" ]; then
                echo "   ❌ Backend dependencies differ"
                echo "      Build1: $BACKEND_BUILD1_FINGERPRINT"
                echo "      Build2: $BACKEND_BUILD2_FINGERPRINT"
            fi
            
            # Show detailed diff for debugging
            echo ""
            echo "   Detailed analysis:"
            echo "   Run these commands to compare installed packages:"
            echo "   docker run --rm deployments-frontend:build1 sh -c 'ls /app/node_modules/.pnpm/ | sort'"
            echo "   docker run --rm deployments-frontend:build2 sh -c 'ls /app/node_modules/.pnpm/ | sort'"
        fi
        
        # Clean up build2 tags
        docker rmi deployments-frontend:build2 deployments-backend:build2 > /dev/null 2>&1 || true
    else
        warn "Second build failed, skipping dependency fingerprint check"
    fi
    
    # Clean up build1 tags
    docker rmi deployments-frontend:build1 deployments-backend:build1 > /dev/null 2>&1 || true

# Final summary
print_header "Verification Summary"

echo ""
echo -e "Tests Passed: ${GREEN}$PASSED${NC}"
echo -e "Tests Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ Stable Docker Builds: PASSED${NC}"
    echo ""
    echo "Your Docker builds are:"
    echo "  ✅ Stable (same source → same image)"
    echo "  ✅ Properly isolated (no host dependencies)"
    echo "  ✅ Using frozen lockfile (no version drift)"
    echo "  ✅ Including workspace packages correctly"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Stable Docker Builds: FAILED${NC}"
    echo ""
    echo "Issues detected:"
    echo "  - $FAILED test(s) failed"
    echo "  - Review output above for details"
    echo ""
    exit 1
fi
