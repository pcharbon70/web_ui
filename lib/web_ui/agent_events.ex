defmodule WebUI.AgentEvents do
  @moduledoc """
  Convenience functions for agents to emit WebUI events.

  This module provides builder functions for common agent response events
  with consistent structure, source URIs, and correlation IDs.

  ## Event Type Naming Convention

  Events follow the pattern: `com.webui.agent.{agent_name}.{event_type}`

  Examples:
  * `com.webui.agent.calculator.ok` - Successful operation
  * `com.webui.agent.calculator.error` - Failed operation
  * `com.webui.agent.calculator.progress` - Progress update
  * `com.webui.agent.calculator.data_changed` - State change

  ## Source URI Convention

  Agent events use URN format: `urn:jido:agents:{agent_name}`

  Examples:
  * `urn:jido:agents:calculator`
  * `urn:jido:agents:workflow-manager`

  ## Correlation IDs

  When handling an incoming event, agents can preserve the correlation ID
  for request/response tracking:

      # In handle_cloud_event/2
      response_event = WebUI.AgentEvents.ok(
        agent_name: "my-agent",
        data: %{result: 42},
        correlation_id: event.id
      )

  ## Examples

  Create a success event:

      event = WebUI.AgentEvents.ok(
        agent_name: "calculator",
        data: %{result: 42}
      )

  Create an error event:

      event = WebUI.AgentEvents.error(
        agent_name: "validator",
        data: %{message: "Invalid input", errors: ["email required"]}
      )

  Create a progress event:

      event = WebUI.AgentEvents.progress(
        agent_name: "importer",
        current: 50,
        total: 100,
        message: "Processing..."
      )

  Create a data changed event:

      event = WebUI.AgentEvents.data_changed(
        agent_name: "user-manager",
        entity_type: "user",
        entity_id: "123",
        data: %{status: "active"}
      )

  Create a validation error event:

      event = WebUI.AgentEvents.validation_error(
        agent_name: "form-validator",
        errors: [%{field: "email", message: "Invalid format"}]
      )

  Create a batch of events:

      events = WebUI.AgentEvents.batch([
        WebUI.AgentEvents.ok(agent_name: "worker-1", data: %{task: "done"}),
        WebUI.AgentEvents.ok(agent_name: "worker-2", data: %{task: "done"})
      ])

  """

  alias WebUi.CloudEvent

  @type agent_name :: String.t() | atom()
  @type event_data :: map()
  @type event_opts :: keyword()

  @doc """
  Creates a success event for an agent.

  ## Options

  * `:agent_name` - Required. The name of the agent
  * `:data` - Required. The event data payload
  * `:correlation_id` - Optional. Correlation ID for request/response tracking
  * `:subject` - Optional. Subject of the event
  * `:extensions` - Optional. Additional custom attributes

  ## Examples

      event = WebUI.AgentEvents.ok(
        agent_name: "calculator",
        data: %{result: 42}
      )

      event = WebUI.AgentEvents.ok(
        agent_name: "processor",
        data: %{count: 10},
        correlation_id: "req-123"
      )

  """
  @spec ok([agent_name: agent_name(), data: event_data()] | event_opts()) :: CloudEvent.t()
  def ok(opts) when is_list(opts) do
    agent_name = Keyword.fetch!(opts, :agent_name)
    data = Keyword.fetch!(opts, :data)
    correlation_id = Keyword.get(opts, :correlation_id)

    base_opts = [
      source: build_source(agent_name),
      type: build_type(agent_name, "ok"),
      data: data,
      time: DateTime.utc_now()
    ]

    base_opts
    |> maybe_put_correlation_id(correlation_id)
    |> maybe_put_subject(Keyword.get(opts, :subject))
    |> maybe_put_extensions(Keyword.get(opts, :extensions))
    |> CloudEvent.new!()
  end

  @doc """
  Creates an error event for an agent.

  ## Options

  * `:agent_name` - Required. The name of the agent
  * `:data` - Required. The error data (should include error details)
  * `:correlation_id` - Optional. Correlation ID for request/response tracking
  * `:subject` - Optional. Subject of the event
  * `:extensions` - Optional. Additional custom attributes

  ## Examples

      event = WebUI.AgentEvents.error(
        agent_name: "calculator",
        data: %{message: "Division by zero", code: "div_zero"}
      )

  """
  @spec error([agent_name: agent_name(), data: event_data()] | event_opts()) :: CloudEvent.t()
  def error(opts) when is_list(opts) do
    agent_name = Keyword.fetch!(opts, :agent_name)
    data = Keyword.fetch!(opts, :data)
    correlation_id = Keyword.get(opts, :correlation_id)

    base_opts = [
      source: build_source(agent_name),
      type: build_type(agent_name, "error"),
      data: data,
      time: DateTime.utc_now()
    ]

    base_opts
    |> maybe_put_correlation_id(correlation_id)
    |> maybe_put_subject(Keyword.get(opts, :subject))
    |> maybe_put_extensions(Keyword.get(opts, :extensions))
    |> CloudEvent.new!()
  end

  @doc """
  Creates a progress event for an agent.

  ## Options

  * `:agent_name` - Required. The name of the agent
  * `:current` - Required. Current progress value
  * `:total` - Required. Total progress value
  * `:message` - Optional. Progress message
  * `:correlation_id` - Optional. Correlation ID for request/response tracking
  * `:subject` - Optional. Subject of the event
  * `:extensions` - Optional. Additional custom attributes

  ## Examples

      event = WebUI.AgentEvents.progress(
        agent_name: "importer",
        current: 50,
        total: 100,
        message: "Processing..."
      )

  """
  @spec progress([agent_name: agent_name(), current: number(), total: number()] | event_opts()) ::
          CloudEvent.t()
  def progress(opts) when is_list(opts) do
    agent_name = Keyword.fetch!(opts, :agent_name)
    current = Keyword.fetch!(opts, :current)
    total = Keyword.fetch!(opts, :total)

    data =
      case Keyword.get(opts, :data) do
        nil -> %{current: current, total: total, percent: calculate_percent(current, total)}
        extra_data -> Map.merge(extra_data, %{current: current, total: total, percent: calculate_percent(current, total)})
      end
      |> maybe_put_message(Keyword.get(opts, :message))

    correlation_id = Keyword.get(opts, :correlation_id)

    base_opts = [
      source: build_source(agent_name),
      type: build_type(agent_name, "progress"),
      data: data,
      time: DateTime.utc_now()
    ]

    base_opts
    |> maybe_put_correlation_id(correlation_id)
    |> maybe_put_subject(Keyword.get(opts, :subject))
    |> maybe_put_extensions(Keyword.get(opts, :extensions))
    |> CloudEvent.new!()
  end

  @doc """
  Creates a data changed event for an agent.

  ## Options

  * `:agent_name` - Required. The name of the agent
  * `:entity_type` - Required. Type of entity that changed
  * `:entity_id` - Required. ID of the entity that changed
  * `:data` - Required. The changed data
  * `:action` - Optional. Action that caused the change (created, updated, deleted)
  * `:correlation_id` - Optional. Correlation ID for request/response tracking
  * `:extensions` - Optional. Additional custom attributes

  ## Examples

      event = WebUI.AgentEvents.data_changed(
        agent_name: "user-manager",
        entity_type: "user",
        entity_id: "123",
        data: %{status: "active"}
      )

      event = WebUI.AgentEvents.data_changed(
        agent_name: "document-store",
        entity_type: "document",
        entity_id: "doc-456",
        data: %{title: "New Title"},
        action: "updated"
      )

  """
  @spec data_changed([
          agent_name: agent_name(),
          entity_type: String.t(),
          entity_id: String.t(),
          data: event_data()
        ] | event_opts()) :: CloudEvent.t()
  def data_changed(opts) when is_list(opts) do
    agent_name = Keyword.fetch!(opts, :agent_name)
    entity_type = Keyword.fetch!(opts, :entity_type)
    entity_id = Keyword.fetch!(opts, :entity_id)
    data = Keyword.fetch!(opts, :data)
    action = Keyword.get(opts, :action)

    correlation_id = Keyword.get(opts, :correlation_id)

    event_data =
      %{
        entity_type: entity_type,
        entity_id: entity_id,
        changes: data
      }
      |> maybe_put_action(action)

    base_opts = [
      source: build_source(agent_name),
      type: build_type(agent_name, "data_changed"),
      data: event_data,
      subject: entity_id,
      time: DateTime.utc_now()
    ]

    base_opts
    |> maybe_put_correlation_id(correlation_id)
    |> maybe_put_extensions(Keyword.get(opts, :extensions))
    |> CloudEvent.new!()
  end

  @doc """
  Creates a validation error event for an agent.

  ## Options

  * `:agent_name` - Required. The name of the agent
  * `:errors` - Required. List of validation errors
  * `:correlation_id` - Optional. Correlation ID for request/response tracking
  * `:subject` - Optional. Subject of the event
  * `:extensions` - Optional. Additional custom attributes

  ## Examples

      event = WebUI.AgentEvents.validation_error(
        agent_name: "form-validator",
        errors: [
          %{field: "email", message: "Invalid format"},
          %{field: "password", message: "Too short"}
        ]
      )

  """
  @spec validation_error([agent_name: agent_name(), errors: list()] | event_opts()) ::
          CloudEvent.t()
  def validation_error(opts) when is_list(opts) do
    agent_name = Keyword.fetch!(opts, :agent_name)
    errors = Keyword.fetch!(opts, :errors)
    correlation_id = Keyword.get(opts, :correlation_id)

    data = %{
      errors: normalize_errors(errors),
      error_count: length(List.wrap(errors))
    }

    base_opts = [
      source: build_source(agent_name),
      type: build_type(agent_name, "validation_error"),
      data: data,
      time: DateTime.utc_now()
    ]

    base_opts
    |> maybe_put_correlation_id(correlation_id)
    |> maybe_put_subject(Keyword.get(opts, :subject))
    |> maybe_put_extensions(Keyword.get(opts, :extensions))
    |> CloudEvent.new!()
  end

  @doc """
  Creates a batch of events.

  Returns a list of CloudEvents that can be dispatched together.

  ## Examples

      events = WebUI.AgentEvents.batch([
        WebUI.AgentEvents.ok(agent_name: "worker-1", data: %{task: "done"}),
        WebUI.AgentEvents.ok(agent_name: "worker-2", data: %{task: "done"})
      ])

  """
  @spec batch([CloudEvent.t()]) :: [CloudEvent.t()]
  def batch(events) when is_list(events), do: events

  @doc """
  Checks if an event matches the given filter criteria.

  ## Filter Options

  * `:type` - Match events with this type (supports wildcards)
  * `:source` - Match events from this source
  * `:agent_name` - Match events from this agent
  * `:has_correlation_id` - Match events with a correlation ID
  * `:min_data` - Match events with at least these data keys

  ## Examples

      WebUI.AgentEvents.matches?(event, type: "com.webui.agent.*")
      WebUI.AgentEvents.matches?(event, agent_name: "calculator")
      WebUI.AgentEvents.matches?(event, has_correlation_id: true)

  """
  @spec matches?(CloudEvent.t(), keyword()) :: boolean()
  def matches?(%CloudEvent{} = event, filters) when is_list(filters) do
    Enum.all?(filters, fn
      {:type, pattern} -> matches_type?(event.type, pattern)
      {:source, source} -> event.source == source
      {:agent_name, name} -> event.source == build_source(name)
      {:has_correlation_id, true} -> has_correlation_id?(event)
      {:has_correlation_id, false} -> not has_correlation_id?(event)
      {:min_data, keys} -> has_min_data?(event, keys)
      _ -> true
    end)
  end

  @doc """
  Extracts the correlation ID from an event.

  Returns the correlation ID if present, nil otherwise.

  ## Examples

      correlation_id = WebUI.AgentEvents.get_correlation_id(event)
      # => "req-123" or nil

  """
  @spec get_correlation_id(CloudEvent.t()) :: String.t() | nil
  def get_correlation_id(%CloudEvent{extensions: extensions}) when is_map(extensions) do
    Map.get(extensions, "correlation_id")
  end

  def get_correlation_id(%CloudEvent{}), do: nil

  @doc """
  Extracts the agent name from an event source.

  Returns the agent name if the source follows the agent URN convention,
  nil otherwise.

  ## Examples

      agent_name = WebUI.AgentEvents.get_agent_name(event)
      # => "calculator" or nil

  """
  @spec get_agent_name(CloudEvent.t()) :: String.t() | nil
  def get_agent_name(%CloudEvent{source: source}) when is_binary(source) do
    case String.split(source, ":") do
      ["urn", "jido", "agents", name] -> name
      _ -> nil
    end
  end

  @doc """
  Creates an event with a custom type for an agent.

  ## Options

  * `:agent_name` - Required. The name of the agent
  * `:event_type` - Required. The custom event type suffix
  * `:data` - Required. The event data
  * `:correlation_id` - Optional. Correlation ID for request/response tracking
  * `:subject` - Optional. Subject of the event
  * `:extensions` - Optional. Additional custom attributes

  ## Examples

      event = WebUI.AgentEvents.custom(
        agent_name: "calculator",
        event_type: "calculation_started",
        data: %{expression: "2 + 2"}
      )
      # event.type == "com.webui.agent.calculator.calculation_started"

  """
  @spec custom([
          agent_name: agent_name(),
          event_type: String.t(),
          data: event_data()
        ] | event_opts()) :: CloudEvent.t()
  def custom(opts) when is_list(opts) do
    agent_name = Keyword.fetch!(opts, :agent_name)
    event_type = Keyword.fetch!(opts, :event_type)
    data = Keyword.fetch!(opts, :data)
    correlation_id = Keyword.get(opts, :correlation_id)

    base_opts = [
      source: build_source(agent_name),
      type: build_type(agent_name, event_type),
      data: data,
      time: DateTime.utc_now()
    ]

    base_opts
    |> maybe_put_correlation_id(correlation_id)
    |> maybe_put_subject(Keyword.get(opts, :subject))
    |> maybe_put_extensions(Keyword.get(opts, :extensions))
    |> CloudEvent.new!()
  end

  # Private helper functions

  defp build_source(agent_name) when is_atom(agent_name), do: build_source(to_string(agent_name))

  defp build_source(agent_name) when is_binary(agent_name) do
    "urn:jido:agents:#{agent_name}"
  end

  defp build_type(agent_name, event_type) when is_atom(agent_name),
    do: build_type(to_string(agent_name), event_type)

  defp build_type(agent_name, event_type) when is_binary(agent_name) and is_binary(event_type) do
    "com.webui.agent.#{agent_name}.#{event_type}"
  end

  defp maybe_put_correlation_id(opts, nil), do: opts
  defp maybe_put_correlation_id(opts, correlation_id) when is_binary(correlation_id) do
    extensions = Keyword.get(opts, :extensions, %{})
    Keyword.put(opts, :extensions, Map.put(extensions, "correlation_id", correlation_id))
  end

  defp maybe_put_subject(opts, nil), do: opts
  defp maybe_put_subject(opts, subject) when is_binary(subject) do
    Keyword.put(opts, :subject, subject)
  end

  defp maybe_put_extensions(opts, nil), do: opts
  defp maybe_put_extensions(opts, extensions) when is_map(extensions) do
    existing = Keyword.get(opts, :extensions, %{})
    Keyword.put(opts, :extensions, Map.merge(existing, extensions))
  end

  defp maybe_put_message(data, nil), do: data
  defp maybe_put_message(data, message) when is_binary(message) do
    Map.put(data, :message, message)
  end

  defp maybe_put_action(data, nil), do: data
  defp maybe_put_action(data, action) when is_binary(action) do
    Map.put(data, :action, action)
  end

  defp calculate_percent(current, total) when total > 0 do
    round((current / total) * 100)
  end

  defp calculate_percent(_current, _total), do: 0

  defp normalize_errors(errors) when is_list(errors) do
    Enum.map(errors, fn
      error when is_map(error) -> error
      error when is_binary(error) -> %{message: error}
      _ -> %{message: "Unknown error"}
    end)
  end

  defp normalize_errors(error) when is_binary(error), do: normalize_errors([error])
  defp normalize_errors(_), do: [%{message: "Unknown error"}]

  defp matches_type?(type, pattern) when is_binary(type) and is_binary(pattern) do
    # Simple wildcard matching
    pattern_regex = Regex.compile!(Regex.escape(pattern) |> String.replace("\\*", ".*"))
    Regex.match?(pattern_regex, type)
  end

  defp has_correlation_id?(%CloudEvent{extensions: extensions}) when is_map(extensions) do
    Map.has_key?(extensions, "correlation_id")
  end

  defp has_correlation_id?(%CloudEvent{}), do: false

  defp has_min_data?(%CloudEvent{data: data}, keys) when is_list(keys) do
    data_keys = if is_map(data), do: Map.keys(data), else: []
    required_keys = keys |> List.wrap() |> Enum.map(&to_string/1) |> MapSet.new()
    data_keys_set = data_keys |> Enum.map(&to_string/1) |> MapSet.new()
    MapSet.subset?(required_keys, data_keys_set)
  end
end
