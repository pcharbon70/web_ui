# Feature: Rate Limiting for HTTP and WebSocket

**Branch:** `feature/rate-limiting`
**Date:** 2026-01-29
**Status:** Complete

## Overview

Implement rate limiting for HTTP requests and WebSocket connections to protect against abuse and ensure fair resource allocation.

## Requirements

1. **HTTP Rate Limiting**
   - ETS-based storage for rate limit tracking
   - IP-based limiting with configurable windows
   - Configurable limits per endpoint
   - Graceful handling of rate limit violations

2. **WebSocket Rate Limiting**
   - Per-connection message rate tracking
   - Configurable limits via Application config
   - Disconnect clients exceeding limits
   - Log rate limit violations

## Design

### HTTP Rate Limiting

**Module:** `WebUi.Plugs.RateLimit`

**Configuration:**
```elixir
config :web_ui, WebUi.Plugs.RateLimit,
  enabled: true,
  storage: WebUi.Plugs.RateLimit.ETSStorage,
  default_limits: [
    {100, 60_000}  # 100 requests per 60 seconds
  ],
  cleanup_interval: 60_000
```

**API:**
```elixir
# In router
plug WebUi.Plugs.RateLimit,
  name: :api,
  limits: [{100, 60_000}, {1000, 300_000}]  # Sliding window

# Custom limits per endpoint
plug WebUi.Plugs.RateLimit,
  name: :strict_api,
  limits: [{10, 60_000}]  # 10 requests per minute
```

**Response Headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1706534400
```

### WebSocket Rate Limiting

**Location:** `WebUi.EventChannel`

**Configuration:**
```elixir
config :web_ui, WebUi.EventChannel,
  rate_limit: [
    enabled: true,
    max_messages: 60,      # 60 messages
    window: 60_000         # per 60 seconds
  ]
```

**Behavior:**
- Track messages per connection
- Disconnect clients exceeding limit
- Log violations

---

## Task List

### Task 1: Create ETS Storage Module

**Status:** Pending

**Module:** `WebUi.Plugs.RateLimit.ETSStorage`

**Responsibilities:**
- Manage ETS table for rate limit tracking
- Cleanup expired entries
- Thread-safe operations

**Functions:**
- `start_link/1` - Start the storage GenServer
- `check_rate_limit/3` - Check if request is within limits
- `record_request/2` - Record a request
- `cleanup/1` - Remove expired entries

---

### Task 2: Create Rate Limit Plug

**Status:** Pending

**Module:** `WebUi.Plugs.RateLimit`

**Responsibilities:**
- Plug interface for HTTP rate limiting
- Extract client identifier (IP)
- Check rate limits
- Add rate limit headers to response

**API:**
```elixir
def init(opts)
def call(conn, opts)
```

---

### Task 3: Add WebSocket Rate Limiting

**Status:** Pending

**Module:** `WebUi.EventChannel` (modify)

**Changes:**
- Track message timestamps per socket
- Check rate before handling message
- Disconnect if rate exceeded
- Log violations

---

### Task 4: Add Tests

**Status:** Pending

**Test Files:**
- `test/web_ui/plugs/rate_limit_test.exs`
- `test/web_ui/plugs/rate_limit/ets_storage_test.exs`
- Update `test/web_ui/channels/event_channel_test.exs`

**Test Cases:**
- ETS storage operations
- Rate limit enforcement
- Sliding window behavior
- Cleanup of expired entries
- WebSocket message rate limiting

---

### Task 5: Update Configuration

**Status:** Pending

**Files to modify:**
- `config/config.exs` - Add default configuration
- `config/dev.exs` - Add dev configuration
- `config/prod.exs` - Add prod configuration
- `config/test.exs` - Add test configuration

---

### Task 6: Update Documentation

**Status:** Pending

**Files to create:**
- Update working plan with implementation notes

**Files to modify:**
- Update relevant guides if needed

---

## Progress Tracking

| Task | Status | Notes |
|------|--------|-------|
| 1: Create ETS Storage Module | Complete | Implemented as nested module in RateLimit |
| 2: Create Rate Limit Plug | Complete | Full plug interface with headers |
| 3: Add WebSocket Rate Limiting | Complete | Added to EventChannel |
| 4: Add Tests | Complete | 19 tests, all passing |
| 5: Update Configuration | Complete | Added to config.exs and test.exs |
| 6: Update Documentation | Complete | Summary written to notes/summaries/ |

---

## Questions for Developer

*No questions yet. Will update as needed.*
