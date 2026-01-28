# Phase 3.5: Router and Routes Configuration

**Feature Branch:** `feature/phase-3.5-router`

**Goal:** Enhance Phoenix Router with SPA routing support, defpage macro for Elm pages, and security middleware.

## Current State

- Basic router exists with:
  - browser and api pipelines
  - GET / route for SPA
  - GET /health route for health check
- Completed:
  - Catch-all route for SPA routing
  - defpage macro for Elm pages
  - Security middleware integration (SecurityHeaders plug)
  - Router tests (16 tests, all passing)
  - Router.Defaults module for importable routes
  - __using__/1 macro for use WebUi.Router pattern

## Implementation Tasks

### Task 3.5.1: Add Catch-All Route for SPA
- [x] Add catch-all route /*path for SPA routing
- [x] Handle client-side routing properly
- [x] Support wildcard matching
- [x] Add configuration option (enable_catch_all)

### Task 3.5.2: Implement defpage Macro
- [x] Create defpage macro for defining Elm page routes
- [x] Support page-specific options
- [x] Generate appropriate route definitions
- [x] Support multiple page definitions (via pages/1 macro)

### Task 3.5.3: Security Middleware
- [x] Integrate existing SecurityHeaders plug
- [x] Add SecurityHeaders to browser pipeline
- [x] Add SecurityHeaders to api pipeline
- [ ] Add rate limiting support (future enhancement)
- [ ] Add request ID generation (future enhancement)
- [ ] Add basic auth hooks (future enhancement)

### Task 3.5.4: Router Defaults Module
- [x] Create WebUi.Router.Defaults for importable routes
- [x] Support both use and import patterns
- [x] Allow selective route inclusion (spa_routes, spa_index, spa_health, spa_catch_all, spa_page)

### Task 3.5.5: Enhanced API Pipeline
- [ ] Add rate limiting to API pipeline (future enhancement)
- [ ] Add API versioning support (future enhancement)
- [ ] Add authentication hooks (future enhancement)

### Task 3.5.6: Router Tests
- [x] Test SPA route serves HTML
- [x] Test health check returns 200
- [x] Test catch-all route works
- [x] Test defpage macro creates correct routes
- [x] Test security middleware is applied
- [x] Test Router.Defaults macros work correctly
- [x] Test use WebUi.Router pattern

## Files Modified

### Existing Files
- `lib/web_ui/router.ex` - Added catch-all route, defpage macro, pages macro, security middleware, __using__/1 callback

### New Files
- `lib/web_ui/router/defaults.ex` - Importable route defaults
- `test/web_ui/router_test.exs` - Router tests (16 tests)

## Configuration Options

```elixir
config :web_ui, WebUi.Router,
  enable_catch_all: true
```

## Test Results

All 16 router tests passing:
- Router structure (2 tests)
- Default routes (3 tests)
- defpage macro (2 tests)
- pages macro (1 test)
- Router.Defaults (5 tests)
- Extending the router (1 test)
- Security (2 tests)

Total test suite: 363 tests + 126 doctests = 489 tests, all passing

## Success Criteria
1. Catch-all route properly handles SPA client-side routing
2. defpage macro provides convenient way to define Elm pages
3. Security middleware integrated and configurable
4. All tests passing
