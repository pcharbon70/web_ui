# Production Deployment Guide

This guide covers deploying WebUI to production environments.

## Table of Contents

1. [Environment Variables](#environment-variables)
2. [SSL/TLS Configuration](#ssltls-configuration)
3. [Session Security](#session-security)
4. [Reverse Proxy Setup](#reverse-proxy-setup)
5. [Monitoring and Logging](#monitoring-and-logging)
6. [Deployment Checklist](#deployment-checklist)

---

## Environment Variables

### Required Variables

The following environment variables MUST be set for production:

```bash
# Phoenix Secret Key Base (required)
# Generate with: openssl rand -base64 64
SECRET_KEY_BASE="your_secret_key_base_here"

# Session Security (required)
# Generate with: openssl rand -base64 48
WEB_UI_SIGNING_SALT="your_signing_salt_here"
WEB_UI_ENCRYPTION_SALT="your_encryption_salt_here"
```

### Optional Variables

```bash
# Session Configuration
WEB_UI_SESSION_KEY="_web_ui_key"  # Override default session cookie name

# Server Configuration
PORT=4000                    # HTTP port
HOST=example.com             # Your domain name
SCHEME=http                  # or https

# WebSocket Configuration
ALLOWED_ORIGINS="https://example.com,https://www.example.com"

# SSL/TLS Configuration
SSL_KEY_PATH=/path/to/ssl/key.pem
SSL_CERT_PATH=/path/to/ssl/cert.pem
SSL_CA_PATH=/path/to/ssl/ca.pem  # Optional
```

---

## SSL/TLS Configuration

### Using Let's Encrypt

1. **Install certbot:**

```bash
sudo apt-get install certbot
```

2. **Generate certificates:**

```bash
sudo certbot certonly --webroot -w /var/www/html -d example.com -d www.example.com
```

3. **Configure environment variables:**

```bash
export SSL_KEY_PATH="/etc/letsencrypt/live/example.com/privkey.pem"
export SSL_CERT_PATH="/etc/letsencrypt/live/example.com/fullchain.pem"
```

### Self-Signed Certificates (Development)

For development or internal deployments:

```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
```

### Configuration in prod.exs

```elixir
# config/prod.exs

config :web_ui, WebUi.Endpoint,
  https: [
    port: 443,
    cipher_suite: :strong,
    keyfile: System.get_env("SSL_KEY_PATH"),
    certfile: System.get_env("SSL_CERT_PATH"),
    cacertfile: System.get_env("SSL_CA_PATH") # Optional
  ],
  force_ssl: [hsts: true]
```

### HSTS Configuration

HTTP Strict Transport Security (HSTS) is enabled by default in production.

To customize:

```elixir
config :web_ui, WebUi.Endpoint,
  force_ssl: [
    hsts: true,
    max_age: 31_536_000,  # 1 year in seconds
    subdomains: false,
    preload: true  # Submit to HSTS preload list
  ]
```

---

## Session Security

### Generate Secure Salts

Use OpenSSL to generate secure random salts:

```bash
# Generate signing salt
openssl rand -base64 48

# Generate encryption salt
openssl rand -base64 48

# Generate secret key base
openssl rand -base64 64
```

### Set Environment Variables

```bash
export WEB_UI_SIGNING_SALT="$(openssl rand -base64 48)"
export WEB_UI_ENCRYPTION_SALT="$(openssl rand -base64 48)"
export SECRET_KEY_BASE="$(openssl rand -base64 64)"
```

### Verification

Verify your salts are set:

```bash
# In iex
iex> Application.get_env(:web_ui, :signing_salt)
"your_signing_salt_here"

iex> Application.get_env(:web_ui, :encryption_salt)
"your_encryption_salt_here"
```

---

## Reverse Proxy Setup

### Nginx Configuration

```nginx
# /etc/nginx/sites-available/webui

upstream webui {
    server localhost:4000;
}

server {
    listen 80;
    server_name example.com;

    # Redirect all HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.com;

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Logging
    access_log /var/log/nginx/webui_access.log;
    error_log /var/log/nginx/webui_error.log;

    # Proxy settings
    location / {
        proxy_pass http://webui;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Static files (optional, for better performance)
    location /assets/ {
        alias /path/to/app/priv/static/web_ui/assets/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

### Apache Configuration

```apache
# /etc/apache2/sites-available/webui.conf

<VirtualHost *:80>
    ServerName example.com
    Redirect permanent / https://example.com/
</VirtualHost>

<VirtualHost *:443>
    ServerName example.com

    # SSL certificates
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/example.com/privkey.pem

    # Proxy settings
    ProxyPreserveHost On
    ProxyRequests Off

    # WebSocket support
    ProxyPass /socket/websocket ws://localhost:4000/socket/websocket
    ProxyPassReverse /socket/websocket ws://localhost:4000/socket/websocket

    # HTTP proxy
    ProxyPass / http://localhost:4000/
    ProxyPassReverse / http://localhost:4000/

    # Headers
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-For "%{REMOTE_ADDR}s"
</VirtualHost>
```

---

## Monitoring and Logging

### Health Check Endpoint

WebUI provides a health check endpoint at `/health`:

```bash
curl https://example.com/health
# Response: {"status":"ok","version":"0.1.0","timestamp":1234567890}
```

### Structured Logging

Configure logging for production:

```elixir
# config/prod.exs

config :logger,
  level: :info,
  backends: [:console, {LoggerJSONFile, :log}],
  json_encoder: Jason

config :logger, :log,
  path: "/var/log/web_ui/app.log",
  rotate: %{max_bytes: 100_000_000, keep: 10}
```

### Metrics

Enable Telemetry metrics:

```elixir
# In your application

defmodule MyApp.Telemetry do
  def setup do
    # Attach reporters
    :telemetry.attach(
      "webui-metrics",
      [:web_ui, :dispatcher, :dispatch_complete],
      &handle_event/4,
      nil
    )
  end

  def handle_event(event, measurements, metadata, config) do
    # Send to your metrics system (Prometheus, Datadog, etc.)
  end
end
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] Generate and set `SECRET_KEY_BASE`
- [ ] Generate and set `WEB_UI_SIGNING_SALT`
- [ ] Generate and set `WEB_UI_ENCRYPTION_SALT`
- [ ] Set `ALLOWED_ORIGINS` for WebSocket
- [ ] Configure SSL certificates
- [ ] Test SSL configuration (use SSL Labs test)
- [ ] Configure reverse proxy
- [ ] Set up logging
- [ ] Set up monitoring

### Post-Deployment

- [ ] Verify health endpoint responds
- [ ] Test WebSocket connections
- [ ] Verify security headers are present
- [ ] Test SSL/TLS configuration
- [ ] Check CSP headers
- [ ] Verify static assets are served
- [ ] Test error handling
- [ ] Load test the application

### Security Verification

```bash
# Check security headers
curl -I https://example.com/

# Should include:
# - X-Frame-Options: SAMEORIGIN
# - X-Content-Type-Options: nosniff
# - Content-Security-Policy: ...
# - Referrer-Policy: strict-origin-when-cross-origin
# - Strict-Transport-Security: ... (if HTTPS)

# Test SSL configuration
# Use: https://www.ssllabs.com/ssltest/

# Check for common vulnerabilities
mix sobelow --skip
```

---

## Troubleshooting

### WebSocket Connection Issues

1. **Check reverse proxy configuration** supports WebSocket upgrade
2. **Verify `ALLOWED_ORIGINS`** includes your domain
3. **Check firewall rules** allow WebSocket connections

### Session Issues

1. **Verify salts are set** in environment variables
2. **Check cookie domain** matches your application URL
3. **Verify `secret_key_base`** is consistent across restarts

### SSL Certificate Issues

1. **Verify certificate paths** are correct
2. **Check file permissions** on certificate files
3. **Verify certificate chain** is complete

---

## Additional Resources

- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [OWASP SSL/TLS Cheatsheet](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Protection_Cheat_Sheet.html)
