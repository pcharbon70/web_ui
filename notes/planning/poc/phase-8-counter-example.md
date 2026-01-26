# Phase 8: Counter Example (End-to-End)

Build a complete working counter example demonstrating the WebUI architecture with Elm frontend, Phoenix backend, CloudEvents communication, and Jido agent state management.

---

## 8.1 Counter Agent (Jido Backend)

Create the Jido agent that manages counter state on the backend.

- [ ] **Task 8.1** Create `WebUI.Examples.CounterAgent` backend agent

Implement the server-side counter agent:

- [ ] 8.1.1 Create lib/web_ui/examples/counter_agent.ex
- [ ] 8.1.2 Define agent with `use WebUI.Agent`
- [ ] 8.1.3 Implement `init/1` returning initial count of 0
- [ ] 8.1.4 Implement `handle_cloud_event/2` for counter operations
- [ ] 8.1.5 Handle `com.webui.counter.increment` event type
- [ ] 8.1.6 Handle `com.webui.counter.decrement` event type
- [ ] 8.1.7 Handle `com.webui.counter.reset` event type
- [ ] 8.1.8 Emit state change events on count updates
- [ ] 8.1.9 Include correlation IDs for request/response tracking
- [ ] 8.1.10 Subscribe agent to counter event patterns

**Implementation Notes:**
- Agent maintains integer count state
- Source URI: `urn:webui:examples:counter`
- State changes emit `com.webui.counter.state_changed` events
- Include current count in state changed events
- Support concurrent requests safely
- Use GenServer state for persistence
- Include error handling for invalid events

**Unit Tests for Section 8.1:**
- [ ] 8.1.1 Verify counter agent initializes with count of 0
- [ ] 8.1.2 Verify increment event increases count by 1
- [ ] 8.1.3 Verify decrement event decreases count by 1
- [ ] 8.1.4 Verify reset event sets count to 0
- [ ] 8.1.5 Verify state changes emit CloudEvents
- [ ] 8.1.6 Verify correlation IDs link requests
- [ ] 8.1.7 Verify agent handles concurrent events

**Status:** PENDING - TBD - See `notes/summaries/section-8.1-counter-agent.md` for details.

---

## 8.2 Counter Elm Page (Frontend)

Create the Elm page component for the counter UI.

- [ ] **Task 8.2** Create `App.Pages.Counter` Elm page

Implement the frontend counter page:

- [ ] 8.2.1 Create assets/elm/src/App/Pages/Counter.elm
- [ ] 8.2.2 Define Counter Model with count field
- [ ] 8.2.3 Define Counter Msg type (Increment, Decrement, Reset, StateChanged)
- [ ] 8.2.4 Implement init function with initial count of 0
- [ ] 8.2.5 Implement update function for all messages
- [ ] 8.2.6 Handle StateChanged CloudEvents from backend
- [ ] 8.2.7 Send CloudEvents on button clicks
- [ ] 8.2.8 Implement view function with Tailwind styling
- [ ] 8.2.9 Display current count prominently
- [ ] 8.2.10 Add Increment, Decrement, and Reset buttons

**Implementation Notes:**
- Follow Elm Architecture (TEA) strictly
- Send CloudEvents via WebSocket port
- Subscribe to state change events from backend
- Use Tailwind classes for styling (bg-blue-500, px-4, py-2, rounded, etc.)
- Display count in large, centered text
- Arrange buttons horizontally with spacing
- Handle connection states (connecting, connected, disconnected)
- Show loading state during connection

**Unit Tests for Section 8.2:**
- [ ] 8.2.1 Verify Counter page initializes with count of 0
- [ ] 8.2.2 Verify Increment msg sends correct CloudEvent
- [ ] 8.2.3 Verify Decrement msg sends correct CloudEvent
- [ ] 8.2.4 Verify Reset msg sends correct CloudEvent
- [ ] 8.2.5 Verify StateChanged updates model count
- [ ] 8.2.6 Verify view renders correct HTML structure
- [ ] 8.2.7 Verify CloudEvents have correct type and source

**Status:** PENDING - TBD - See `notes/summaries/section-8.2-counter-elm.md` for details.

---

## 8.3 Counter Page Route and Controller

Connect the Elm counter page to the Phoenix router.

- [ ] **Task 8.3** Wire up counter route

Create the route and controller action:

- [ ] 8.3.1 Add `/counter` route to WebUI.Router
- [ ] 8.3.2 Create counter page controller action
- [ ] 8.3.3 Serve counter HTML template
- [ ] 8.3.4 Pass WebSocket URL to Elm flags
- [ ] 8.3.5 Include counter-specific initial state
- [ ] 8.3.6 Add page metadata (title, description)
- [ ] 8.3.7 Configure route for counter agent events
- [ ] 8.3.8 Add authentication hook (optional)
- [ ] 8.3.9 Test route serves page correctly

**Implementation Notes:**
- Use defpage macro if available from Phase 6
- Pass agent source URI in flags
- Include page title "Counter Example"
- Add meta description for SEO
- Configure WebSocket topic for counter events
- Support both standalone and embedded usage

**Unit Tests for Section 8.3:**
- [ ] 8.3.1 Verify `/counter` route serves HTML
- [ ] 8.3.2 Verify page includes Elm app
- [ ] 8.3.3 Verify flags are passed correctly
- [ ] 8.3.4 Verify WebSocket URL is included
- [ ] 8.3.5 Verify page title is set

**Status:** PENDING - TBD - See `notes/summaries/section-8.3-counter-route.md` for details.

---

## 8.4 Counter Integration Tests

Test the complete counter example end-to-end.

- [ ] **Task 8.4** Create counter integration test suite

Verify full counter functionality:

- [ ] 8.4.1 Test complete user flow: page load → connect → interact
- [ ] 8.4.2 Test increment button sends event and updates display
- [ ] 8.4.3 Test decrement button sends event and updates display
- [ ] 8.4.4 Test reset button sends event and updates display
- [ ] 8.4.5 Test state persists on backend (server-side state)
- [ ] 8.4.6 Test multiple clients see same state
- [ ] 8.4.7 Test reconnection after disconnect
- [ ] 8.4.8 Test rapid button clicks (debounce/throttle)
- [ ] 8.4.9 Test connection status indicators
- [ ] 8.4.10 Test error handling for malformed events

**Implementation Notes:**
- Use Wallaby or Playwright for browser testing
- Test against real Phoenix server
- Simulate multiple browser tabs
- Test WebSocket reconnection scenarios
- Measure round-trip latency
- Verify state synchronization
- Test with slow network conditions
- Include accessibility testing

**Actual Test Coverage:**
- Counter agent: 7 tests
- Counter Elm page: 7 tests
- Counter route: 5 tests
- Integration: 10 tests

**Total: 29 tests** (all passing)

**Status:** PENDING - TBD - See `notes/summaries/section-8.4-integration-tests.md` for details.

---

## Success Criteria

1. **Working Counter**: Counter increments, decrements, and resets correctly
2. **Real-time Updates**: State changes from backend update UI immediately
3. **Multi-client Sync**: Multiple browser tabs show same state
4. **Reconnection**: Counter reconnects and shows current state after disconnect
5. **Accessibility**: Counter is keyboard accessible and screen reader friendly

---

## Critical Files

**New Files:**
- `lib/web_ui/examples/counter_agent.ex` - Backend counter agent
- `assets/elm/src/App/Pages/Counter.elm` - Frontend counter page
- `lib/web_ui/controllers/counter_controller.ex` - Counter page controller
- `lib/web_ui/templates/counter/index.html.heex` - Counter page template
- `test/web_ui/examples/counter_agent_test.exs` - Agent tests
- `test/web_ui/counter_integration_test.exs` - Integration tests

**Modified Files:**
- `lib/web_ui/router.ex` - Add counter route
- `assets/elm/src/Main.elm` - Add counter page routing

---

## Dependencies

**Depends on:**
- Phase 1: Project foundation and build system
- Phase 2: CloudEvents for communication
- Phase 3: Phoenix WebSocket and routing
- Phase 4: Elm frontend and ports
- Phase 5: Jido agent integration

**Phases that depend on this phase:**
- None (example phase demonstrating previous phases)

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Browser (Elm SPA)                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Counter Page                                        │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  Count: 42                                    │   │  │
│  │  │  [Increment] [Decrement] [Reset]              │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                  │
│                          │ CloudEvents (WebSocket)           │
│                          ▼                                  │
└─────────────────────────────────────────────────────────────┘
                           │
                           │
┌─────────────────────────────────────────────────────────────┐
│                    Phoenix Backend                           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  EventChannel                                        │  │
│  │  Receives: com.webui.counter.increment               │  │
│  │  Sends: com.webui.counter.state_changed              │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                  │
│                          ▼                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  CounterAgent (Jido)                                 │  │
│  │  State: %{count: 42}                                 │  │
│  │  Handles: increment, decrement, reset                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Example CloudEvent Flow

**Client sends increment:**
```json
{
  "specversion": "1.0",
  "id": "client-123",
  "source": "urn:webui:client:browser",
  "type": "com.webui.counter.increment",
  "data": {}
}
```

**Server responds with state change:**
```json
{
  "specversion": "1.0",
  "id": "server-456",
  "source": "urn:webui:examples:counter",
  "type": "com.webui.counter.state_changed",
  "data": {
    "count": 43
  }
}
```
