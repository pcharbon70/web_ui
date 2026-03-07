# WebUi

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `web_ui` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:web_ui, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/web_ui>.

## Conformance

Run the deterministic conformance harness locally:

```bash
./scripts/run_conformance.sh
```

Quick scenario-alignment report without running tests:

```bash
./scripts/run_conformance.sh --report-only
```

Convenience aliases:

```bash
make conformance
make conformance-report
```

Triage flow for failures:

1. Fix any scenario-alignment errors first (`SCN-*` missing from catalog/matrix/tests).
2. Re-run `./scripts/run_conformance.sh --report-only` and confirm alignment passes.
3. Run `./scripts/run_conformance.sh` to reproduce test failures with deterministic seed.
4. Update contracts, matrix, and tests in the same change set when behavior changes.
