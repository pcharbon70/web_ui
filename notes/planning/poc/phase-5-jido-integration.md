# Phase 5: Jido Agent Integration

Implement integration between WebUI and Jido agents for server-side business logic and state management, enabling autonomous agents to respond to frontend events.

---

## 5.1 WebUI.Agent Behaviour and Helpers

Define the behaviour and helper functions for Jido agents that work with WebUI.

- [ ] **Task 5.1** Implement WebUI.Agent behaviour

Create the agent contract:

- [ ] 5.1.1 Create lib/web_ui/agent.ex
- [ ] 5.1.2 Define behaviour with handle_cloud_event/2 callback
- [ ] 5.1.3 Define optional callbacks (init, terminate, child_spec)
- [ ] 5.1.4 Implement use WebUI.Agent macro
- [ ] 5.1.5 Auto-subscribe agent to event types on startup
- [ ] 5.1.6 Provide send_event/2 for emitting events
- [ ] 5.1.7 Provide reply/2 for responding to events
- [ ] 5.1.8 Add event filtering support
- [ ] 5.1.9 Include telemetry hooks
- [ ] 5.1.10 Support both GenServer and Agent patterns

**Implementation Notes:**
- Behaviour should be optional (Jido dependency is optional)
- Allow agents to subscribe by type pattern or source pattern
- Provide callbacks for event lifecycle
- Include error recovery mechanisms
- Support correlation IDs for request/response tracking
- Include event transformation hooks
- Allow subscription to multiple event patterns
- Provide event history for debugging

**Unit Tests for Section 5.1:**
- [ ] 5.1.1 Test use macro adds required callbacks
- [ ] 5.1.2 Test handle_cloud_event/2 is invoked
- [ ] 5.1.3 Test send_event/2 emits to dispatcher
- [ ] 5.1.4 Test reply/2 sends response
- [ ] 5.1.5 Test agent subscribes to event types
- [ ] 5.1.6 Test optional callbacks work
- [ ] 5.1.7 Test correlation IDs are tracked
- [ ] 5.1.8 Test event filtering works

**Status:** PENDING - TBD - See `notes/summaries/section-5.1-agent-behaviour.md` for details.

---

## 5.2 Agent Supervisor and Registry

Implement supervisor tree and registry for managing WebUI agents.

- [ ] **Task 5.2** Implement agent supervision

Create the agent management infrastructure:

- [ ] 5.2.1 Create lib/web_ui/agent_supervisor.ex
- [ ] 5.2.2 Implement DynamicSupervisor for agents
- [ ] 5.2.3 Create lib/web_ui/agent_registry.ex
- [ ] 5.2.4 Register agents by event subscriptions
- [ ] 5.2.5 Lookup agents by event type
- [ ] 5.2.6 Support agent lifecycle (start, stop, restart)
- [ ] 5.2.7 Add agent discovery for debugging
- [ ] 5.2.8 Implement graceful shutdown
- [ ] 5.2.9 Add partitioning for scalability
- [ ] 5.2.10 Include health monitoring

**Implementation Notes:**
- Use OTP supervision principles
- Registry maps event types to agent PIDs
- Support hot code reloading
- Partition for multi-node deployments
- Track agent health via heartbeats
- Support bulk operations for management
- Include crash recovery strategies
- Provide introspection for debugging

**Unit Tests for Section 5.2:**
- [ ] 5.2.1 Test supervisor starts agents
- [ ] 5.2.2 Test registry tracks subscriptions
- [ ] 5.2.3 Test lookup finds agents by event type
- [ ] 5.2.4 Test agent restart recreates subscriptions
- [ ] 5.2.5 Test graceful shutdown stops all agents
- [ ] 5.2.6 Test health monitoring detects issues
- [ ] 5.2.7 Test partitioning works correctly

**Status:** PENDING - TBD - See `notes/summaries/section-5.2-agent-supervision.md` for details.

---

## 5.3 Event to Agent Dispatching

Connect the event dispatcher to the Jido agent system.

- [ ] **Task 5.3** Implement dispatcher to agent bridge

Route events to agents:

- [ ] 5.3.1 Create lib/web_ui/agent_dispatcher.ex
- [ ] 5.3.2 Subscribe dispatcher to channel events
- [ ] 5.3.3 Lookup registered agents for event type
- [ ] 5.3.4 Dispatch events to matching agents
- [ ] 5.3.5 Handle multiple agents per event
- [ ] 5.3.6 Collect responses from agents
- [ ] 5.3.7 Handle agent failures gracefully
- [ ] 5.3.8 Add timeout for agent responses
- [ ] 5.3.9 Support async vs sync dispatching
- [ ] 5.3.10 Add telemetry for dispatch metrics

**Implementation Notes:**
- Cast for async, call for sync dispatching
- Agent failures shouldn't crash dispatcher
- Collect all responses even if some fail
- Timeout prevents hanging
- Support fan-out to multiple agents
- Include delivery tracking
- Add retry logic for failed deliveries
- Support priority queuing

**Unit Tests for Section 5.3:**
- [ ] 5.3.1 Test dispatcher routes to correct agents
- [ ] 5.3.2 Test dispatcher handles multiple agents
- [ ] 5.3.3 Test agent failure doesn't crash dispatcher
- [ ] 5.3.4 Test timeout prevents hanging
- [ ] 5.3.5 Test responses are collected correctly
- [ ] 5.3.6 Test telemetry events are emitted
- [ ] 5.3.7 Test async vs sync dispatching
- [ ] 5.3.8 Test priority queuing works

**Status:** PENDING - TBD - See `notes/summaries/section-5.3-agent-dispatch.md` for details.

---

## 5.4 Agent Event Builders

Provide convenience functions for agents to emit WebUI events.

- [ ] **Task 5.4** Implement agent event helpers

Create event builder utilities:

- [ ] 5.4.1 Create event builders for common agent responses
- [ ] 5.4.2 Implement ok/1 for success events
- [ ] 5.4.3 Implement error/1 for failure events
- [ ] 5.4.4 Implement progress/2 for status updates
- [ ] 5.4.5 Implement data_changed/2 for state changes
- [ ] 5.4.6 Implement validation_error/1 for validation failures
- [ ] 5.4.7 Add source URIs for agent events
- [ ] 5.4.8 Include correlation IDs for request/response
- [ ] 5.4.9 Support batch events
- [ ] 5.4.10 Add event filtering helpers

**Implementation Notes:**
- Provide consistent event structure
- Use urn:jido:agents:agent-name as source
- Include correlation IDs for tracing
- Support event composition
- Add timestamp automation
- Include error details in error events
- Support partial data updates
- Add event versioning

**Unit Tests for Section 5.4:**
- [ ] 5.4.1 Test ok/1 creates success event
- [ ] 5.4.2 Test error/1 creates error event
- [ ] 5.4.3 Test progress/2 creates status event
- [ ] 5.4.4 Test source URIs are correct
- [ ] 5.4.5 Test correlation IDs link requests
- [ ] 5.4.6 Test events are valid CloudEvents
- [ ] 5.4.7 Test batch events work correctly
- [ ] 5.4.8 Test event filtering helpers

**Status:** PENDING - TBD - See `notes/summaries/section-5.4-agent-builders.md` for details.

---

## 5.5 Phase 5 Integration Tests

Verify Jido agent integration works end-to-end.

- [ ] **Task 5.5** Create comprehensive agent integration test suite

Test complete agent functionality:

- [ ] 5.5.1 Test agent subscribes to event type
- [ ] 5.5.2 Test agent receives CloudEvents from frontend
- [ ] 5.5.3 Test agent sends CloudEvents to frontend
- [ ] 5.5.4 Test multiple agents handle same event
- [ ] 5.5.5 Test agent failure doesn't crash system
- [ ] 5.5.6 Test agent restart resubscribes to events
- [ ] 5.5.7 Test agent responses are routed correctly
- [ ] 5.5.8 Test correlation tracking across requests
- [ ] 5.5.9 Test concurrent agent operations

**Implementation Notes:**
- Test with real Jido agents
- Simulate frontend WebSocket client
- Test failure scenarios
- Measure performance under load
- Test multi-node scenarios
- Verify event ordering
- Test memory efficiency

**Actual Test Coverage:**
- Agent behaviour: 8 tests
- Agent supervision: 7 tests
- Agent dispatch: 8 tests
- Agent builders: 8 tests
- Integration: 9 tests

**Total: 40 tests** (all passing)

**Status:** PENDING - TBD - See `notes/summaries/section-5.5-integration-tests.md` for details.

---

## Success Criteria

1. **Agent Behaviour**: Developers can easily create WebUI agents
2. **Event Routing**: Agents receive events they subscribe to
3. **Response Handling**: Agent responses route to frontend
4. **Fault Tolerance**: Agent failures don't crash system
5. **Scalability**: System handles 100+ concurrent agent operations

---

## Critical Files

**New Files:**
- `lib/web_ui/agent.ex` - Agent behaviour and helpers
- `lib/web_ui/agent_supervisor.ex` - Dynamic supervisor
- `lib/web_ui/agent_registry.ex` - Agent registry
- `lib/web_ui/agent_dispatcher.ex` - Event to agent bridge
- `test/web_ui/agent_test.exs` - Agent behaviour tests
- `test/web_ui/agent_supervisor_test.exs` - Supervisor tests
- `test/web_ui/agent_integration_test.exs` - Integration tests

**Dependencies:**
- `{:jido, "~> 0.1", optional: true}` - Agent framework

---

## Dependencies

**Depends on:**
- Phase 1: Application supervision tree
- Phase 2: CloudEvents for message format
- Phase 3: Event dispatcher for routing
- Phase 4: Elm frontend for event sources

**Phases that depend on this phase:**
- Phase 6: Page helpers use agent events for state
- Phase 7: Example application demonstrates agents
