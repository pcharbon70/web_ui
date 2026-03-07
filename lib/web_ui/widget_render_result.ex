defmodule WebUi.WidgetRenderResult do
  @moduledoc """
  Normalized widget render result contract.
  """

  alias WebUi.TypedError

  @enforce_keys [:widget_id, :outcome, :events]
  defstruct [:widget_id, :outcome, :node, :error, :events]

  @type t :: %__MODULE__{
          widget_id: String.t(),
          outcome: String.t(),
          node: map() | nil,
          error: TypedError.t() | nil,
          events: [map()]
        }

  @spec success(String.t(), map(), map()) :: t()
  def success(widget_id, node, context) when is_binary(widget_id) and is_map(node) and is_map(context) do
    %__MODULE__{
      widget_id: widget_id,
      outcome: "ok",
      node: node,
      error: nil,
      events: [rendered_event(widget_id, context)]
    }
  end

  @spec error(String.t(), TypedError.t(), map()) :: t()
  def error(widget_id, %TypedError{} = typed_error, context) when is_binary(widget_id) and is_map(context) do
    %__MODULE__{
      widget_id: widget_id,
      outcome: "error",
      node: nil,
      error: typed_error,
      events: [render_failed_event(widget_id, typed_error, context)]
    }
  end

  defp rendered_event(widget_id, context) do
    %{
      event_name: "runtime.widget.rendered.v1",
      event_version: "v1",
      source: "WebUi.Widget",
      widget_id: widget_id,
      correlation_id: Map.get(context, :correlation_id, "unknown"),
      request_id: Map.get(context, :request_id, "unknown"),
      outcome: "ok"
    }
  end

  defp render_failed_event(widget_id, typed_error, context) do
    %{
      event_name: "runtime.widget.render_failed.v1",
      event_version: "v1",
      source: "WebUi.Widget",
      widget_id: widget_id,
      correlation_id: Map.get(context, :correlation_id, typed_error.correlation_id),
      request_id: Map.get(context, :request_id, "unknown"),
      outcome: "error",
      error_code: typed_error.error_code,
      category: typed_error.category
    }
  end
end
