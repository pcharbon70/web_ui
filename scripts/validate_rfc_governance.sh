#!/usr/bin/env bash
set -euo pipefail

ROOT="${RFC_GOVERNANCE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

MATRIX="specs/conformance/spec_conformance_matrix.md"
SCENARIO_CATALOG="specs/conformance/scenario_catalog.md"
RFC_INDEX="rfcs/index.md"
RFC_TEMPLATE="rfcs/templates/rfc-template.md"
RFC_FILE_REGEX='^rfcs/RFC-[0-9]{4}-[a-z0-9][a-z0-9-]*\.md$'
ALLOWED_STATUS_REGEX='^(Draft|Proposed|Accepted|Rejected|Implemented|Superseded)$'
ALLOWED_ACTION_REGEX='^(create|update|deprecate)$'
ALLOWED_PLANE_REGEX='^(Product Plane|UI Runtime Plane|Transport Plane|Runtime Authority Plane|Data Plane|Extension Plane)$'

failures=0

fail() {
  echo "FAIL: $1"
  failures=1
}

trim() {
  echo "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

if [[ ! -f "$MATRIX" ]]; then
  echo "ERROR: missing conformance matrix: $MATRIX"
  exit 1
fi

if [[ ! -f "$SCENARIO_CATALOG" ]]; then
  echo "ERROR: missing scenario catalog: $SCENARIO_CATALOG"
  exit 1
fi

if [[ ! -d "rfcs" ]]; then
  echo "Skipping RFC governance validation: missing rfcs/ directory."
  exit 0
fi

if [[ ! -f "$RFC_INDEX" ]]; then
  echo "ERROR: missing RFC index: $RFC_INDEX"
  exit 1
fi

if [[ ! -f "$RFC_TEMPLATE" ]]; then
  echo "ERROR: missing RFC template: $RFC_TEMPLATE"
  exit 1
fi

RFC_FILES="$(rg --files rfcs | rg "$RFC_FILE_REGEX" | sort || true)"

if [[ -z "$RFC_FILES" ]]; then
  echo "No RFC files found under rfcs/ matching RFC-XXXX naming convention."
  exit 0
fi

KNOWN_REQ_FAMILIES="$(rg -o 'REQ-[A-Z]+' "$MATRIX" | sort -u || true)"
KNOWN_SCENARIOS="$(rg -o 'SCN-[0-9]+' "$SCENARIO_CATALOG" | sort -u || true)"
INDEX_RFC_IDS="$(rg -o 'RFC-[0-9]{4}' "$RFC_INDEX" | sort -u || true)"

echo "Checking RFC metadata, governance mappings, and creation plans..."
while IFS= read -r rfc; do
  [[ -z "$rfc" ]] && continue

  base="$(basename "$rfc")"
  rfc_id_from_filename="$(echo "$base" | sed -E 's/^(RFC-[0-9]{4})-.+$/\1/')"

  if ! rg -q '^## Metadata$' "$rfc"; then
    fail "missing required section '## Metadata' in $rfc"
  fi

  if ! rg -q '^## Governance Mapping$' "$rfc"; then
    fail "missing required section '## Governance Mapping' in $rfc"
  fi

  if ! rg -q '^## Spec Creation Plan$' "$rfc"; then
    fail "missing required section '## Spec Creation Plan' in $rfc"
  fi

  rfc_id_line="$(rg -n '^- RFC ID: `RFC-[0-9]{4}`$' "$rfc" | head -n1 || true)"
  if [[ -z "$rfc_id_line" ]]; then
    fail "missing machine-readable RFC ID metadata in $rfc"
  else
    rfc_id_in_doc="$(echo "$rfc_id_line" | sed -E 's/.*`(RFC-[0-9]{4})`.*/\1/')"
    if [[ "$rfc_id_in_doc" != "$rfc_id_from_filename" ]]; then
      fail "RFC ID mismatch in $rfc (filename=$rfc_id_from_filename metadata=$rfc_id_in_doc)"
    fi
  fi

  status_line="$(rg -n '^- Status: `[^`]+`$' "$rfc" | head -n1 || true)"
  if [[ -z "$status_line" ]]; then
    fail "missing machine-readable Status metadata in $rfc"
  else
    status_value="$(echo "$status_line" | sed -E 's/.*`([^`]+)`.*/\1/')"
    if ! echo "$status_value" | rg -q "$ALLOWED_STATUS_REGEX"; then
      fail "invalid RFC status '$status_value' in $rfc"
    fi
  fi

  if ! echo "$INDEX_RFC_IDS" | grep -Fxq "$rfc_id_from_filename"; then
    fail "RFC index is missing row for $rfc_id_from_filename"
  fi

  contract_refs="$(rg -o 'specs/contracts/[a-z0-9_]+\.md' "$rfc" | sort -u || true)"
  if [[ -z "$contract_refs" ]]; then
    fail "missing contract references under specs/contracts in $rfc"
  else
    while IFS= read -r contract_path; do
      [[ -z "$contract_path" ]] && continue
      if [[ ! -f "$contract_path" ]]; then
        fail "RFC references missing contract path $contract_path in $rfc"
      fi
    done <<< "$contract_refs"
  fi

  req_refs="$(rg -o 'REQ-[A-Z]+(?:-[0-9]{3}|-\*)?' "$rfc" | sort -u || true)"
  if [[ -z "$req_refs" ]]; then
    fail "missing REQ mappings in $rfc"
  else
    while IFS= read -r req; do
      [[ -z "$req" ]] && continue
      req_family="$(echo "$req" | sed -E 's/(REQ-[A-Z]+).*/\1/')"
      if ! echo "$KNOWN_REQ_FAMILIES" | grep -Fxq "$req_family"; then
        fail "unknown REQ family '$req_family' in $rfc"
      fi
    done <<< "$req_refs"
  fi

  scn_refs="$(rg -o 'SCN-[0-9]+' "$rfc" | sort -u || true)"
  if [[ -z "$scn_refs" ]]; then
    fail "missing SCN mappings in $rfc"
  else
    while IFS= read -r scn; do
      [[ -z "$scn" ]] && continue
      if ! echo "$KNOWN_SCENARIOS" | grep -Fxq "$scn"; then
        fail "unknown SCN id '$scn' in $rfc"
      fi
    done <<< "$scn_refs"
  fi

  plan_block="$(awk '/^## Spec Creation Plan/{flag=1;next}/^## /{if(flag)exit}flag' "$rfc")"
  if [[ -z "$plan_block" ]]; then
    fail "empty Spec Creation Plan block in $rfc"
    continue
  fi

  plan_rows=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" == \|* ]] || continue

    if echo "$line" | rg -q '^\|[[:space:]]*Action[[:space:]]*\|'; then
      continue
    fi

    if ! echo "$line" | rg -q '[A-Za-z0-9]'; then
      continue
    fi

    plan_rows=$((plan_rows + 1))

    IFS='|' read -r _ action spec_path component_title control_plane req_cell scn_cell ac_cell _ <<< "$line"

    action="$(trim "$action" | tr '[:upper:]' '[:lower:]')"
    spec_path="$(trim "$spec_path")"
    control_plane="$(trim "$control_plane")"
    req_cell="$(trim "$req_cell")"
    scn_cell="$(trim "$scn_cell")"
    ac_cell="$(trim "$ac_cell")"

    if ! echo "$action" | rg -q "$ALLOWED_ACTION_REGEX"; then
      fail "invalid action '$action' in Spec Creation Plan for $rfc"
    fi

    if ! echo "$spec_path" | rg -q '^specs/.+\.md$'; then
      fail "invalid spec path '$spec_path' in Spec Creation Plan for $rfc"
    fi

    if ! echo "$control_plane" | rg -q "$ALLOWED_PLANE_REGEX"; then
      fail "invalid control plane '$control_plane' for $spec_path in $rfc"
    fi

    row_req_refs="$(echo "$req_cell" | rg -o 'REQ-[A-Z]+(?:-[0-9]{3}|-\*)?' | sort -u || true)"
    if [[ -z "$row_req_refs" ]]; then
      fail "missing REQ mapping in Spec Creation Plan row for $spec_path in $rfc"
    else
      while IFS= read -r req; do
        [[ -z "$req" ]] && continue
        req_family="$(echo "$req" | sed -E 's/(REQ-[A-Z]+).*/\1/')"
        if ! echo "$KNOWN_REQ_FAMILIES" | grep -Fxq "$req_family"; then
          fail "unknown REQ family '$req_family' in plan row for $spec_path in $rfc"
        fi
      done <<< "$row_req_refs"
    fi

    row_scn_refs="$(echo "$scn_cell" | rg -o 'SCN-[0-9]+' | sort -u || true)"
    if [[ -z "$row_scn_refs" ]]; then
      fail "missing SCN mapping in Spec Creation Plan row for $spec_path in $rfc"
    else
      while IFS= read -r scn; do
        [[ -z "$scn" ]] && continue
        if ! echo "$KNOWN_SCENARIOS" | grep -Fxq "$scn"; then
          fail "unknown SCN id '$scn' in plan row for $spec_path in $rfc"
        fi
      done <<< "$row_scn_refs"
    fi

    if [[ -z "$ac_cell" ]] || ! echo "$ac_cell" | rg -q 'AC-[0-9]{2}'; then
      fail "missing AC seed IDs in Spec Creation Plan row for $spec_path in $rfc"
    fi

    case "$action" in
      update|deprecate)
        if [[ ! -f "$spec_path" ]]; then
          fail "action '$action' points to missing existing file $spec_path in $rfc"
        fi
        ;;
    esac
  done <<< "$plan_block"

  if [[ "$plan_rows" -eq 0 ]]; then
    fail "Spec Creation Plan in $rfc has no actionable rows"
  fi
done <<< "$RFC_FILES"

DIFF_BASE="${DIFF_BASE:-}"
DIFF_HEAD="${DIFF_HEAD:-}"
DIFF_RANGE=""
CHANGED_FILES=""

if [[ -n "$DIFF_BASE" && -n "$DIFF_HEAD" ]] \
  && git rev-parse --verify "${DIFF_BASE}^{commit}" >/dev/null 2>&1 \
  && git rev-parse --verify "${DIFF_HEAD}^{commit}" >/dev/null 2>&1; then
  DIFF_RANGE="${DIFF_BASE}..${DIFF_HEAD}"
fi

if [[ -n "$DIFF_RANGE" ]]; then
  CHANGED_FILES="$(git diff --name-only "$DIFF_RANGE" -- rfcs specs scripts/validate_rfc_governance.sh .github/workflows/rfc-governance.yml || true)"
else
  CHANGED_FILES="$({
    git diff --name-only -- rfcs specs scripts/validate_rfc_governance.sh .github/workflows/rfc-governance.yml
    git diff --name-only --cached -- rfcs specs scripts/validate_rfc_governance.sh .github/workflows/rfc-governance.yml
  } | sort -u | sed '/^$/d')"
fi

if [[ -n "$CHANGED_FILES" ]]; then
  CHANGED_RFC_FILES="$(echo "$CHANGED_FILES" | rg "$RFC_FILE_REGEX" || true)"
  CHANGED_SPECS="$(echo "$CHANGED_FILES" | rg '^specs/.+\.md$' || true)"

  if [[ -n "$CHANGED_RFC_FILES" ]]; then
    while IFS= read -r rfc; do
      [[ -z "$rfc" ]] && continue
      [[ -f "$rfc" ]] || continue

      status_line="$(rg -n '^- Status: `[^`]+`$' "$rfc" | head -n1 || true)"
      [[ -z "$status_line" ]] && continue

      status_value="$(echo "$status_line" | sed -E 's/.*`([^`]+)`.*/\1/')"
      if [[ "$status_value" == "Accepted" || "$status_value" == "Implemented" ]]; then
        if [[ -z "$CHANGED_SPECS" ]]; then
          fail "accepted/implemented RFC changes require at least one specs/*.md change in the same change set ($rfc)"
        fi
      fi
    done <<< "$CHANGED_RFC_FILES"
  fi
fi

if [[ "$failures" -ne 0 ]]; then
  echo
  echo "RFC governance validation failed."
  exit 1
fi

echo "RFC governance validation passed."
