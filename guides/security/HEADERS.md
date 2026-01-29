# Security Headers Guide

WebUI includes comprehensive security headers to protect against common web vulnerabilities. This guide explains each header and how to configure it.

## Table of Contents

1. [Overview](#overview)
2. [Security Headers](#security-headers)
3. [Configuration](#configuration)
4. [Content Security Policy](#content-security-policy)
5. [Permissions Policy](#permissions-policy)
6. [Testing](#testing)

---

## Overview

WebUI's `SecurityHeaders` plug automatically adds the following security headers to all responses:

| Header | Purpose | Default |
|--------|---------|---------|
| X-Frame-Options | Prevents clickjacking | SAMEORIGIN |
| X-Content-Type-Options | Prevents MIME sniffing | nosniff |
| X-XSS-Protection | Enables XSS filtering | 1; mode=block |
| Content-Security-Policy | Controls resource loading | Environment-specific |
| Referrer-Policy | Controls referrer information | strict-origin-when-cross-origin |
| Permissions-Policy | Controls browser features | Restrictive |

---

## Security Headers

### X-Frame-Options

Prevents your site from being framed by other sites, protecting against clickjacking attacks.

**Values:**
- `DENY` - No framing allowed
- `SAMEORIGIN` - Only allow framing from same origin (default)
- `ALLOW-FROM uri` - Allow framing from specific URI

**Configuration:**
```elixir
config :web_ui, WebUi.Plugs.SecurityHeaders,
  frame_options: "SAMEORIGIN"
```

### X-Content-Type-Options

Prevents browsers from MIME-sniffing responses away from the declared content-type.

**Value:**
- `nosniff` - Prevents MIME sniffing (default, always enabled)

**No configuration needed** - this header is always applied.

### X-XSS-Protection

Enables the browser's XSS filtering. Note: Modern browsers with CSP don't require this.

**Value:**
- `1; mode=block` - Enable XSS filter and block page (default)

**Configuration:**
```elixir
config :web_ui, WebUi.Plugs.SecurityHeaders,
  enable_xss_protection: true  # default: true
```

**Note:** This header is deprecated in favor of CSP, but still provides protection for older browsers.

---

## Configuration

### Basic Configuration

```elixir
# config/config.exs

config :web_ui, WebUi.Plugs.SecurityHeaders,
  frame_options: "SAMEORIGIN",
  referrer_policy: "strict-origin-when-cross-origin",
  enable_permissions_policy: true,
  enable_xss_protection: true,
  csp: "default-src 'self'"
```

### Environment-Specific Configuration

```elixir
# config/dev.exs - More permissive for development

config :web_ui, WebUi.Plugs.SecurityHeaders,
  csp: "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: ws://localhost:* wss://localhost:*; connect-src 'self' ws://localhost:* wss://localhost:*;"

# config/prod.exs - Stricter for production

config :web_ui, WebUi.Plugs.SecurityHeaders,
  csp: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' ws: wss:; manifest-src 'self'",
  frame_options: "SAMEORIGIN",
  referrer_policy: "strict-origin-when-cross-origin",
  enable_permissions_policy: true
```

### Runtime Override

You can override security headers at runtime using the plug options:

```elixir
plug WebUi.Plugs.SecurityHeaders,
  csp: "custom-csp-directive",
  frame_options: "DENY"
```

---

## Content Security Policy (CSP)

CSP is an HTTP header that allows site operators to declare approved sources of content that browsers are allowed to load.

### Default CSP for WebUI

**Development:**
```
default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: ws://localhost:* wss://localhost:*;
connect-src 'self' ws://localhost:* wss://localhost:*;
```

**Production:**
```
default-src 'self';
script-src 'self' 'unsafe-inline' 'unsafe-eval';
style-src 'self' 'unsafe-inline';
img-src 'self' data: blob:;
font-src 'self' data:;
connect-src 'self' ws: wss:;
manifest-src 'self'
```

### CSP Directives

| Directive | Purpose | Elm SPA Requirements |
|-----------|---------|---------------------|
| default-src | Default policy for all content types | `'self'` |
| script-src | Valid script sources | `'self' 'unsafe-inline' 'unsafe-eval'` |
| style-src | Valid style sources | `'self' 'unsafe-inline'` |
| img-src | Valid image sources | `'self' data: blob:` |
| font-src | Valid font sources | `'self' data:` |
| connect-src | Valid fetch/websocket targets | `'self' ws: wss:` |

**Note:** Elm requires `'unsafe-inline'` and `'unsafe-eval'` for script-src. This is a known limitation of Elm's architecture.

### CSP Nonce Usage

For stricter CSP, you can use nonces instead of `'unsafe-inline'`:

```elixir
# In your controller
def index(conn, params) do
  nonce = generate_csp_nonce()
  # Use nonce in your CSP header
  csp = "script-src 'self' 'nonce-#{nonce}'"
  # Pass nonce to template
  render(conn, :index, nonce: nonce)
end
```

### CSP Reporting

Enable CSP violation reporting:

```elixir
# config/prod.exs

config :web_ui, WebUi.Plugs.SecurityHeaders,
  csp: "default-src 'self'; report-uri /csp-violation-report-endpoint"
```

Handle violation reports:

```elixir
defmodule MyApp.CSPReportController do
  use MyApp.Web, :controller

  def create(conn, params) do
    # Log CSP violation
    Logger.warning("CSP violation",
      csp_report: params["csp-report"],
      remote_ip: inspect(conn.remote_ip)
    )

    send_resp(conn, 204, "")
  end
end

# In router
post "/csp-violation-report-endpoint", CSPReportController, :create
```

---

## Permissions Policy

Permissions Policy (formerly Feature Policy) allows you to control which browser features can be used.

### Default Permissions Policy

```elixir
"geolocation=(), microphone=(), camera=(), payment=(), usb=()"
```

This disables:
- Geolocation access
- Microphone access
- Camera access
- Payment Request API
- USB device access

### Enabling Features

To enable specific features:

```elixir
# config/prod.exs

config :web_ui, WebUi.Plugs.SecurityHeaders,
  enable_permissions_policy: true  # Must be enabled first

# Then set a custom policy via plug
plug WebUi.Plugs.SecurityHeaders,
  permissions_policy: "geolocation=self, camera=()"
```

### Available Features

| Feature | Description |
|---------|-------------|
| geolocation | Geolocation API |
| microphone | Microphone access |
| camera | Camera access |
| payment | Payment Request API |
| usb | WebUSB API |
| magnetometer | Magnetometer API |
| gyroscope | Gyroscope API |
| accelerometer | Accelerometer API |
| ambient-light-sensor | Ambient Light Sensor API |
| autoplay | Autoplay policy |
| encrypted-media | Encrypted Media Extensions |
| fullscreen | Fullscreen API |
| picture-in-picture | Picture-in-Picture API |

---

## Referrer Policy

Controls how much referrer information is sent with navigation requests.

### Available Values

| Value | Description |
|-------|-------------|
| no-referrer | No referrer information |
| no-referrer-when-downgrade | Full URL for same-origin, none for HTTPS→HTTP |
| origin | Only send origin |
| origin-when-cross-origin | Full URL for same-origin, origin for cross-origin |
| same-origin | Full URL for same-origin, none for cross-origin |
| strict-origin | Origin only, no URL for HTTPS→HTTP |
| **strict-origin-when-cross-origin** (default) | Origin for cross-origin, full URL for same-origin |
| unsafe-url | Full URL always |

**Configuration:**
```elixir
config :web_ui, WebUi.Plugs.SecurityHeaders,
  referrer_policy: "strict-origin-when-cross-origin"
```

---

## Testing

### Verify Headers with curl

```bash
# Check all security headers
curl -I https://yourapp.com/

# Should see:
# X-Frame-Options: SAMEORIGIN
# X-Content-Type-Options: nosniff
# X-XSS-Protection: 1; mode=block
# Content-Security-Policy: ...
# Referrer-Policy: strict-origin-when-cross-origin
# Permissions-Policy: ...
```

### Verify Headers in Browser

```javascript
// In browser console
fetch(window.location.href)
  .then(response => {
    const headers = {}
    response.headers.forEach((value, key) => {
      if (key.includes('x-') || key === 'content-security-policy' ||
          key === 'referrer-policy' || key === 'permissions-policy') {
        headers[key] = value
      }
    })
    console.log('Security Headers:', headers)
  })
```

### Test CSP with CSP Evaluator

1. Visit [CSP Evaluator](https://csp-evaluator.withgoogle.com/)
2. Enter your CSP header
3. Review recommendations

### Security Header Scanners

- [Security Headers](https://securityheaders.com/)
- [Mozilla Observatory](https://observatory.mozilla.org/)
- [Webbkoll](https://webbkoll.dataskydd.net/)

---

## Troubleshooting

### Common CSP Issues

**Issue:** Resources blocked by CSP

**Solution:** Add the source to the appropriate directive:
```elixir
# To load from CDN
csp: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.example.com"
```

**Issue:** Inline event handlers blocked

**Solution:** Avoid inline handlers or use nonces:
```html
<!-- Bad: blocked by CSP -->
<button onclick="doSomething()">Click</button>

<!-- Good: use event listeners -->
<button data-action="doSomething">Click</button>
```

**Issue:** WebSockets blocked

**Solution:** Add websocket sources to connect-src:
```elixir
csp: "connect-src 'self' wss://example.com"
```

### Frame Options Issues

**Issue:** Content won't load in iframe

**Solution:** Adjust frame options or use CSP frame-ancestors:
```elixir
# Allow framing from specific origin
config :web_ui, WebUi.Plugs.SecurityHeaders,
  frame_options: "ALLOW-FROM https://trusted-site.com"

# Or use CSP (more flexible)
csp: "frame-ancestors 'self' https://trusted-site.com"
```

---

## Best Practices

1. **Always use HTTPS in production** - Required for many security features
2. **Start with restrictive defaults** - Only open up what's necessary
3. **Use CSP reporting** - Get notified of violations before enforcing
4. **Test in dev mode first** - Ensure your app works with stricter headers
5. **Review headers regularly** - Security best practices evolve
6. **Use report-only mode** - Test CSP without breaking your site:
   ```elixir
   csp: "Content-Security-Policy-Report-Only: ..."
   ```

---

## Additional Resources

- [OWASP Secure Headers](https://owasp.org/www-project-secure-headers/)
- [Content Security Policy Level 3](https://w3c.github.io/webappsec-csp/)
- [Permissions Policy](https://w3c.github.io/webappsec-permissions-policy/)
- [MDN Web Security](https://developer.mozilla.org/en-US/docs/Web/Security)
