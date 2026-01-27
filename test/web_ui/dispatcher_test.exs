defmodule WebUi.DispatcherTest do
  @moduledoc """
  Tests for WebUi.Dispatcher.
  """

  use ExUnit.Case, async: false

  alias WebUi.{CloudEvent, Dispatcher}
  alias WebUi.Dispatcher.Registry

  setup do
    # Ensure the registry is started for each test
    start_supervised!(Registry)

    # Start a fresh dispatcher for each test
    {:ok, pid} = start_supervised({Dispatcher, name: :test_dispatcher})
    {:ok, dispatcher: pid}
  end

  describe "subscribe/3" do
    test "subscribes with exact type pattern" do
      handler = fn _event -> :ok end
      assert {:ok, sub_id} = Dispatcher.subscribe("com.example.event", handler)
      assert is_reference(sub_id)
    end

    test "subscribes with prefix wildcard" do
      handler = fn _event -> :ok end
      assert {:ok, sub_id} = Dispatcher.subscribe("com.example.*", handler)
      assert is_reference(sub_id)
    end

    test "subscribes with suffix wildcard" do
      handler = fn _event -> :ok end
      assert {:ok, sub_id} = Dispatcher.subscribe("*.event", handler)
      assert is_reference(sub_id)
    end

    test "subscribes with full wildcard" do
      handler = fn _event -> :ok end
      assert {:ok, sub_id} = Dispatcher.subscribe("*", handler)
      assert is_reference(sub_id)
    end

    test "subscribes with module/function handler" do
      assert {:ok, sub_id} = Dispatcher.subscribe("com.example.event", {TestHandler, :handle})
      assert is_reference(sub_id)
    end

    test "subscribes with filter option" do
      filter = fn %CloudEvent{source: src} -> src == "/allowed" end
      handler = fn _event -> :ok end

      assert {:ok, sub_id} =
               Dispatcher.subscribe("com.example.*", handler, filter: filter)

      assert is_reference(sub_id)
    end

    test "subscribes multiple handlers to same pattern" do
      handler1 = fn _event -> :ok end
      handler2 = fn _event -> :ok end

      assert {:ok, sub_id1} = Dispatcher.subscribe("com.example.*", handler1)
      assert {:ok, sub_id2} = Dispatcher.subscribe("com.example.*", handler2)

      assert sub_id1 != sub_id2
    end
  end

  describe "unsubscribe/1" do
    test "unsubscribes a handler" do
      handler = fn _event -> :ok end
      {:ok, sub_id} = Dispatcher.subscribe("com.example.*", handler)

      assert :ok = Dispatcher.unsubscribe(sub_id)
      # Handler should no longer receive events
    end

    test "handles unsubscribe of non-existent subscription gracefully" do
      sub_id = make_ref()
      assert :ok = Dispatcher.unsubscribe(sub_id)
    end
  end

  describe "dispatch/1" do
    test "delivers event to exact match handler" do
      parent = self()
      handler = fn %CloudEvent{id: id} -> send(parent, {:handled, id}) end

      {:ok, _sub_id} = Dispatcher.subscribe("com.example.event", handler)

      event = event_with_type("com.example.event")
      assert :ok = Dispatcher.dispatch(event)

      assert_receive {:handled, _id}
    end

    test "delivers event to prefix wildcard handler" do
      parent = self()
      handler = fn %CloudEvent{id: id} -> send(parent, {:handled, id}) end

      {:ok, _sub_id} = Dispatcher.subscribe("com.example.*", handler)

      event = event_with_type("com.example.specific")
      assert :ok = Dispatcher.dispatch(event)

      assert_receive {:handled, _id}
    end

    test "delivers event to suffix wildcard handler" do
      parent = self()
      handler = fn %CloudEvent{id: id} -> send(parent, {:handled, id}) end

      {:ok, _sub_id} = Dispatcher.subscribe("*.created", handler)

      event = event_with_type("com.example.created")
      assert :ok = Dispatcher.dispatch(event)

      assert_receive {:handled, _id}
    end

    test "delivers event to full wildcard handler" do
      parent = self()
      handler = fn %CloudEvent{id: id} -> send(parent, {:handled, id}) end

      {:ok, _sub_id} = Dispatcher.subscribe("*", handler)

      event = event_with_type("anything.event")
      assert :ok = Dispatcher.dispatch(event)

      assert_receive {:handled, _id}
    end

    test "delivers event to multiple matching handlers" do
      parent = self()
      handler1 = fn %CloudEvent{id: id} -> send(parent, {:handler1, id}) end
      handler2 = fn %CloudEvent{id: id} -> send(parent, {:handler2, id}) end

      {:ok, _sub1} = Dispatcher.subscribe("com.example.*", handler1)
      {:ok, _sub2} = Dispatcher.subscribe("com.example.event", handler2)

      event = event_with_type("com.example.event")
      assert :ok = Dispatcher.dispatch(event)

      assert_receive {:handler1, _id}
      assert_receive {:handler2, _id}
    end

    test "respects filter function" do
      parent = self()
      filter = fn %CloudEvent{source: src} -> src == "/allowed" end
      handler = fn %CloudEvent{id: id} -> send(parent, {:handled, id}) end

      {:ok, _sub_id} = Dispatcher.subscribe("*", handler, filter: filter)

      # Event with blocked source
      event1 = event_with_type("test.event", source: "/blocked")
      assert :ok = Dispatcher.dispatch(event1)
      refute_receive {:handled, _}, 100

      # Event with allowed source
      event2 = event_with_type("test.event", source: "/allowed")
      assert :ok = Dispatcher.dispatch(event2)
      assert_receive {:handled, _id2}
    end

    test "does not deliver to non-matching handlers" do
      parent = self()
      handler = fn %CloudEvent{id: id} -> send(parent, {:handled, id}) end

      {:ok, _sub_id} = Dispatcher.subscribe("com.other.*", handler)

      event = event_with_type("com.example.event")
      assert :ok = Dispatcher.dispatch(event)

      refute_receive {:handled, _}, 100
    end

    test "handles handler crash gracefully" do
      parent = self()
      crashing_handler = fn _ -> raise "handler crash" end
      working_handler = fn %CloudEvent{id: id} -> send(parent, {:handled, id}) end

      {:ok, _sub1} = Dispatcher.subscribe("com.example.*", crashing_handler)
      {:ok, _sub2} = Dispatcher.subscribe("com.example.event", working_handler)

      event = event_with_type("com.example.event")
      assert :ok = Dispatcher.dispatch(event)

      # Working handler should still receive event
      assert_receive {:handled, _id}
    end

    test "handles filter function crash gracefully" do
      parent = self()
      filter = fn _ -> raise "filter crash" end
      handler = fn %CloudEvent{id: id} -> send(parent, {:handled, id}) end

      {:ok, _sub_id} = Dispatcher.subscribe("*", handler, filter: filter)

      event = event_with_type("test.event")
      assert :ok = Dispatcher.dispatch(event)

      # Filter crash should not deliver event
      refute_receive {:handled, _}, 100
    end
  end

  describe "subscription_count/0" do
    test "returns 0 when no subscriptions" do
      assert Dispatcher.subscription_count() == 0
    end

    test "returns count of active subscriptions" do
      handler = fn _event -> :ok end

      {:ok, _sub1} = Dispatcher.subscribe("com.example.*", handler)
      assert Dispatcher.subscription_count() == 1

      {:ok, _sub2} = Dispatcher.subscribe("com.test.event", handler)
      assert Dispatcher.subscription_count() == 2
    end

    test "decreases after unsubscribe" do
      handler = fn _event -> :ok end

      {:ok, sub_id} = Dispatcher.subscribe("com.example.*", handler)
      assert Dispatcher.subscription_count() == 1

      Dispatcher.unsubscribe(sub_id)
      assert Dispatcher.subscription_count() == 0
    end
  end

  describe "module/function handler" do
    defmodule TestHandler do
      def handle(%CloudEvent{id: id}) do
        send(parent(), {:handled, id})
      end

      def handle(_), do: :ok

      def set_parent(pid), do: Process.put(:parent, pid)

      defp parent, do: Process.get(:parent)
    end

    setup do
      parent = self()
      TestHandler.set_parent(parent)
      :ok
    end

    test "calls module/function handler" do
      {:ok, _sub_id} = Dispatcher.subscribe("com.example.*", {TestHandler, :handle})

      event = event_with_type("com.example.event")
      assert :ok = Dispatcher.dispatch(event)

      assert_receive {:handled, _id}
    end
  end

  describe "gen_server handler" do
    defmodule TestGenServer do
      use GenServer

      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts)
      end

      @impl true
      def init(opts) do
        {:ok, %{parent: Keyword.get(opts, :parent)}}
      end

      @impl true
      def handle_cast({:cloudevent, %CloudEvent{id: id}}, state) do
        send(state.parent, {:handled, id})
        {:noreply, state}
      end
    end

    setup do
      {:ok, pid} = start_supervised({TestGenServer, parent: self()})
      %{pid: pid}
    end

    test "sends cast to GenServer handler", %{pid: pid} do
      {:ok, _sub_id} = Dispatcher.subscribe("com.example.*", pid)

      event = event_with_type("com.example.event")
      assert :ok = Dispatcher.dispatch(event)

      assert_receive {:handled, _id}
    end
  end

  describe "subscriptions/0" do
    test "returns all subscriptions" do
      handler = fn _event -> :ok end
      {:ok, sub_id} = Dispatcher.subscribe("com.example.*", handler)

      subs = Dispatcher.subscriptions()
      assert length(subs) > 0

      {pattern, ^handler, ^sub_id, opts} = List.first(subs)
      assert pattern == "com.example.*"
      assert Keyword.has_key?(opts, :metadata)
    end
  end

  describe "clear/0" do
    test "clears all subscriptions" do
      handler = fn _event -> :ok end
      {:ok, _sub_id} = Dispatcher.subscribe("com.example.*", handler)

      assert Dispatcher.subscription_count() > 0
      Dispatcher.clear()
      assert Dispatcher.subscription_count() == 0
    end
  end

  # Helper functions

  defp event_with_type(type, opts \\ []) do
    source = Keyword.get(opts, :source, "/test/source")
    id = Keyword.get(opts, :id, CloudEvent.generate_id())

    %CloudEvent{
      specversion: "1.0",
      id: id,
      source: source,
      type: type,
      data: %{}
    }
  end
end
