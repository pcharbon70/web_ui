defmodule WebUi.WidgetRegistry do
  @moduledoc """
  Built-in widget catalog registry with deterministic term_ui parity baseline.
  """

  alias WebUi.TypedError

  @allowed_categories ["primitive", "navigation", "overlay", "visualization", "data", "runtime", "utility"]

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
    %{widget_id: "block", termui_module: "TermUI.Widget.Block", category: "primitive"},
    %{widget_id: "button", termui_module: "TermUI.Widget.Button", category: "primitive"},
    %{widget_id: "label", termui_module: "TermUI.Widget.Label", category: "primitive"},
    %{widget_id: "list", termui_module: "TermUI.Widget.List", category: "primitive"},
    %{widget_id: "pick_list", termui_module: "TermUI.Widget.PickList", category: "primitive"},
    %{widget_id: "progress", termui_module: "TermUI.Widget.Progress", category: "primitive"},
    %{widget_id: "text_input_primitive", termui_module: "TermUI.Widget.TextInput", category: "primitive"},
    %{widget_id: "alert_dialog", termui_module: "TermUI.Widgets.AlertDialog", category: "overlay"},
    %{widget_id: "bar_chart", termui_module: "TermUI.Widgets.BarChart", category: "visualization"},
    %{widget_id: "canvas", termui_module: "TermUI.Widgets.Canvas", category: "visualization"},
    %{widget_id: "cluster_dashboard", termui_module: "TermUI.Widgets.ClusterDashboard", category: "runtime"},
    %{widget_id: "command_palette", termui_module: "TermUI.Widgets.CommandPalette", category: "navigation"},
    %{widget_id: "context_menu", termui_module: "TermUI.Widgets.ContextMenu", category: "overlay"},
    %{widget_id: "dialog", termui_module: "TermUI.Widgets.Dialog", category: "overlay"},
    %{widget_id: "form_builder", termui_module: "TermUI.Widgets.FormBuilder", category: "utility"},
    %{widget_id: "gauge", termui_module: "TermUI.Widgets.Gauge", category: "visualization"},
    %{widget_id: "line_chart", termui_module: "TermUI.Widgets.LineChart", category: "visualization"},
    %{widget_id: "log_viewer", termui_module: "TermUI.Widgets.LogViewer", category: "data"},
    %{widget_id: "markdown_viewer", termui_module: "TermUI.Widgets.MarkdownViewer", category: "data"},
    %{widget_id: "menu", termui_module: "TermUI.Widgets.Menu", category: "navigation"},
    %{widget_id: "process_monitor", termui_module: "TermUI.Widgets.ProcessMonitor", category: "runtime"},
    %{widget_id: "scroll_bar", termui_module: "TermUI.Widgets.ScrollBar", category: "navigation"},
    %{widget_id: "sparkline", termui_module: "TermUI.Widgets.Sparkline", category: "visualization"},
    %{widget_id: "split_pane", termui_module: "TermUI.Widgets.SplitPane", category: "navigation"},
    %{widget_id: "stream_widget", termui_module: "TermUI.Widgets.StreamWidget", category: "runtime"},
    %{widget_id: "supervision_tree_viewer", termui_module: "TermUI.Widgets.SupervisionTreeViewer", category: "runtime"},
    %{widget_id: "table", termui_module: "TermUI.Widgets.Table", category: "data"},
    %{widget_id: "tabs", termui_module: "TermUI.Widgets.Tabs", category: "navigation"},
    %{widget_id: "text_input", termui_module: "TermUI.Widgets.TextInput", category: "utility"},
    %{widget_id: "toast", termui_module: "TermUI.Widgets.Toast", category: "overlay"},
    %{widget_id: "toast_manager", termui_module: "TermUI.Widgets.ToastManager", category: "overlay"},
    %{widget_id: "tree_view", termui_module: "TermUI.Widgets.TreeView", category: "data"},
    %{widget_id: "viewport", termui_module: "TermUI.Widgets.Viewport", category: "navigation"}
  ]

  @catalog_fingerprint :erlang.phash2(@builtin_widget_entries)

  @enforce_keys [:built_in_index, :catalog_fingerprint]
  defstruct built_in_index: %{}, catalog_fingerprint: @catalog_fingerprint

  @type widget_entry :: %{
          widget_id: String.t(),
          termui_module: String.t(),
          category: String.t()
        }

  @type t :: %__MODULE__{built_in_index: %{String.t() => widget_entry()}, catalog_fingerprint: non_neg_integer()}

  @spec new() :: {:ok, t()} | {:error, TypedError.t()}
  def new do
    with :ok <- parity_check(),
         :ok <- validate_categories() do
      {:ok,
       %__MODULE__{
         built_in_index: Map.new(@builtin_widget_entries, &{&1.widget_id, &1}),
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

  @spec allowed_categories() :: [String.t()]
  def allowed_categories, do: @allowed_categories

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
    invalid_entries = Enum.reject(@builtin_widget_entries, &(&1.category in @allowed_categories))

    case invalid_entries do
      [] ->
        :ok

      _ ->
        {:error,
         TypedError.new(
           "widget_registry.invalid_category",
           "validation",
           false,
           %{invalid_entries: invalid_entries, allowed_categories: @allowed_categories}
         )}
    end
  end

  @spec catalog_fingerprint() :: non_neg_integer()
  def catalog_fingerprint, do: @catalog_fingerprint

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
end
