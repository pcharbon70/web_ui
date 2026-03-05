# Counter Example

Runnable counter application using the parent `web_ui` library.

## Status

Implemented:
- Interactive counter UI at `/counter`
- WebSocket CloudEvents round-trip
- Server-side counter state via `CounterExample.CounterServer`

Roadmap details remain in [`PLAN.md`](./PLAN.md).

## Run

```bash
# from repo root (one-time for frontend assets)
mix setup
mix assets.build --force

# then run the example app
cd examples/counter
mix deps.get
mix server
```

Then open [http://localhost:4100](http://localhost:4100).

Open [http://localhost:4100/counter](http://localhost:4100/counter) for the
counter page.

## Notes

- This example depends on the local parent repo via `{:web_ui, path: "../.."}`.
- The app boots `WebUi.Endpoint` in dev via `config/dev.exs`.
