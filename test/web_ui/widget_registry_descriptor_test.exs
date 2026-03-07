defmodule WebUi.WidgetRegistryDescriptorTest do
  use ExUnit.Case, async: true

  alias WebUi.TypedError
  alias WebUi.WidgetRegistry

  test "all built-in descriptors include required metadata fields" do
    {:ok, registry} = WidgetRegistry.new()

    descriptors = WidgetRegistry.list_by_origin(registry, "builtin")

    assert length(descriptors) == 33

    for descriptor <- descriptors do
      assert is_binary(descriptor.widget_id) and descriptor.widget_id != ""
      assert descriptor.origin == "builtin"
      assert descriptor.category in WidgetRegistry.allowed_categories()
      assert descriptor.state_model in ["stateless", "stateful"]
      assert descriptor.version == "v1"
      assert is_map(descriptor.props_schema)
      assert descriptor.props_schema.type == "object"
      assert is_map(descriptor.event_schema)
      assert is_list(descriptor.event_schema.event_types)
      assert descriptor.event_schema.version == "v1"
    end
  end

  test "descriptor lookup by widget ID is deterministic" do
    {:ok, registry} = WidgetRegistry.new()

    assert {:ok, descriptor_a} = WidgetRegistry.descriptor(registry, "button")
    assert {:ok, descriptor_b} = WidgetRegistry.descriptor(registry, "button")

    assert descriptor_a == descriptor_b
    assert "unified.button.clicked" in descriptor_a.event_schema.event_types
  end

  test "descriptor list filters by category and origin" do
    {:ok, registry} = WidgetRegistry.new()

    overlays = WidgetRegistry.list_by_category(registry, "overlay")
    builtins = WidgetRegistry.list_by_origin(registry, "builtin")

    assert overlays != []
    assert Enum.all?(overlays, &(&1.category == "overlay"))
    assert Enum.all?(builtins, &(&1.origin == "builtin"))
  end

  test "missing descriptor lookup returns typed error" do
    {:ok, registry} = WidgetRegistry.new()

    assert {:error, %TypedError{} = error} = WidgetRegistry.descriptor(registry, "unknown_widget")
    assert error.error_code == "widget_registry.descriptor_not_found"
    assert error.category == "validation"
  end
end
