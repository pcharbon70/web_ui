#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

export MIX_ENV="${MIX_ENV:-test}"

./scripts/validate_specs_governance.sh

if rg -q '@(module)?tag[[:space:]]+:conformance' test 2>/dev/null; then
  mix test --only conformance
else
  echo "INFO: no conformance-tagged tests found."
  echo "INFO: skipping mix test --only conformance (bootstrap mode)."
fi
