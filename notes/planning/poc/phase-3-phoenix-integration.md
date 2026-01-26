# Phase 3: Phoenix Integration

Implement Phoenix Endpoint, Channel, Router, and Controller for serving the Elm SPA and handling WebSocket communication with CloudEvents.

---

## 3.1 Phoenix Endpoint Configuration

Configure Phoenix Endpoint for serving static assets and WebSocket connections.

- [ ] **Task 3.1** Implement WebUI.Endpoint module

Set up the Phoenix Endpoint:

- [ ] 3.1.1 Create lib/web_ui/endpoint.ex with use Phoenix.Endpoint
- [ ] 3.1.2 Configure websocket endpoint with timeout
- [ ] 3.1.3 Configure static serving for compiled Elm assets
- [ ] 3.1.4 Configure cache headers for static assets
- [ ] 3.1.5 Add code reloading configuration for development
- [ ] 3.1.6 Configure SSL/TLS settings for production
- [ ] 3.1.7 Add security headers (CSP, X-Frame-Options, etc.)
- [ ] 3.1.8 Configure gzip compression
- [ ] 3.1.9 Add render errors configuration
- [ ] 3.1.10 Make endpoint configurable via application config

**Implementation Notes:**
- Support both standalone and embedded usage
- Provide sensible defaults for all settings
- Allow user applications to override configurations
- Include WebSocket origin checking for security
- Cache static assets with long max-age
- Enable code reloader in development only
- CSP headers should allow inline scripts for Elm initialization
- Include X-Content-Type-Options: nosniff

**Unit Tests for Section 3.1:**
- [ ] 3.1.1 Test endpoint configuration loads correctly
- [ ] 3.1.2 Test static files are served with correct headers
- [ ] 3.1.3 Test WebSocket endpoint accepts connections
- [ ] 3.1.4 Test code reloading in development
- [ ] 3.1.5 Test security headers are set correctly
- [ ] 3.1.6 Test gzip compression is applied

**Status:** PENDING - TBD - See `notes/summaries/section-3.1-endpoint.md` for details.

---

## 3.2 WebSocket Channel for CloudEvents

Implement Phoenix Channel for bidirectional CloudEvents communication over WebSocket.

- [ ] **Task 3.2** Implement WebUI.EventChannel

Create the WebSocket event channel:

- [ ] 3.2.1 Create lib/web_ui/channels/event_channel.ex
- [ ] 3.2.2 Define channel topic pattern ("events:*")
- [ ] 3.2.3 Implement join/3 for channel authorization
- [ ] 3.2.4 Implement handle_in/3 for incoming CloudEvents
- [ ] 3.2.5 Decode JSON CloudEvents from client messages
- [ ] 3.2.6 Encode and push CloudEvents to client
- [ ] 3.2.7 Add heartbeat/keepalive mechanism
- [ ] 3.2.8 Handle disconnect and cleanup
- [ ] 3.2.9 Add broadcasting for multi-client scenarios
- [ ] 3.2.10 Implement channel-specific event routing

**Implementation Notes:**
- Authorize joins via configurable callback
- Validate CloudEvents before processing using WebUI.CloudEvent
- Support both direct messages and broadcasts
- Handle reconnection gracefully with state recovery
- Include client identifier tracking via assigns
- Push connection status events (connected, disconnected)
- Support topic-based filtering for selective subscriptions
- Implement exponential backoff for reconnection attempts

**Unit Tests for Section 3.2:**
- [ ] 3.2.1 Test client can join channel
- [ ] 3.2.2 Test join authorization works correctly
- [ ] 3.2.3 Test incoming CloudEvent is decoded and handled
- [ ] 3.2.4 Test outgoing CloudEvent is pushed to client
- [ ] 3.2.5 Test broadcast sends to all subscribed clients
- [ ] 3.2.6 Test heartbeat keeps connection alive
- [ ] 3.2.7 Test disconnect triggers cleanup
- [ ] 3.2.8 Test invalid CloudEvents are rejected

**Status:** PENDING - TBD - See `notes/summaries/section-3.2-channel.md` for details.

---

## 3.3 Event Dispatcher and Router

Implement event routing from WebSocket channel to appropriate handlers (Jido agents or user callbacks).

- [ ] **Task 3.3** Implement event dispatcher system

Create the event routing infrastructure:

- [ ] 3.3.1 Create lib/web_ui/dispatcher.ex
- [ ] 3.3.2 Define behaviour for event handlers
- [ ] 3.3.3 Implement registry for handler subscriptions
- [ ] 3.3.4 Route events by type pattern matching
- [ ] 3.3.5 Route events by source pattern matching
- [ ] 3.3.6 Support wildcard subscriptions (prefix, suffix)
- [ ] 3.3.7 Add event filtering capabilities
- [ ] 3.3.8 Implement error handling and recovery
- [ ] 3.3.9 Add telemetry for event routing
- [ ] 3.3.10 Support both GenServer and function handlers

**Implementation Notes:**
- Pattern matching should be efficient (use Registry or ETS)
- Support multiple handlers per event type
- Handler failures should not crash the dispatcher
- Provide ordered delivery guarantees
- Use Phoenix.PubSub for multi-node scenarios
- Support middleware chain for event processing
- Include event tracing for debugging
- Track delivery status (delivered, failed, pending)

**Unit Tests for Section 3.3:**
- [ ] 3.3.1 Test handler can subscribe to event type
- [ ] 3.3.2 Test handler can unsubscribe from event type
- [ ] 3.3.3 Test event routes to correct handler by type
- [ ] 3.3.4 Test event routes to correct handler by source
- [ ] 3.3.5 Test wildcard subscriptions work correctly
- [ ] 3.3.6 Test multiple handlers receive same event
- [ ] 3.3.7 Test handler failure doesn't crash dispatcher
- [ ] 3.3.8 Test telemetry events are emitted
- [ ] 3.3.9 Test filtering works correctly

**Status:** PENDING - TBD - See `notes/summaries/section-3.3-dispatcher.md` for details.

---

## 3.4 Page Controller and HTML Template

Implement controller for serving the Elm SPA bootstrap HTML.

- [ ] **Task 3.4** Implement page serving infrastructure

Create the SPA serving layer:

- [ ] 3.4.1 Create lib/web_ui/controllers/page_controller.ex
- [ ] 3.4.2 Implement index/2 action for serving SPA
- [ ] 3.4.3 Create HTML template with Elm app mount point
- [ ] 3.4.4 Include compiled Elm JS in template
- [ ] 3.4.5 Include Tailwind CSS in template
- [ ] 3.4.6 Add WebSocket connection initialization
- [ ] 3.4.7 Support server-side flags/initial state
- [ ] 3.4.8 Add CSP nonce support for inline scripts
- [ ] 3.4.9 Add cache control headers
- [ ] 3.4.10 Create error page template

**Implementation Notes:**
- Template should be minimal (just a mount div)
- All UI rendered by Elm after mount
- Support multiple pages/routes via query params
- Include health check endpoint
- Pass WebSocket URL to Elm via flags
- Support server-side rendering (SSR) hooks for future
- Include meta tags for SEO
- Add viewport meta tag for responsive design

**Unit Tests for Section 3.4:**
- [ ] 3.4.1 Test index action returns HTML
- [ ] 3.4.2 Test HTML includes Elm mount point
- [ ] 3.4.3 Test HTML includes compiled JS references
- [ ] 3.4.4 Test server-side flags are passed to Elm
- [ ] 3.4.5 Test cache headers are set correctly
- [ ] 3.4.6 Test CSP nonce is included when configured
- [ ] 3.4.7 Test health check returns 200

**Status:** PENDING - TBD - See `notes/summaries/section-3.4-controller.md` for details.

---

## 3.5 Router and Routes Configuration

Implement Phoenix Router helpers and default routes.

- [ ] **Task 3.5** Implement WebUI.Router

Set up routing for the application:

- [ ] 3.5.1 Create lib/web_ui/router.ex
- [ ] 3.5.2 Define scope for WebUI routes
- [ ] 3.5.3 Add GET / for serving SPA
- [ ] 3.5.4 Add GET /health for health check
- [ ] 3.5.5 Add WebSocket route at /socket
- [ ] 3.5.6 Implement macro for defining Elm page routes
- [ ] 3.5.7 Add support for catch-all route (SPA routing)
- [ ] 3.5.8 Add pipeline for browser requests
- [ ] 3.5.9 Add pipeline for API requests
- [ ] 3.5.10 Include security middleware

**Implementation Notes:**
- Support both standalone and embedded router usage
- Provide defpage macro for Elm route definition
- Allow user application to extend routes
- Include CSRF protection
- Add rate limiting for API routes
- Support WebSocket upgrades
- Include request ID generation
- Add basic auth hooks (optional)

**Unit Tests for Section 3.5:**
- [ ] 3.5.1 Test SPA route serves HTML
- [ ] 3.5.2 Test health check returns 200
- [ ] 3.5.3 Test WebSocket route is accessible
- [ ] 3.5.4 Test catch-all route works
- [ ] 3.5.5 Test defpage macro creates correct routes
- [ ] 3.5.6 Test security middleware is applied
- [ ] 3.5.7 Test CSRF protection works

**Status:** PENDING - TBD - See `notes/summaries/section-3.5-router.md` for details.

---

## 3.6 Phase 3 Integration Tests

Verify Phoenix integration provides complete web server functionality.

- [ ] **Task 3.6** Create end-to-end Phoenix integration test suite

Test complete web functionality:

- [ ] 3.6.1 Test complete request lifecycle from HTTP to response
- [ ] 3.6.2 Test WebSocket connection and message flow
- [ ] 3.6.3 Test CloudEvent round-trip over WebSocket
- [ ] 3.6.4 Test static asset serving
- [ ] 3.6.5 Test event dispatcher routes to multiple handlers
- [ ] 3.6.6 Test security headers are present
- [ ] 3.6.7 Test concurrent connections and events
- [ ] 3.6.8 Test reconnection after disconnect

**Implementation Notes:**
- Use Phoenix.ConnTest for HTTP testing
- Use Phoenix.ChannelTest for WebSocket testing
- Simulate real client behavior
- Test under load with multiple connections
- Verify session handling
- Test error responses

**Actual Test Coverage:**
- Endpoint: 6 tests
- Channel: 8 tests
- Dispatcher: 9 tests
- Controller: 7 tests
- Router: 7 tests
- Integration: 8 tests

**Total: 45 tests** (all passing)

**Status:** PENDING - TBD - See `notes/summaries/section-3.6-integration-tests.md` for details.

---

## Success Criteria

1. **HTTP Server**: Serves SPA bootstrap HTML correctly
2. **WebSocket**: Bidirectional CloudEvents communication works
3. **Event Routing**: Events route to correct handlers
4. **Security**: All security headers and protections in place
5. **Performance**: Handles 100+ concurrent WebSocket connections

---

## Critical Files

**New Files:**
- `lib/web_ui/endpoint.ex` - Phoenix Endpoint configuration
- `lib/web_ui/channels/event_channel.ex` - WebSocket channel
- `lib/web_ui/dispatcher.ex` - Event routing system
- `lib/web_ui/controllers/page_controller.ex` - Page controller
- `lib/web_ui/router.ex` - Router configuration
- `lib/web_ui/templates/page/index.html.heex` - SPA template
- `test/web_ui/endpoint_test.exs` - Endpoint tests
- `test/web_ui/event_channel_test.exs` - Channel tests
- `test/web_ui/dispatcher_test.exs` - Dispatcher tests
- `test/web_ui/controllers/page_controller_test.exs` - Controller tests

**Dependencies:**
- `{:phoenix, "~> 1.7"}` - Required
- `{:phoenix_html, "~> 4.0"}` - Required
- `{:phoenix_live_view, "~> 1.0"}` - Required for Channel
- `{:phoenix_pubsub, "~> 2.1"}` - Required for multi-node

---

## Dependencies

**Depends on:**
- Phase 1: Project foundation and application configuration
- Phase 2: CloudEvents implementation for message format

**Phases that depend on this phase:**
- Phase 4: Elm frontend connects to WebSocket endpoint
- Phase 5: Jido integration uses event dispatcher
