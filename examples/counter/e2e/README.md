# Counter E2E Suite

Playwright suite for the counter example.

## Coverage

- Load/connect flow
- Increment/decrement/reset command round-trip
- Reconnect recovery
- Multi-client sync (two tabs)
- Malformed channel payload handling
- Rapid command burst convergence

## Run

From repo root:

```bash
npm run test:e2e:counter
```

## CI Setup

Install Chromium before running tests:

```bash
npx playwright install --with-deps chromium
npm run test:e2e:counter
```

## Notes

- Tests run against `MIX_ENV=dev` via `examples/counter/mix server`.
- The interop layer exposes `window.__webuiTest` only when `window.__WEBUI_E2E__ = true`.
