defmodule WebUi.WidgetRegistryCustomTest do
  use ExUnit.Case, async: true

  alias WebUi.TypedError
  alias WebUi.WidgetRegistry

  defp base_request(overrides \\ %{}) do
    base = %{
      descriptor: %{
        widget_id: "custom.acme.console",
        origin: "custom",
        category: "runtime",
        state_model: "stateful",
        props_schema: %{type: "object", additional_properties: true},
        event_schema: %{
          version: "v1",
          event_types: ["custom.acme.console.selected", "unified.item.selected"]
        },
        version: "v1",
        capabilities: ["emit_widget_events@1"]
      },
      implementation_ref: "WebUi.CustomWidgets.AcmeConsole",
      requested_by: "acme-team",
      context: %{correlation_id: "corr-611", request_id: "req-611"}
    }

    Map.merge(base, overrides)
  end

  test "valid custom widget registrations are accepted and queryable" do
    {:ok, registry} = WidgetRegistry.new()
    assert {:ok, updated_registry} = WidgetRegistry.register_custom(registry, base_request())

    assert {:ok, descriptor} = WidgetRegistry.descriptor(updated_registry, "custom.acme.console")
    assert descriptor.origin == "custom"
    assert {:ok, entry} = WidgetRegistry.entry(updated_registry, "custom.acme.console")
    assert entry.origin == "custom"
    assert entry.implementation_ref == "WebUi.CustomWidgets.AcmeConsole"

    assert {:ok, implementation_ref} = WidgetRegistry.implementation_ref(updated_registry, "custom.acme.console")
    assert implementation_ref == "WebUi.CustomWidgets.AcmeConsole"
  end

  test "capability registry exposes supported extension permissions" do
    capability_registry = WidgetRegistry.capability_registry()

    assert capability_registry["emit_widget_events"].version == 1
    assert capability_registry["read_view_state"].version == 1
    assert capability_registry["request_js_interop"].version == 1
  end

  test "reserved built-in IDs are rejected for custom registration" do
    {:ok, registry} = WidgetRegistry.new()
    request = put_in(base_request(), [:descriptor, :widget_id], "button")

    assert {:error, %TypedError{} = error} = WidgetRegistry.register_custom(registry, request)
    assert error.error_code == "widget_registry.reserved_widget_id"
  end

  test "duplicate custom IDs are rejected with typed conflict errors" do
    {:ok, registry} = WidgetRegistry.new()
    assert {:ok, registry} = WidgetRegistry.register_custom(registry, base_request())

    assert {:error, %TypedError{} = error} = WidgetRegistry.register_custom(registry, base_request())
    assert error.error_code == "widget_registry.duplicate_custom_widget_id"
    assert error.category == "conflict"
  end

  test "invalid props schema is rejected for custom descriptors" do
    {:ok, registry} = WidgetRegistry.new()

    request =
      base_request()
      |> put_in([:descriptor, :props_schema], %{type: "array"})

    assert {:error, %TypedError{} = error} = WidgetRegistry.register_custom(registry, request)
    assert error.error_code == "widget_registry.invalid_custom_props_schema"
  end

  test "invalid custom event naming is rejected" do
    {:ok, registry} = WidgetRegistry.new()

    request =
      base_request()
      |> put_in([:descriptor, :event_schema, :event_types], ["acme.console.selected"])

    assert {:error, %TypedError{} = error} = WidgetRegistry.register_custom(registry, request)
    assert error.error_code == "widget_registry.invalid_custom_event_schema"
  end

  test "unsupported custom capabilities are rejected with typed validation errors" do
    {:ok, registry} = WidgetRegistry.new()
    request = put_in(base_request(), [:descriptor, :capabilities], ["unknown_capability@1"])

    assert {:error, %TypedError{} = error} = WidgetRegistry.register_custom(registry, request)
    assert error.error_code == "widget_registry.unsupported_custom_capability"
  end

  test "capability version mismatches are rejected" do
    {:ok, registry} = WidgetRegistry.new()
    request = put_in(base_request(), [:descriptor, :capabilities], ["emit_widget_events@2"])

    assert {:error, %TypedError{} = error} = WidgetRegistry.register_custom(registry, request)
    assert error.error_code == "widget_registry.custom_capability_version_mismatch"
  end

  test "custom origin is required for custom registration" do
    {:ok, registry} = WidgetRegistry.new()
    request = put_in(base_request(), [:descriptor, :origin], "builtin")

    assert {:error, %TypedError{} = error} = WidgetRegistry.register_custom(registry, request)
    assert error.error_code == "widget_registry.invalid_custom_origin"
  end
end
