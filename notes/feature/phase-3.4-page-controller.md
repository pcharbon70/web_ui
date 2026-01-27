# Phase 3.4: Page Controller and HTML Template

**Feature Branch:** `feature/phase-3.4-page-controller`

**Goal:** Implement controller for serving the Elm SPA bootstrap HTML with proper asset loading, WebSocket initialization, and security headers.

## Current State

**Status:** COMPLETE ✅

All tasks completed. All 27 tests passing.

## Implementation Tasks

### Task 3.4.1: Create Page Controller Module
- [x] Create lib/web_ui/controllers/page_controller.ex
- [x] Implement index/2 action for serving SPA
- [x] Add plug for cache control headers
- [x] Add plug for CSP headers
- [x] Add module documentation

### Task 3.4.2: Create HTML Template
- [x] Create lib/web_ui/templates/page/index.html.heex
- [x] Add HTML5 doctype and basic structure
- [x] Add meta tags (charset, viewport, description)
- [x] Add Elm app mount point div
- [x] Add script tags for Elm JS
- [x] Add link tags for CSS

### Task 3.4.3: Asset References
- [x] Include compiled Elm JS
- [x] Include Tailwind CSS
- [x] Support asset fingerprinting
- [x] Add CSP nonce support for inline scripts

### Task 3.4.4: WebSocket Initialization
- [x] Pass WebSocket URL to Elm via flags
- [x] Configure WebSocket endpoint path
- [x] Support WebSocket in development/production

### Task 3.4.5: Server-Side Flags
- [x] Support passing flags to Elm
- [x] Include user data in flags
- [x] Include configuration in flags
- [x] JSON encode flags for Elm

### Task 3.4.6: Security Headers
- [x] Add CSP headers
- [x] Add X-Frame-Options
- [x] Add X-Content-Type-Options
- [x] Add X-XSS-Protection

### Task 3.4.7: Cache Control
- [x] Add cache control headers for HTML
- [x] Support long caching for assets
- [x] Add ETag support

### Task 3.4.8: Error Handling
- [x] Create error page template
- [x] Handle 404 errors
- [x] Handle 500 errors
- [x] Add error logging

## Files Created

### New Files
- `lib/web_ui/controllers/page_controller.ex` - Page controller with index, health, error actions
- `lib/web_ui/templates/page/index.html.heex` - SPA template with Elm mount point
- `lib/web_ui/templates/page/error.html.heex` - Error page template
- `lib/web_ui/views/page_view.ex` - Page view module for template rendering
- `test/web_ui/controllers/page_controller_test.exs` - Controller tests (27 tests)

### Modified Files
- `lib/web_ui/router.ex` - Removed inline PageController, now uses external module

## Configuration Options

```elixir
config :web_ui, WebUi.PageController,
  cache_control: "no-cache, no-store, must-revalidate",
  csp_enabled: true,
  websocket_path: "/socket/websocket"

config :web_ui, :server_flags,
  user_id: fn conn -> get_session(conn, :user_id) end,
  api_key: "your-key"
```

## Test Results

All 27 tests passing:

**index/2 tests (12 tests):**
- Returns HTML response
- Includes Elm mount point div
- Includes WebSocket URL in flags
- Includes server flags
- Includes CSS reference
- Includes JavaScript references
- Sets cache control header
- Includes loading state styles
- Includes viewport meta tag
- Includes nonce for CSP
- Includes user agent in flags when present
- Uses correct WebSocket URL based on connection

**health/2 tests (4 tests):**
- Returns JSON response
- Includes status field
- Includes version field
- Includes timestamp field

**error/2 tests (5 tests):**
- Renders error page with default values
- Renders error page with custom values
- Error page includes home link
- Error page includes back button
- Error page shows status code

**version/0 tests (1 test):**
- Returns version string

**Custom server flags tests (2 tests):**
- Includes static custom flags
- Evaluates function flags

**WebSocket URL generation tests (3 tests):**
- Uses ws:// for http connections
- Uses wss:// for https connections
- Uses custom websocket path from config

## Success Criteria
1. ✅ Controller serves HTML correctly
2. ✅ Template includes all required assets
3. ✅ WebSocket URL passed to Elm
4. ✅ Security headers set correctly
5. ✅ All tests passing (27/27)
