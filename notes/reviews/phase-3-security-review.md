# Phase 3 Security Review: Phoenix Integration

**Date:** 2026-01-29
**Scope:** Phase 3 Phoenix Framework Integration
**Status:** Complete

## Executive Summary

Phase 3 implements a solid security foundation for WebUI with proper header-based protections, origin validation, and input validation. However, several security hardening opportunities remain before production deployment.

**Overall Security Grade:** B (Good Foundation, Hardening Recommended)

---

## 1. Security Headers Analysis

### 1.1 Implemented Headers

| Header | Status | Default Value | Notes |
|--------|--------|---------------|-------|
| X-Frame-Options | ✅ | SAMEORIGIN | Clickjacking protection |
| X-Content-Type-Options | ✅ | nosniff | MIME sniffing protection |
| X-XSS-Protection | ✅ | 1; mode=block | Legacy XSS filter |
| Content-Security-Policy | ✅ | Configurable | Environment-aware |
| Referrer-Policy | ✅ | strict-origin-when-cross-origin | Referrer control |
| Permissions-Policy | ✅ | Restrictive | Feature control |

**File:** `lib/web_ui/plugs/security_headers.ex:100-141`

### 1.2 CSP Analysis

**Development CSP:**
```elixir
"default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: ws://localhost:* wss://localhost:*; connect-src 'self' ws://localhost:* wss://localhost:;"
```

**Production CSP:**
```elixir
"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' ws: wss:; manifest-src 'self'"
```

**Concerns:**
1. `unsafe-inline` and `unsafe-eval` are necessary for Elm but increase attack surface
2. Wildcard WebSocket origins in development (acceptable)

**Recommendation:** Document CSP requirements for Elm deployment

---

## 2. WebSocket Security

### 2.1 Origin Checking

**Implementation:** `lib/web_ui/endpoint.ex:137-236`

```elixir
defp check_origin(%{origin: origin}) do
  allowed = get_allowed_origins()
  if origin_allowed?(origin, allowed) do
    :ok
  else
    :error
  end
end
```

**Status:** ✅ Implemented

**Configuration:**
```elixir
config :web_ui, WebUi.Endpoint,
  allowed_origins: ["https://example.com"]
```

**Concerns:**
1. Default behavior in production without configuration allows no origins
2. Wildcard port matching (`localhost:*`) may be overly permissive

### 2.2 CloudEvents Validation

**Implementation:** `lib/web_ui/channels/event_channel.ex:379-414`

**Validated Fields:**
- `specversion` - Must be "1.0"
- `id` - Non-empty string
- `source` - Non-empty string
- `type` - Non-empty string

**Status:** ✅ Well implemented

---

## 3. Session Security

### 3.1 Session Configuration

**File:** `lib/web_ui/endpoint.ex:69-74`

```elixir
@session_options [
  store: :cookie,
  key: "_web_ui_key",
  signing_salt: "web_ui_signing_salt",
  encryption_salt: "web_ui_encryption_salt"
]
```

**Concerns:** 🔴 Critical

1. **Hardcoded salts** - Should be configured via environment
2. **Default key name** - `_web_ui_key` is predictable

**Recommendations:**
```elixir
@session_options [
  store: :cookie,
  key: Application.compile_env(:web_ui, :session_key, "_web_ui_key"),
  signing_salt: Application.compile_env(:web_ui, :signing_salt),
  encryption_salt: Application.compile_env(:web_ui, :encryption_salt)
]
```

### 3.2 CSRF Protection

**Status:** ✅ Enabled via `protect_from_forgery` in browser pipeline

**File:** `lib/web_ui/router.ex:75-82`

```elixir
pipeline :browser do
  plug(:accepts, ["html"])
  plug(:fetch_session)
  plug(:fetch_flash)
  plug(:protect_from_forgery)
  plug(:put_secure_browser_headers)
  plug(SecurityHeaders)
end
```

---

## 4. Input Validation

### 4.1 CloudEvents Schema Validation

**Status:** ✅ Comprehensive validation

**Validates:**
- Required fields presence
- Field types (strings)
- Specversion format

**File:** `lib/web_ui/channels/event_channel.ex:393-414`

### 4.2 Router Parameter Handling

**Status:** ⚠️ No explicit validation

The catch-all route accepts any path parameter:
```elixir
Phoenix.Router.get("/*path", PageController, :index)
```

**Concern:** No validation on path parameter length or content

**Recommendation:** Add path sanitization in PageController

---

## 5. Authentication & Authorization

### 5.1 Authentication

**Status:** ❌ Not implemented (by design)

**Note:** WebUI is designed as a library; authentication is the responsibility of the host application.

**Recommendation:** Document authentication patterns for host applications

### 5.2 Channel Authorization

**Status:** ✅ Hook provided

**File:** `lib/web_ui/channels/event_channel.ex:361-369`

```elixir
defp authorize_join(topic, payload, socket) do
  case get_authorize_callback() do
    {mod, fun} ->
      apply(mod, fun, [topic, payload, socket])
    nil ->
      {:ok, socket}
  end
end
```

**Configuration:**
```elixir
config :web_ui, WebUi.EventChannel,
  authorize_join: {MyApp.Auth, :authorize_channel_join}
```

---

## 6. Rate Limiting

### 6.1 HTTP Rate Limiting

**Status:** ❌ Not implemented

**Recommendation:** Add rate limiting plug for:
- Health check endpoint
- Page requests
- API endpoints (if added)

### 6.2 WebSocket Rate Limiting

**Status:** ❌ Not implemented

**Concerns:**
1. No limit on message rate per connection
2. No limit on connection rate per IP
3. No limit on channel joins per connection

**Recommendation:** Implement rate limiting for:
- Messages per second per connection
- Connection attempts per IP
- Channel join attempts

---

## 7. Secrets Management

### 7.1 Secret Key Base

**Test Configuration:**
```elixir
# config/test.exs:7
secret_key_base: "test_secret_key_base_for_testing_only"
```

**Status:** ✅ Acceptable for test environment

**Concern:** Must verify production uses environment variables

**Recommendation:**
```elixir
# config/runtime.exs (recommended)
config :web_ui, WebUi.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE") || raise "SECRET_KEY_BASE not set"
```

### 7.2 Signing & Encryption Salts

**Status:** 🔴 Hardcoded in endpoint

**See Section 3.1 for recommendations**

---

## 8. Transport Security

### 8.1 HTTP/HTTPS

**Status:** ⚠️ HTTP only by default

**Development:**
```elixir
http: [ip: {127, 0, 0, 1}, port: 4000]
```

**Production:** Not configured in library

**Recommendation:** Document HTTPS setup for production

### 8.2 WebSocket Security (WSS)

**Status:** ⚠️ WS only by default

**Connection detection:**
```elixir
defp websocket_url(conn) do
  scheme = if conn.scheme == :https, do: "wss", else: "ws"
  # ...
end
```

**Status:** ✅ Correctly switches to WSS for HTTPS connections

---

## 9. Information Disclosure

### 9.1 Error Messages

**Status:** ✅ Generally safe

**Example:**
```elixir
# lib/web_ui/channels/event_channel.ex:434-437
push(socket, "error", %{
  reason: inspect(reason),
  message: "Invalid CloudEvent: #{inspect(reason)}"
})
```

**Concern:** `inspect(reason)` may expose internal state

**Recommendation:** Sanitize error messages for client responses

### 9.2 Server Headers

**Status:** ⚠️ Phoenix may reveal version in Server header

**Recommendation:** Configure server header in production

### 9.3 Health Check

**Status:** ✅ Minimal information disclosure

```elixir
def health(conn, _params) do
  json(conn, %{
    status: "ok",
    version: version(),
    timestamp: System.system_time(:millisecond)
  })
end
```

---

## 10. Dependency Security

### 10.1 Current Dependencies

**Key dependencies:**
- phoenix ~> 1.7
- plug ~> 1.14
- jason ~> 1.4

**Recommendation:** Run `mix deps.audit` regularly

### 10.2 Known Vulnerabilities

**Status:** Not checked in this review

**Action Item:** Run security audit before production deployment

```bash
mix deps.audit
mix sobelow
```

---

## 11. Security Recommendations Summary

### Critical Priority

1. **Configure salts via environment**
   ```elixir
   signing_salt: Application.compile_env(:web_ui, :signing_salt)
   ```

2. **Add rate limiting**
   - HTTP endpoints
   - WebSocket connections

3. **Document production secrets setup**
   - SECRET_KEY_BASE
   - Signing/encryption salts

### High Priority

1. **Add authentication guide**
   - Document patterns for host applications
   - Provide example implementations

2. **Sanitize error messages**
   - Remove `inspect(reason)` from client responses
   - Use generic error messages

3. **Add path validation**
   - Limit path parameter length
   - Sanitize special characters

### Medium Priority

1. **Document HTTPS/WSS setup**
   - SSL certificate configuration
   - Force SSL headers

2. **Add security monitoring**
   - Failed connection logging
   - Rate limit violation alerts

3. **Run dependency audits**
   - Set up automated `mix deps.audit`
   - Add `mix sobelow` to CI

### Low Priority

1. **Add security headers documentation**
   - CSP configuration guide
   - Permissions-Policy customization

2. **Add security testing**
   - Integration tests for security features
   - Penetration testing guide

---

## 12. Compliance Considerations

### OWASP Top 10 Coverage

| Risk | Status | Mitigation |
|------|--------|------------|
| A01: Broken Access Control | ⚠️ | No auth (library mode) |
| A02: Cryptographic Failures | ⚠️ | Hardcoded salts |
| A03: Injection | ✅ | Input validation |
| A04: Insecure Design | ⚠️ | No rate limiting |
| A05: Security Misconfiguration | ⚠️ | Default salts |
| A06: Vulnerable Components | ❓ | Not audited |
| A07: Auth Failures | ⚠️ | No auth (library mode) |
| A08: Data Integrity Failures | ✅ | CSP headers |
| A09: Logging Failures | ⚠️ | Basic logging |
| A10: SSRF | N/A | Not applicable |

---

## Conclusion

Phase 3 provides a solid security foundation with proper header-based protections and input validation. The main concerns are:

1. **Hardcoded secrets** (must be fixed for production)
2. **Missing rate limiting** (recommended for production)
3. **Authentication** (by design, but needs documentation)

**Recommendation:** Address critical and high priority items before production deployment.

---

**Review Date:** 2026-01-29
**Reviewer:** Security Analysis
**Next Review:** After critical fixes are implemented
