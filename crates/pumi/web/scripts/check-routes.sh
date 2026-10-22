#!/usr/bin/env bash
# Fail if crates/pumi/web/src/routeTree.gen.ts is not what `tsr generate` would produce.
# Run from the repository root (prek local hooks do).
set -euo pipefail

pnpm --dir crates/pumi/web gen:routes
git diff --exit-code -- crates/pumi/web/src/routeTree.gen.ts
