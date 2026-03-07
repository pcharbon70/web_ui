defmodule WebUi.WidgetRegistry do
  @moduledoc """
  Built-in widget catalog registry with deterministic term_ui parity baseline.
  """

  alias WebUi.TypedError
  alias WebUi.WidgetDescriptor

  @required_builtin_ids [
    "block",
    "button",
    "label",
    "list",
    "pick_list",
    "progress",
    "text_input_primitive",
    "alert_dialog",
    "bar_chart",
    "canvas",
    "cluster_dashboard",
    "command_palette",
    "context_menu",
    "dialog",
    "form_builder",
    "gauge",
    "line_chart",
    "log_viewer",
    "markdown_viewer",
    "menu",
    "process_monitor",
    "scroll_bar",
    "sparkline",
    "split_pane",
    "stream_widget",
    "supervision_tree_viewer",
    "table",
    "tabs",
    "text_input",
    "toast",
    "toast_manager",
    "tree_view",
    "viewport"
  ]

  @builtin_widget_entries [
    %{widget_id: "block", termui_module: "TermUI.Widget.Block", category: "primitive", event_types: []},
    %{widget_id: "button", termui_module: "TermUI.Widget.Button", category: "primitive", event_types: ["unified.button.clicked", "unified.element.focused", "unified.element.blurred"]},
    %{widget_id: "label", termui_module: "TermUI.Widget.Label", category: "primitive", event_types: []},
    %{widget_id: "list", termui_module: "TermUI.Widget.List", category: "primitive", event_types: ["unified.item.selected", "unified.item.toggled"]},
    %{widget_id: "pick_list", termui_module: "TermUI.Widget.PickList", category: "primitive", event_types: ["unified.item.selected", "unified.overlay.closed"]},
    %{widget_id: "progress", termui_module: "TermUI.Widget.Progress", category: "primitive", event_types: []},
    %{widget_id: "text_input_primitive", termui_module: "TermUI.Widget.TextInput", category: "primitive", event_types: ["unified.input.changed", "unified.form.submitted", "unified.element.focused", "unified.element.blurred"]},
    %{widget_id: "alert_dialog", termui_module: "TermUI.Widgets.AlertDialog", category: "overlay", event_types: ["unified.overlay.confirmed", "unified.overlay.closed", "unified.button.clicked"]},
    %{widget_id: "bar_chart", termui_module: "TermUI.Widgets.BarChart", category: "visualization", event_types: ["unified.chart.point_selected", "unified.chart.point_hovered"]},
    %{widget_id: "canvas", termui_module: "TermUI.Widgets.Canvas", category: "visualization", event_types: ["unified.canvas.pointer.changed", "unified.button.clicked"]},
    %{widget_id: "cluster_dashboard", termui_module: "TermUI.Widgets.ClusterDashboard", category: "runtime", event_types: ["unified.item.selected", "unified.view.changed", "unified.action.requested"]},
    %{widget_id: "command_palette", termui_module: "TermUI.Widgets.CommandPalette", category: "navigation", event_types: ["unified.input.changed", "unified.item.selected", "unified.command.executed", "unified.overlay.closed"]},
    %{widget_id: "context_menu", termui_module: "TermUI.Widgets.ContextMenu", category: "overlay", event_types: ["unified.menu.action_selected", "unified.item.selected", "unified.overlay.closed"]},
    %{widget_id: "dialog", termui_module: "TermUI.Widgets.Dialog", category: "overlay", event_types: ["unified.overlay.confirmed", "unified.overlay.closed", "unified.button.clicked"]},
    %{widget_id: "form_builder", termui_module: "TermUI.Widgets.FormBuilder", category: "utility", event_types: ["unified.input.changed", "unified.form.submitted", "unified.item.toggled", "unified.element.focused", "unified.element.blurred"]},
    %{widget_id: "gauge", termui_module: "TermUI.Widgets.Gauge", category: "visualization", event_types: []},
    %{widget_id: "line_chart", termui_module: "TermUI.Widgets.LineChart", category: "visualization", event_types: ["unified.chart.point_selected", "unified.chart.point_hovered"]},
    %{widget_id: "log_viewer", termui_module: "TermUI.Widgets.LogViewer", category: "data", event_types: ["unified.scroll.changed", "unified.item.selected", "unified.input.changed"]},
    %{widget_id: "markdown_viewer", termui_module: "TermUI.Widgets.MarkdownViewer", category: "data", event_types: ["unified.link.clicked"]},
    %{widget_id: "menu", termui_module: "TermUI.Widgets.Menu", category: "navigation", event_types: ["unified.menu.action_selected", "unified.item.selected"]},
    %{widget_id: "process_monitor", termui_module: "TermUI.Widgets.ProcessMonitor", category: "runtime", event_types: ["unified.item.selected", "unified.action.requested"]},
    %{widget_id: "scroll_bar", termui_module: "TermUI.Widgets.ScrollBar", category: "navigation", event_types: ["unified.scroll.changed"]},
    %{widget_id: "sparkline", termui_module: "TermUI.Widgets.Sparkline", category: "visualization", event_types: ["unified.chart.point_selected", "unified.chart.point_hovered"]},
    %{widget_id: "split_pane", termui_module: "TermUI.Widgets.SplitPane", category: "navigation", event_types: ["unified.split.resized", "unified.split.collapse_changed"]},
    %{widget_id: "stream_widget", termui_module: "TermUI.Widgets.StreamWidget", category: "runtime", event_types: ["unified.item.selected", "unified.scroll.changed"]},
    %{widget_id: "supervision_tree_viewer", termui_module: "TermUI.Widgets.SupervisionTreeViewer", category: "runtime", event_types: ["unified.tree.node_selected", "unified.tree.node_toggled", "unified.action.requested"]},
    %{widget_id: "table", termui_module: "TermUI.Widgets.Table", category: "data", event_types: ["unified.table.row_selected", "unified.table.sorted", "unified.item.toggled"]},
    %{widget_id: "tabs", termui_module: "TermUI.Widgets.Tabs", category: "navigation", event_types: ["unified.tab.changed", "unified.tab.closed"]},
    %{widget_id: "text_input", termui_module: "TermUI.Widgets.TextInput", category: "utility", event_types: ["unified.input.changed", "unified.form.submitted", "unified.element.focused", "unified.element.blurred"]},
    %{widget_id: "toast", termui_module: "TermUI.Widgets.Toast", category: "overlay", event_types: ["unified.toast.dismissed"]},
    %{widget_id: "toast_manager", termui_module: "TermUI.Widgets.ToastManager", category: "overlay", event_types: ["unified.toast.dismissed", "unified.toast.cleared"]},
    %{widget_id: "tree_view", termui_module: "TermUI.Widgets.TreeView", category: "data", event_types: ["unified.tree.node_selected", "unified.tree.node_toggled"]},
    %{widget_id: "viewport", termui_module: "TermUI.Widgets.Viewport", category: "navigation", event_types: ["unified.scroll.changed", "unified.viewport.resized"]}
  ]

  @catalog_fingerprint :erlang.phash2(@builtin_widget_entries)

  @enforce_keys [:built_in_index, :descriptor_index, :catalog_fingerprint]
  defstruct built_in_index: %{}, descriptor_index: %{}, catalog_fingerprint: @catalog_fingerprint

  @type widget_entry :: %{
          widget_id: String.t(),
          termui_module: String.t(),
          category: String.t(),
          event_types: [String.t()]
        }

  @type t :: %__MODULE__{
          built_in_index: %{String.t() => widget_entry()},
          descriptor_index: %{String.t() => WidgetDescriptor.t()},
          catalog_fingerprint: non_neg_integer()
        }

  @spec new() :: {:ok, t()} | {:error, TypedError.t()}
  def new do
    with :ok <- parity_check(),
         :ok <- validate_categories(),
         {:ok, descriptors} <- validate_descriptors() do
      {:ok,
       %__MODULE__{
         built_in_index: Map.new(@builtin_widget_entries, &{&1.widget_id, Map.new(&1)}),
         descriptor_index: Map.new(descriptors, &{&1.widget_id, &1}),
         catalog_fingerprint: @catalog_fingerprint
       }}
    end
  end

  @spec builtin_widget_entries() :: [widget_entry()]
  def builtin_widget_entries do
    Enum.map(@builtin_widget_entries, &Map.new/1)
  end

  @spec builtin_widget_ids() :: [String.t()]
  def builtin_widget_ids do
    Enum.map(@builtin_widget_entries, & &1.widget_id)
  end

  @spec builtin_widget_descriptors() :: [WidgetDescriptor.t()]
  def builtin_widget_descriptors do
    Enum.map(@builtin_widget_entries, &descriptor_from_entry/1)
  end

  @spec allowed_categories() :: [String.t()]
  def allowed_categories, do: WidgetDescriptor.allowed_categories()

  @spec parity_check() :: :ok | {:error, TypedError.t()}
  def parity_check do
    actual = builtin_widget_ids()

    if actual == @required_builtin_ids do
      :ok
    else
      {:error,
       TypedError.new(
         "widget_registry.catalog_mismatch",
         "validation",
         false,
         %{expected_ids: @required_builtin_ids, actual_ids: actual}
       )}
    end
  end

  @spec validate_categories() :: :ok | {:error, TypedError.t()}
  def validate_categories do
    invalid_entries = Enum.reject(@builtin_widget_entries, &(&1.category in allowed_categories()))

    case invalid_entries do
      [] ->
        :ok

      _ ->
        {:error,
         TypedError.new(
           "widget_registry.invalid_category",
           "validation",
           false,
           %{invalid_entries: invalid_entries, allowed_categories: allowed_categories()}
         )}
    end
  end

  @spec validate_catalog_fingerprint(non_neg_integer()) :: :ok | {:error, TypedError.t()}
  def validate_catalog_fingerprint(expected) when is_integer(expected) and expected >= 0 do
    if expected == @catalog_fingerprint do
      :ok
    else
      {:error,
       TypedError.new(
         "widget_registry.catalog_fingerprint_mismatch",
         "validation",
         false,
         %{expected_fingerprint: expected, actual_fingerprint: @catalog_fingerprint}
       )}
    end
  end

  @spec catalog_fingerprint() :: non_neg_integer()
  def catalog_fingerprint, do: @catalog_fingerprint

  @spec entry(t(), String.t()) :: {:ok, widget_entry()} | {:error, TypedError.t()}
  def entry(%__MODULE__{built_in_index: index}, widget_id) when is_binary(widget_id) do
    case Map.get(index, widget_id) do
      nil ->
        {:error,
         TypedError.new(
           "widget_registry.unknown_widget",
           "validation",
           false,
           %{widget_id: widget_id}
         )}

      entry ->
        {:ok, Map.new(entry)}
    end
  end

  @spec descriptor(t(), String.t()) :: {:ok, WidgetDescriptor.t()} | {:error, TypedError.t()}
  def descriptor(%__MODULE__{descriptor_index: descriptors}, widget_id) when is_binary(widget_id) do
    case Map.get(descriptors, widget_id) do
      nil ->
        {:error,
         TypedError.new(
           "widget_registry.descriptor_not_found",
           "validation",
           false,
           %{widget_id: widget_id}
         )}

      descriptor ->
        {:ok, descriptor}
    end
  end

  @spec list_descriptors(t(), keyword()) :: [WidgetDescriptor.t()]
  def list_descriptors(%__MODULE__{descriptor_index: descriptors}, filters \\ []) when is_list(filters) do
    descriptors
    |> Map.values()
    |> Enum.filter(fn descriptor ->
      matches_filter?(descriptor, :category, Keyword.get(filters, :category)) and
        matches_filter?(descriptor, :origin, Keyword.get(filters, :origin))
    end)
    |> Enum.sort_by(& &1.widget_id)
  end

  @spec list_by_category(t(), String.t()) :: [WidgetDescriptor.t()]
  def list_by_category(%__MODULE__{} = registry, category) when is_binary(category) do
    list_descriptors(registry, category: category)
  end

  @spec list_by_origin(t(), String.t()) :: [WidgetDescriptor.t()]
  def list_by_origin(%__MODULE__{} = registry, origin) when is_binary(origin) do
    list_descriptors(registry, origin: origin)
  end

  defp validate_descriptors do
    @builtin_widget_entries
    |> Enum.map(&descriptor_from_entry/1)
    |> Enum.reduce_while({:ok, []}, fn descriptor_map, {:ok, acc} ->
      case WidgetDescriptor.validate(descriptor_map) do
        {:ok, descriptor} -> {:cont, {:ok, [descriptor | acc]}}
        {:error, %TypedError{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, descriptors} -> {:ok, Enum.reverse(descriptors)}
      {:error, %TypedError{} = error} -> {:error, error}
    end
  end

  defp descriptor_from_entry(entry) do
    %{
      widget_id: entry.widget_id,
      origin: "builtin",
      category: entry.category,
      state_model: state_model(entry.event_types),
      props_schema: %{
        type: "object",
        additional_properties: true,
        required: []
      },
      event_schema: %{
        version: "v1",
        event_types: entry.event_types
      },
      version: "v1",
      capabilities: []
    }
  end

  defp state_model([]), do: "stateless"
  defp state_model(_event_types), do: "stateful"

  defp matches_filter?(_descriptor, _field, nil), do: true

  defp matches_filter?(descriptor, field, expected) do
    Map.get(descriptor, field) == expected
  end
end
