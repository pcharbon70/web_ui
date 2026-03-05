defmodule CounterExample.EventContract do
  @moduledoc """
  Single source of truth for the counter example CloudEvent contract.

  This module defines event types, source URIs, specversion expectations,
  and payload field requirements used by the counter example.
  """

  @specversion "1.0"
  @client_source "urn:webui:examples:counter:client"
  @server_source "urn:webui:examples:counter"
  @state_changed_type "com.webui.counter.state_changed"

  @command_type_to_operation %{
    "com.webui.counter.increment" => :increment,
    "com.webui.counter.decrement" => :decrement,
    "com.webui.counter.reset" => :reset,
    "com.webui.counter.sync" => :sync
  }

  @operation_to_command_type Map.new(@command_type_to_operation, fn {type, operation} ->
                               {operation, type}
                             end)

  @command_event_required_fields ["specversion", "id", "source", "type"]
  @command_event_optional_fields ["data", "time"]
  @state_changed_required_data_fields ["count", "operation"]
  @state_changed_optional_data_fields ["correlation_id"]
  @operations Enum.uniq(Map.values(@command_type_to_operation))

  @type operation :: :increment | :decrement | :reset | :sync
  @type command_type :: String.t()

  @spec specversion() :: String.t()
  def specversion, do: @specversion

  @spec supported_specversion?(term()) :: boolean()
  def supported_specversion?(version), do: version == @specversion

  @spec client_source() :: String.t()
  def client_source, do: @client_source

  @spec server_source() :: String.t()
  def server_source, do: @server_source

  @spec command_types() :: [command_type()]
  def command_types, do: Map.keys(@command_type_to_operation)

  @spec state_changed_type() :: String.t()
  def state_changed_type, do: @state_changed_type

  @spec operations() :: [operation()]
  def operations, do: @operations

  @spec command_type_for_operation(operation()) :: {:ok, command_type()} | :error
  def command_type_for_operation(operation) do
    case Map.fetch(@operation_to_command_type, operation) do
      {:ok, type} -> {:ok, type}
      :error -> :error
    end
  end

  @spec operation_from_command_type(command_type()) :: {:ok, operation()} | :error
  def operation_from_command_type(type) do
    case Map.fetch(@command_type_to_operation, type) do
      {:ok, operation} -> {:ok, operation}
      :error -> :error
    end
  end

  @spec command_event_required_fields() :: [String.t()]
  def command_event_required_fields, do: @command_event_required_fields

  @spec command_event_optional_fields() :: [String.t()]
  def command_event_optional_fields, do: @command_event_optional_fields

  @spec state_changed_required_data_fields() :: [String.t()]
  def state_changed_required_data_fields, do: @state_changed_required_data_fields

  @spec state_changed_optional_data_fields() :: [String.t()]
  def state_changed_optional_data_fields, do: @state_changed_optional_data_fields
end
