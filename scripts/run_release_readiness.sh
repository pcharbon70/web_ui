#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/run_release_readiness.sh [--report-only] [--skip-conformance] [--skip-tests]

Options:
  --report-only       Run governance + conformance alignment checks only.
  --skip-conformance  Skip conformance harness execution.
  --skip-tests        Skip full mix test execution.
USAGE
}

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

REPORT_ONLY=0
SKIP_CONFORMANCE=0
SKIP_TESTS=0

for arg in "$@"; do
  case "$arg" in
    --report-only) REPORT_ONLY=1 ;;
    --skip-conformance) SKIP_CONFORMANCE=1 ;;
    --skip-tests) SKIP_TESTS=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      usage
      exit 1
      ;;
  esac
done

echo "== Release Readiness Gate =="

echo "[1/5] Validate specs governance"
./scripts/validate_specs_governance.sh

echo "[2/5] Validate RFC governance"
./scripts/validate_rfc_governance.sh

echo "[3/5] Scan RFC governance debt (strict)"
./scripts/scan_rfc_governance_debt.sh --strict

if [[ "$SKIP_CONFORMANCE" -eq 0 ]]; then
  echo "[4/5] Run conformance harness"
  if [[ "$REPORT_ONLY" -eq 1 ]]; then
    ./scripts/run_conformance.sh --report-only --skip-governance
  else
    ./scripts/run_conformance.sh --skip-governance
  fi
else
  echo "[4/5] Conformance harness skipped (--skip-conformance)"
fi

if [[ "$REPORT_ONLY" -eq 0 && "$SKIP_TESTS" -eq 0 ]]; then
  echo "[5/5] Run full test suite"
  mix test
elif [[ "$REPORT_ONLY" -eq 1 ]]; then
  echo "[5/5] Full test suite skipped (--report-only)"
else
  echo "[5/5] Full test suite skipped (--skip-tests)"
fi

echo "Release readiness gate passed."
