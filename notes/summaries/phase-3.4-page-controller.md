# Phase 3.4: Page Controller and HTML Template - Summary

## Overview

Implemented the PageController and HTML templates for serving the Elm SPA bootstrap HTML. This completes section 3.4 of the implementation plan.

**Feature Branch:** `feature/phase-3.4-page-controller`
**Status:** Complete ✅
**Tests:** 27/27 passing

## Implementation Details

### Files Created

1. **`lib/web_ui/controllers/page_controller.ex`** (185 lines)
   - `index/2` - Serves the Elm SPA bootstrap HTML
   - `health/2` - Health check endpoint returning JSON
   - `error/2` - Renders error pages with custom status/title/message
   - `version/0` - Returns application version
   - `get_server_flags/2` - Builds server-side flags for Elm
   - `websocket_url/1` - Generates WebSocket URL based on connection scheme
   - `put_cache_header/1` - Sets cache control headers
   - `get_csp_nonce/1` - Generates/returns CSP nonce

2. **`lib/web_ui/templates/page/index.html.heex`** (52 lines)
   - HTML5 structure with proper doctype
   - Meta tags (charset, viewport, description)
   - Elm app mount point (`#app` div with loading state)
   - Inline script for WebSocket URL and server flags
   - Script references for interop.js and app.js
   - CSS reference for app.css
   - Loading spinner styles

3. **`lib/web_ui/templates/page/error.html.heex`** (93 lines)
   - Styled error page with gradient background
   - Status code display
   - Customizable title and message
   - Home link and back button
   - Responsive design

4. **`lib/web_ui/views/page_view.ex`** (15 lines)
   - Phoenix.Template integration
   - Template embedding from `lib/web_ui/templates/page/`
   - Import of Phoenix.HTML.raw for safe HTML rendering

5. **`test/web_ui/controllers/page_controller_test.exs`** (291 lines)
   - 27 comprehensive tests covering all functionality
   - Tests for index, health, error actions
   - Tests for WebSocket URL generation
   - Tests for custom server flags
   - Tests for security headers

### Files Modified

1. **`lib/web_ui/router.ex`**
   - Removed inline PageController module (previously 68 lines)
   - Routes now use external `WebUi.PageController` module
   - No functional changes to routing

## Key Features

### Server-Side Flags

The controller passes server-side data to Elm via `window.serverFlags`:

```javascript
window.serverFlags = {
  now: 1234567890,
  page: "index",
  user_agent: "Mozilla/5.0...",
  custom: { /* from application config */ }
};
```

Custom flags can be configured:

```elixir
config :web_ui, :server_flags,
  user_id: fn conn -> get_session(conn, :user_id) end,
  api_key: "your-key"
```

Functions are evaluated at request time with the conn as argument.

### WebSocket URL Generation

WebSocket URLs are automatically generated based on the connection:
- HTTP connections → `ws://host:port/socket/websocket`
- HTTPS connections → `wss://host:port/socket/websocket`

The path can be customized:

```elixir
config :web_ui, WebUi.PageController,
  websocket_path: "/custom/socket"
```

### Security Headers

- **Cache Control**: Configurable cache-control header (default: no-cache)
- **CSP Nonce**: Generated for inline scripts (supports CSP policies)
- **Additional Headers**: Applied via `WebUi.Plugs.SecurityHeaders`

### Health Check

The `/health` endpoint returns:

```json
{
  "status": "ok",
  "version": "0.1.0",
  "timestamp": 1234567890
}
```

### Error Pages

The `error/2` function accepts options:

```elixir
PageController.error(conn,
  status: 404,
  title: "Not Found",
  message: "The page you requested could not be found."
)
```

## Testing

All 27 tests pass, covering:

| Category | Tests | Description |
|----------|-------|-------------|
| index/2 | 12 | SPA serving, flags, headers |
| health/2 | 4 | JSON response, fields |
| error/2 | 5 | Error pages, status codes |
| version/0 | 1 | Version string |
| Custom Flags | 2 | Static and function flags |
| WebSocket | 3 | URL generation |

## Configuration

### Application Config

```elixir
config :web_ui, WebUi.PageController,
  cache_control: "no-cache, no-store, must-revalidate",
  websocket_path: "/socket/websocket"

config :web_ui, :server_flags,
  # Static values
  environment: Mix.env(),
  # Dynamic values (evaluated per request)
  user_id: fn conn -> get_session(conn, :user_id) end
```

## Lessons Learned

1. **Phoenix 1.8 Template Embedding**: Using `embed_templates "../templates/page/*"` in the view module is required for template discovery. The path is relative to the view file location.

2. **Phoenix.HTML Import**: Templates using `raw/1` require `import Phoenix.HTML, only: [raw: 1]` in the view module.

3. **Test Setup for Controllers**: When testing controller actions directly (not through endpoint dispatch), use `put_view/2` to set the view module on the test conn.

4. **Function Flag Resolution**: Server flags as maps with function values need special handling since Jason can't encode functions. The `resolve_flag_map/2` function evaluates functions before encoding.

## Dependencies

- `phoenix` ~> 1.7
- `phoenix_html` ~> 4.0
- `jason` ~> 1.4
- `plug` ~> 1.14

## Next Steps

Phase 3.5: Router and Routes Configuration (if not already complete)
- Define scope for WebUI routes
- Add SPA routes
- Add catch-all route for SPA routing
- Implement security middleware

## Branch Status

- **Branch:** `feature/phase-3.4-page-controller`
- **Ready to merge:** Yes, pending user approval
- **Test Status:** All 27 tests passing
