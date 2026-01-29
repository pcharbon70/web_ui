# Telemetry and Monitoring Guide

WebUI emits telemetry events that can be used for monitoring, observability, and performance analysis.

## Table of Contents

1. [Overview](#overview)
2. [Available Events](#available-events)
3. [Setting Up Telemetry Handlers](#setting-up-telemetry-handlers)
4. [Metrics](#metrics)
5. [Logging](#logging)
6. [Example Integrations](#example-integrations)

---

## Overview

WebUI uses [:telemetry](https://hexdocs.pm/telemetry/) for emitting events. This allows you to:

- Track request/response performance
- Monitor WebSocket connections
- Measure event dispatch performance
- Collect custom metrics
- Integrate with observability platforms

### Telemetry Events Structure

All events follow this structure:

```elixir
[:web_ui, :component, :event_name]
```

Measurements are maps with numeric values.
Metadata are maps with contextual information.

---

## Available Events

### Dispatcher Events

#### `[:web_ui, :dispatcher, :dispatch_start]`

Emitted when an event dispatch begins.

**Measurements:**
```elixir
%{
  # No measurements (event start)
}
```

**Metadata:**
```elixir
%{
  type: String.t(),          # Event type
  handler_count: integer()   # Number of handlers
}
```

#### `[:web_ui, :dispatcher, :dispatch_complete]`

Emitted when an event dispatch completes.

**Measurements:**
```elixir
%{
  duration: integer(),       # Dispatch duration in milliseconds
  handler_count: integer(),  # Total number of handlers
  success_count: integer(),  # Successful handler calls
  error_count: integer()     # Failed handler calls
}
```

**Metadata:**
```elixir
%{
  type: String.t()           # Event type
}
```

#### `[:web_ui, :dispatcher, :handler_complete]`

Emitted when a handler completes processing.

**Measurements:**
```elixir
%{
  duration: integer(),       # Handler execution time in milliseconds
  result: atom()             # :ok, :error, :filtered
}
```

**Metadata:**
```elixir
%{
  # No additional metadata
}
```

---

## Setting Up Telemetry Handlers

### Basic Handler

```elixir
defmodule MyApp.Telemetry do
  require Logger

  def setup do
    # Attach to dispatcher events
    :telemetry.attach(
      "webui-dispatcher-handler",
      [:web_ui, :dispatcher, :dispatch_complete],
      &handle_dispatch_complete/4,
      nil
    )

    :telemetry.attach(
      "webui-handler-handler",
      [:web_ui, :dispatcher, :handler_complete],
      &handle_handler_complete/4,
      nil
    )
  end

  def handle_dispatch_complete(
        _event,
        measurements,
        metadata,
        _config
      ) do
    Logger.info("Event dispatch completed",
      type: metadata.type,
      duration: measurements.duration,
      handler_count: measurements.handler_count,
      success_count: measurements.success_count,
      error_count: measurements.error_count
    )
  end

  def handle_handler_complete(_event, measurements, _metadata, _config) do
    Logger.debug("Handler completed",
      duration: measurements.duration,
      result: measurements.result
    )
  end
end
```

### Call from Application Startup

```elixir
defmodule MyApp.Application do
  def start(_type, _args) do
    # Setup telemetry handlers
    MyApp.Telemetry.setup()

    # Start supervision tree
    children = [
      # ...
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

---

## Metrics

### Custom Metrics Module

```elixir
defmodule MyApp.Metrics do
  @moduledoc """
  Custom metrics collection for WebUI events.
  """

  use Agent

  @doc "Start the metrics collector"
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc "Get current metrics"
  def get_metrics do
    Agent.get(__MODULE__, & &1)
  end

  @doc "Reset metrics"
  def reset_metrics do
    Agent.update(__MODULE__, fn _ -> %{} end)
  end

  # Telemetry handlers

  def handle_event(
        [:web_ui, :dispatcher, :dispatch_complete],
        measurements,
        metadata,
        _config
      ) do
    Agent.update(__MODULE__, fn state ->
      key = {:dispatch, metadata.type}

      update_metric(state, key, %{
        count: 1,
        total_duration: measurements.duration,
        total_handlers: measurements.handler_count,
        total_success: measurements.success_count,
        total_errors: measurements.error_count
      })
    end)
  end

  def handle_event(
        [:web_ui, :dispatcher, :handler_complete],
        measurements,
        _metadata,
        _config
      ) do
    Agent.update(__MODULE__, fn state ->
      key = {:handler, measurements.result}

      update_metric(state, key, %{
        count: 1,
        total_duration: measurements.duration
      })
    end)
  end

  # Private helpers

  defp update_metric(state, key, updates) do
    Map.update(state, key, updates, fn existing ->
      Enum.reduce(updates, existing, fn {k, v}, acc ->
        Map.update!(acc, k, &(&1 + v))
      end)
    end)
  end
end
```

### Using Metrics

```elixir
# In IEx
iex> MyApp.Metrics.get_metrics()
%{
  {:dispatch, "com.example.event"} => %{
    count: 1250,
    total_duration: 3420,
    total_handlers: 3750,
    total_success: 3700,
    total_errors: 50
  },
  {:handler, :ok} => %{
    count: 3700,
    total_duration: 3200
  },
  {:handler, :error} => %{
    count: 50,
    total_duration: 220
  }
}
```

---

## Logging

### Structured Logging Configuration

```elixir
# config/config.exs

config :logger,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :event_type]

# config/prod.exs

config :logger,
  level: :info,
  backends: [:console, {LoggerFileBackend, :error_log}]

config :logger, :error_log,
  path: "/var/log/web_ui/error.log",
  level: :error

config :logger, :info_log,
  path: "/var/log/web_ui/info.log",
  level: :info
```

### Request Logging

```elixir
defmodule MyApp.Telemetry do
  def handle_phoenix_event(
        [:phoenix, :endpoint, :stop],
        measurements,
        metadata,
        _config
      ) do
    Logger.info("Request completed",
      request_id: Logger.metadata()[:request_id],
      method: metadata.request.method,
      path: metadata.request.path,
      status: metadata.status,
      duration: measurements.duration
    )
  end
end
```

---

## Example Integrations

### Prometheus Integration

```elixir
# mix.exs
defp deps do
  [
    {:telemetry_metrics_prometheus, "~> 1.0"}
  ]
end

# lib/my_app/telemetry.ex
defmodule MyApp.Telemetry do
  use Telemetry.Metrics

  def metrics do
    [
      # Dispatcher metrics
      last_value(
        "web_ui.dispatcher.duration",
        event_name: [:web_ui, :dispatcher, :dispatch_complete],
        measurement: :duration,
        tags: [:type]
      ),

      counter(
        "web_ui.dispatcher.count",
        event_name: [:web_ui, :dispatcher, :dispatch_complete],
        tags: [:type]
      ),

      sum(
        "web_ui.dispatcher.errors",
        event_name: [:web_ui, :dispatcher, :dispatch_complete],
        measurement: :error_count,
        tags: [:type]
      ),

      # Handler metrics
      distribution(
        "web_ui.handler.duration",
        event_name: [:web_ui, :dispatcher, :handler_complete],
        measurement: :duration,
        tags: [:result],
        buckets: [10, 25, 50, 100, 250, 500, 1000]
      )
    ]
  end
end

# lib/my_app/prometheus_endpoint.ex
defmodule MyApp.PrometheusEndpoint do
  use PromEx.Plug.Endpoint

  prom_ex_endpoint("/metrics")
end
```

### Datadog Integration

```elixir
# mix.exs
defp deps do
  [
    {:dogstatsd, "~> 1.0"}
  ]

# lib/my_app/telemetry.ex
defmodule MyApp.Telemetry do
  def setup do
    :telemetry.attach(
      "webui-datadog",
      [:web_ui, :dispatcher, :dispatch_complete],
      &handle_datadog_event/4,
      nil
    )
  end

  def handle_datadog_event(
        _event,
        measurements,
        metadata,
        _config
      ) do
    # Send metrics to Datadog
    :dogstatsd.gauge(
      "web_ui.dispatcher.duration",
      measurements.duration,
      tags: ["event_type:#{metadata.type}"]
    )

    :dogstatsd.increment(
      "web_ui.dispatcher.count",
      tags: ["event_type:#{metadata.type}"]
    )
  end
end
```

### New Relic Integration

```elixir
# mix.exs
defp deps do
  [
    {:new_relic_agent, "~> 1.0"}
  ]

# lib/my_app/telemetry.ex
defmodule MyApp.Telemetry do
  use NewRelic.Tracer

  @trace :handle_dispatch_event
  def handle_dispatch_event(
        _event,
        measurements,
        metadata,
        _config
      ) do
    NewRelic.increment_custom_metric(
      "WebUI/Dispatcher/Duration",
      measurements.duration
    )

    NewRelic.increment_custom_metric(
      "WebUI/Dispatcher/Count",
      1,
      type: metadata.type
    )
  end
end
```

---

## Dashboard Queries

### Grafana Dashboard Example

```promql
# Average dispatch duration by event type
avg by (type) (web_ui_dispatcher_duration_milliseconds)

# Dispatch error rate
sum by (type) (web_ui_dispatcher_errors_total) /
sum by (type) (web_ui_dispatcher_count_total) * 100

# Handler execution time distribution
histogram_quantile(0.95, web_ui_handler_duration_milliseconds_bucket)

# Successful vs failed handlers
sum(web_ui_handler_count_total{result="ok"}) /
sum(web_ui_handler_count_total) * 100
```

---

## Troubleshooting

### Debug Telemetry Events

```elixir
# Attach a debug handler to see all events
defmodule MyApp.DebugTelemetry do
  def setup do
    :telemetry.attach(
      "debug-handler",
      [:web_ui, :dispatcher, :dispatch_complete],
      &debug_event/4,
      nil
    )
  end

  def debug_event(event, measurements, metadata, _config) do
    IO.inspect(%{
      event: event,
      measurements: measurements,
      metadata: metadata
    }, label: "Telemetry Event")
  end
end

# In IEx
iex> MyApp.DebugTelemetry.setup()
```

### Verify Event Emission

```elixir
# Check if telemetry is working
defmodule MyApp.TestTelemetry do
  use ExUnit.Case

  test "dispatcher emits telemetry events" do
    # Attach a test handler
    handler = fn
      [:web_ui, :dispatcher, :dispatch_complete], measurements, metadata, _config ->
        send(self(), {:telemetry_event, measurements, metadata})
    end

    :telemetry.attach(
      "test-handler",
      [:web_ui, :dispatcher, :dispatch_complete],
      handler,
      nil
    )

    # Trigger event
    event = %WebUi.CloudEvent{
      specversion: "1.0",
      id: WebUi.CloudEvent.generate_id(),
      source: "/test",
      type: "test.event",
      data: %{}
    }

    WebUi.Dispatcher.dispatch(event)

    # Assert event was received
    assert_receive {:telemetry_event, measurements, metadata}
    assert is_integer(measurements.duration)
  end
end
```

---

## Additional Resources

- [Telemetry Documentation](https://hexdocs.pm/telemetry/)
- [Telemetry Metrics](https://hexdocs.pm/telemetry_metrics/)
- [Telemetry Poller](https://hexdocs.pm/telemetry_poller/)
- [Prometheus.ex](https://hexdocs.pm/prometheus_ex/)
- [DogStatsD Elixir](https://hexdocs.pm/dogstatsd/)
