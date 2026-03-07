defmodule WebUi.Widget do
  @moduledoc """
  Deterministic widget render boundary for built-in registry descriptors.
  """

  alias WebUi.TypedError
  alias WebUi.WidgetRegistry
  alias WebUi.WidgetRenderRequest
  alias WebUi.WidgetRenderResult

  @spec validate_render_request(WidgetRegistry.t(), map() | WidgetRenderRequest.t()) ::
          {:ok, WidgetRenderRequest.t()} | {:error, TypedError.t()}
  def validate_render_request(%WidgetRegistry{} = registry, request) do
    with {:ok, normalized_request} <- WidgetRenderRequest.validate(request),
         {:ok, _descriptor} <- WidgetRegistry.descriptor(registry, normalized_request.widget_id) do
      {:ok, normalized_request}
    else
      {:error, %TypedError{} = error} -> {:error, error}
    end
  end

  @spec render(WidgetRegistry.t(), map() | WidgetRenderRequest.t()) :: WidgetRenderResult.t()
  def render(%WidgetRegistry{} = registry, request) do
    context = request_context(request)

    with {:ok, normalized_request} <- validate_render_request(registry, request),
         {:ok, descriptor} <- WidgetRegistry.descriptor(registry, normalized_request.widget_id),
         {:ok, entry} <- WidgetRegistry.entry(registry, normalized_request.widget_id) do
      node = render_node(descriptor, entry, normalized_request.props, normalized_request.state)
      WidgetRenderResult.success(normalized_request.widget_id, node, normalized_request.context)
    else
      {:error, %TypedError{} = error} ->
        widget_id = request_widget_id(request)
        WidgetRenderResult.error(widget_id, error, context)
    end
  end

  defp render_node(descriptor, entry, props, state) do
    %{
      widget_id: descriptor.widget_id,
      termui_module: entry.termui_module,
      descriptor_version: descriptor.version,
      category: descriptor.category,
      state_model: descriptor.state_model,
      props: normalize_map(props),
      state: normalize_map(state)
    }
  end

  defp normalize_map(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), normalize_value(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.into(%{})
  end

  defp normalize_value(value) when is_map(value), do: normalize_map(value)
  defp normalize_value(value) when is_list(value), do: Enum.map(value, &normalize_value/1)
  defp normalize_value(value), do: value

  defp request_widget_id(%WidgetRenderRequest{widget_id: widget_id}), do: widget_id

  defp request_widget_id(request) when is_map(request) do
    Map.get(request, :widget_id) || Map.get(request, "widget_id") || "unknown_widget"
  end

  defp request_widget_id(_request), do: "unknown_widget"

  defp request_context(%WidgetRenderRequest{context: context}), do: context

  defp request_context(request) when is_map(request) do
    case Map.get(request, :context) || Map.get(request, "context") do
      context when is_map(context) -> context
      _ -> %{}
    end
  end

  defp request_context(_request), do: %{}
end
