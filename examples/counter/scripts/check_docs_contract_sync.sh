#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
COUNTER_DIR="${REPO_ROOT}/examples/counter"
README_FILE="${COUNTER_DIR}/README.md"
PLAN_FILE="${COUNTER_DIR}/PLAN.md"

require_file() {
  local file_path="$1"
  if [[ ! -f "${file_path}" ]]; then
    echo "Required file missing: ${file_path}" >&2
    exit 1
  fi
}

require_contains() {
  local file_path="$1"
  local expected="$2"
  local description="$3"

  if ! rg -Fq -- "${expected}" "${file_path}"; then
    echo "Missing ${description} in ${file_path}" >&2
    exit 1
  fi
}

require_file "${README_FILE}"
require_file "${PLAN_FILE}"

specversion=""
client_source=""
server_source=""
state_changed_type=""
declare -a command_types=()

while IFS= read -r line; do
  case "${line}" in
    contract:specversion=*) specversion="${line#contract:specversion=}" ;;
    contract:client_source=*) client_source="${line#contract:client_source=}" ;;
    contract:server_source=*) server_source="${line#contract:server_source=}" ;;
    contract:state_changed_type=*) state_changed_type="${line#contract:state_changed_type=}" ;;
    contract:command_type=*) command_types+=("${line#contract:command_type=}") ;;
  esac
done < <(
  cd "${COUNTER_DIR}" &&
    mix run -e '
      alias CounterExample.EventContract

      IO.puts("contract:specversion=" <> EventContract.specversion())
      IO.puts("contract:client_source=" <> EventContract.client_source())
      IO.puts("contract:server_source=" <> EventContract.server_source())
      IO.puts("contract:state_changed_type=" <> EventContract.state_changed_type())

      EventContract.command_types()
      |> Enum.sort()
      |> Enum.each(&(IO.puts("contract:command_type=" <> &1)))
    '
)

if [[ -z "${specversion}" || -z "${client_source}" || -z "${server_source}" || -z "${state_changed_type}" ]]; then
  echo "Unable to read contract values from CounterExample.EventContract" >&2
  exit 1
fi

if [[ "${#command_types[@]}" -eq 0 ]]; then
  echo "No command types returned by CounterExample.EventContract.command_types/0" >&2
  exit 1
fi

for command_type in "${command_types[@]}"; do
  require_contains "${README_FILE}" "\`${command_type}\`" "command event type ${command_type}"
done

require_contains "${README_FILE}" "\`${state_changed_type}\`" "state_changed event type ${state_changed_type}"
require_contains "${README_FILE}" "\`${client_source}\`" "client source ${client_source}"
require_contains "${README_FILE}" "\`${server_source}\`" "server source ${server_source}"
require_contains "${README_FILE}" "\`\"${specversion}\"\`" "specversion ${specversion}"
require_contains "${README_FILE}" "WebUi.ServerAgentDispatcher" "dispatcher architecture reference"
require_contains "${README_FILE}" "CounterExample.CounterEventHandler" "compatibility wrapper reference"
require_contains "${README_FILE}" "## Troubleshooting" "troubleshooting runbook section"
require_contains "${README_FILE}" "## Debugging Guide" "debugging runbook section"

require_contains "${PLAN_FILE}" "Phase 6 - Release Gate and Ongoing Maintenance" "phase 6 section"
require_contains "${PLAN_FILE}" "6.6 Add a periodic doc drift check" "maintenance checklist item 6.6"
require_contains "${PLAN_FILE}" "6.7 Keep event contract examples synchronized" "maintenance checklist item 6.7"
require_contains "${PLAN_FILE}" "6.8 Update this plan when architecture changes" "maintenance checklist item 6.8"
require_contains "${PLAN_FILE}" "Decision: Move to the server-agent dispatcher path as canonical architecture." "canonical dispatcher decision"

echo "Counter docs and contract checks passed."
