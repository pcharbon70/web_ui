#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
DOC_CHECK_SCRIPT="${SCRIPT_DIR}/check_docs_contract_sync.sh"

if [[ ! -f "${DOC_CHECK_SCRIPT}" ]]; then
  echo "Missing required script: ${DOC_CHECK_SCRIPT}" >&2
  exit 1
fi

cd "${REPO_ROOT}"

echo "[1/5] Running counter example tests"
(
  cd examples/counter
  mix test
)

echo "[2/5] Running parent counter channel/dispatcher integration tests"
mix test \
  test/web_ui/channels/event_channel_test.exs \
  test/web_ui/channels/event_channel_server_agent_test.exs \
  test/web_ui/server_agent_dispatcher_test.exs \
  test/web_ui/signal_bridge_test.exs

echo "[3/5] Running phase3 integration tests (explicitly included)"
mix test test/web_ui/phase3_integration_test.exs --include phase3_integration

echo "[4/5] Running docs and contract drift checks"
bash "${DOC_CHECK_SCRIPT}"

if [[ "${SKIP_E2E:-0}" == "1" ]]; then
  echo "[5/5] Skipping counter e2e smoke (SKIP_E2E=1)"
  exit 0
fi

echo "[5/5] Running counter e2e smoke tests"
npm run test:e2e:counter
