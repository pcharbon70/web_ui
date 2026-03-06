# IUR Interpretation Contract

This contract defines how `web_ui` interprets `UnifiedIUR` layouts and signal declarations.

`../unified_iur` and `../unified-ui` are external compatibility references for shape and behavior alignment. They are not normative ownership sources for `web_ui`.

## External Compatibility References

| Reference | Compatibility Role | Ownership |
|---|---|---|
| `../unified_iur` | Canonical struct families and field shapes for IUR layout/widget trees | External |
| `../unified-ui` | Canonical signal naming and routing-key precedence expectations | External |

## Requirement Set

- `REQ-IUR-001`: `web_ui` MUST interpret IUR trees against the canonical struct families from `../unified_iur` and MUST version-track compatibility explicitly.
- `REQ-IUR-002`: External IUR/DSL references MUST be treated as compatibility inputs only and MUST NOT redefine control-plane authority from [control_plane_ownership_matrix.md](/Users/Pascal/code/unified/web_ui/specs/contracts/control_plane_ownership_matrix.md).
- `REQ-IUR-003`: The interpreter MUST support recursive layout traversal for `UnifiedIUR.Layouts.VBox` and `UnifiedIUR.Layouts.HBox`, preserving declared child order deterministically.
- `REQ-IUR-004`: Supported widget compatibility baseline MUST include the IUR widget families currently emitted by `unified-ui` builder flows.
- `REQ-IUR-005`: Unsupported, malformed, or ambiguous IUR nodes MUST fail closed with typed protocol/validation errors.
- `REQ-IUR-006`: Signal handler normalization MUST accept only: `atom()`, `{atom(), map()}`, and `{module(), atom(), list()}`; all other handler shapes MUST be rejected.
- `REQ-IUR-007`: Standard signal names MUST map to canonical signal types compatible with `unified-ui` standard signals.
- `REQ-IUR-008`: Signal route-key extraction MUST preserve compatibility with `unified-ui` precedence for click/change/submit signals.
- `REQ-IUR-009`: IUR interpretation and signal dispatch preparation MUST preserve `RuntimeContext` continuity (`correlation_id`, `request_id`) for downstream transport.
- `REQ-IUR-010`: IUR interpretation success/failure paths MUST emit observability events required by [observability_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/observability_contract.md).

## Compatibility Baseline

### Layout Families

- `UnifiedIUR.Layouts.VBox`
- `UnifiedIUR.Layouts.HBox`

### Widget Families (Current Builder Compatibility Surface)

- `UnifiedIUR.Widgets.Text`
- `UnifiedIUR.Widgets.Button`
- `UnifiedIUR.Widgets.Label`
- `UnifiedIUR.Widgets.TextInput`
- `UnifiedIUR.Widgets.Gauge`
- `UnifiedIUR.Widgets.Sparkline`
- `UnifiedIUR.Widgets.BarChart`
- `UnifiedIUR.Widgets.LineChart`
- `UnifiedIUR.Widgets.Table`
- `UnifiedIUR.Widgets.Column`
- `UnifiedIUR.Widgets.Menu`
- `UnifiedIUR.Widgets.MenuItem`
- `UnifiedIUR.Widgets.ContextMenu`
- `UnifiedIUR.Widgets.Tabs`
- `UnifiedIUR.Widgets.Tab`
- `UnifiedIUR.Widgets.TreeView`
- `UnifiedIUR.Widgets.TreeNode`

## Canonical Standard Signal Mapping

| Signal Name | Canonical Signal Type |
|---|---|
| `:click` | `unified.button.clicked` |
| `:change` | `unified.input.changed` |
| `:submit` | `unified.form.submitted` |
| `:focus` | `unified.element.focused` |
| `:blur` | `unified.element.blurred` |
| `:select` | `unified.item.selected` |

## Signal Route-Key Precedence

| Signal Kind | Route-Key Precedence |
|---|---|
| click | `action` -> `button_id` -> `widget_id` -> `id` |
| change | `input_id` -> `widget_id` -> `field` -> `action` -> `id` |
| submit | `form_id` -> `action` -> `id` |

## Types

### IURInterpretRequest

```text
IURInterpretRequest {
  iur_tree: map | struct,
  context: RuntimeContext,
  compatibility_mode: "strict" | "forward_compatible"
}
```

### IURInterpretResult

```text
IURInterpretResult {
  outcome: "ok" | "error",
  normalized_tree?: map,
  normalized_signals?: map,
  error?: TypedError,
  events: RuntimeEventEnvelope[]
}
```

## Required Interpreter Events

Implementations MUST emit:

- `runtime.iur.interpreted.v1`
- `runtime.iur.interpretation_failed.v1`
- `runtime.iur.signal_normalized.v1`
- `runtime.iur.signal_rejected.v1`

## ADR References

- [ADR-0001-control-plane-authority.md](/Users/Pascal/code/unified/web_ui/specs/adr/ADR-0001-control-plane-authority.md)
