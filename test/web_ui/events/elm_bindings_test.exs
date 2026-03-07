defmodule WebUi.Events.ElmBindingsTest do
  use ExUnit.Case, async: true

  alias WebUi.Events.ElmBindings
  alias WebUi.TypedError

  test "standard Html bindings produce canonical widget events" do
    assert {:ok, click_event} = ElmBindings.on_click("save_button", "button", %{action: "save"})
    assert click_event.type == "unified.button.clicked"
    assert click_event.widget_id == "save_button"
    assert click_event.data.action == "save"
    assert click_event.meta.binding == "Html.Events.onClick"

    assert {:ok, input_event} = ElmBindings.on_input("email_input", "text_input", "person@example.com")
    assert input_event.type == "unified.input.changed"
    assert input_event.data.value == "person@example.com"
    assert input_event.data.input_id == "email_input"

    assert {:ok, focus_event} = ElmBindings.on_focus("search_input", "text_input")
    assert focus_event.type == "unified.element.focused"
    assert focus_event.data.widget_id == "search_input"

    assert {:ok, blur_event} = ElmBindings.on_blur("search_input", "text_input")
    assert blur_event.type == "unified.element.blurred"
    assert blur_event.data.widget_id == "search_input"
  end

  test "submit binding carries Elm-compatible prevent-default semantics" do
    assert {:ok, submit_event} = ElmBindings.on_submit("login_form", "form")
    assert submit_event.type == "unified.form.submitted"
    assert submit_event.data.form_id == "login_form"
    assert submit_event.meta.binding == "Html.Events.onSubmit"
    assert submit_event.meta.prevent_default == true
  end

  test "decoder helpers map keyboard and pointer payloads to canonical events" do
    assert {:ok, action_event} =
             ElmBindings.decode_action_key(
               "table_1",
               "table",
               %{"key" => "Enter", "code" => "Enter", "ctrlKey" => true},
               %{target_id: "row-4"}
             )

    assert action_event.type == "unified.action.requested"
    assert action_event.data.action == "Enter"
    assert action_event.data.code == "Enter"
    assert action_event.data.ctrl_key == true
    assert action_event.data.target_id == "row-4"

    assert {:ok, pointer_event} =
             ElmBindings.decode_canvas_pointer(
               "chart_canvas",
               %{"clientX" => 32, "clientY" => 64, "type" => "move", "pointerId" => "p-1"}
             )

    assert pointer_event.type == "unified.canvas.pointer.changed"
    assert pointer_event.data.x == 32
    assert pointer_event.data.y == 64
    assert pointer_event.data.phase == "move"
    assert pointer_event.data.pointer_id == "p-1"
  end

  test "resize binding maps Browser.Events.onResize to viewport resized events" do
    assert {:ok, event} = ElmBindings.on_resize("main_viewport", "viewport", 144, 55)
    assert event.type == "unified.viewport.resized"
    assert event.data.width == 144
    assert event.data.height == 55
    assert event.meta.binding == "Browser.Events.onResize"
  end

  test "subscription generation and reconciliation are deterministic" do
    desired =
      ElmBindings.subscription_specs("main_viewport", "viewport",
        resize: true,
        keyboard_actions: true,
        canvas_pointer: true
      )

    current = [List.first(desired)]

    transition_a = ElmBindings.reconcile_subscriptions(current, desired)
    transition_b = ElmBindings.reconcile_subscriptions(Enum.reverse(current), Enum.reverse(desired))

    assert transition_a == transition_b
    assert length(transition_a.subscribe) == 2
    assert transition_a.unsubscribe == []
    assert Enum.map(transition_a.active, & &1.subscription_id) ==
             Enum.sort(Enum.map(desired, & &1.subscription_id))
  end

  test "invalid decoder payloads fail with typed errors" do
    assert {:error, %TypedError{} = key_error} = ElmBindings.decode_action_key("table_1", "table", %{})
    assert key_error.error_code == "elm_bindings.invalid_key_event"

    assert {:error, %TypedError{} = pointer_error} = ElmBindings.decode_canvas_pointer("canvas_1", %{"x" => 10})
    assert pointer_error.error_code == "elm_bindings.invalid_pointer_event"
  end
end
