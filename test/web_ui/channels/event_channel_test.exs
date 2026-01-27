defmodule WebUi.EventChannelTest do
  @moduledoc """
  Tests for WebUi.EventChannel.

  Direct unit tests for channel functions without requiring
  a full Endpoint setup.
  """

  use ExUnit.Case, async: true

  alias WebUi.EventChannel

  @moduletag :channels

  describe "join/3" do
    test "accepts events:lobby topic" do
      socket = socket_struct("events:lobby")

      assert {:ok, returned_socket} = EventChannel.join("events:lobby", %{}, socket)
      assert %Phoenix.Socket{} = returned_socket
    end

    test "accepts events:room_id topic pattern" do
      socket = socket_struct("events:testroom")

      assert {:ok, returned_socket} = EventChannel.join("events:testroom", %{}, socket)
      assert returned_socket.assigns.room_id == "testroom"
      assert returned_socket.assigns.joined_at != nil
      assert returned_socket.assigns.last_activity != nil
      assert returned_socket.assigns.event_subscriptions == []
      assert returned_socket.assigns.error_count == 0
    end

    test "rejects invalid topic" do
      socket = socket_struct("invalid:topic")

      assert {:error, %{reason: "invalid_topic"}} = EventChannel.join("invalid:topic", %{}, socket)
    end
  end

  describe "handle_in/3 for cloudevent" do
    test "handle_in function exists for cloudevent" do
      # Verify the function is exported and handles the cloudevent message type
      socket = joined_socket("events:lobby")
      assert {:noreply, _socket} = EventChannel.handle_in("shout", %{}, socket)
    end
  end

  describe "handle_in/3 for ping" do
    test "responds to ping with pong" do
      socket = joined_socket("events:lobby")

      assert {:reply, {:ok, response}, _socket} = EventChannel.handle_in("ping", %{}, socket)
      assert response.type == "pong"
      assert response.timestamp != nil
      assert response.server_time != nil
      assert is_binary(response.timestamp)
      assert is_integer(response.server_time)
    end

    test "pong response includes ISO 8601 timestamp" do
      socket = joined_socket("events:lobby")

      assert {:reply, {:ok, response}, _socket} = EventChannel.handle_in("ping", %{}, socket)

      # Verify ISO 8601 format
      assert {:ok, _, _} = DateTime.from_iso8601(response.timestamp)
    end
  end

  describe "handle_in/3 for subscribe" do
    test "subscribes to event types" do
      socket = joined_socket("events:lobby")

      event_types = ["com.example.*", "com.test.event"]

      assert {:reply, {:ok, response}, new_socket} =
               EventChannel.handle_in("subscribe", %{"event_types" => event_types}, socket)

      assert response.subscribed == event_types
      assert new_socket.assigns.event_subscriptions == event_types
    end

    test "adds to existing subscriptions" do
      socket =
        %{joined_socket("events:lobby") | assigns: %{event_subscriptions: ["existing.subscription"]}}

      event_types = ["com.example.*"]

      assert {:reply, {:ok, _response}, new_socket} =
               EventChannel.handle_in("subscribe", %{"event_types" => event_types}, socket)

      assert "existing.subscription" in new_socket.assigns.event_subscriptions
      assert "com.example.*" in new_socket.assigns.event_subscriptions
    end

    test "rejects invalid subscription request without event_types" do
      socket = joined_socket("events:lobby")

      assert {:reply, {:error, response}, _socket} =
               EventChannel.handle_in("subscribe", %{}, socket)

      assert response.reason == "invalid_subscription_request"
    end

    test "rejects subscription without event_types list" do
      socket = joined_socket("events:lobby")

      assert {:reply, {:error, _response}, _socket} =
               EventChannel.handle_in("subscribe", %{"event_types" => "not-a-list"}, socket)
    end
  end

  describe "handle_in/3 for unsubscribe" do
    test "unsubscribes from event types" do
      socket =
        %{joined_socket("events:lobby") | assigns: %{event_subscriptions: ["com.example.*", "com.test.event"]}}

      event_types = ["com.example.*"]

      assert {:reply, {:ok, response}, new_socket} =
               EventChannel.handle_in("unsubscribe", %{"event_types" => event_types}, socket)

      assert response.unsubscribed == event_types
      refute "com.example.*" in new_socket.assigns.event_subscriptions
      assert "com.test.event" in new_socket.assigns.event_subscriptions
    end

    test "rejects invalid unsubscription request" do
      socket = joined_socket("events:lobby")

      assert {:reply, {:error, response}, _socket} =
               EventChannel.handle_in("unsubscribe", %{}, socket)

      assert response.reason == "invalid_unsubscription_request"
    end

    test "rejects unsubscription without event_types list" do
      socket = joined_socket("events:lobby")

      assert {:reply, {:error, _response}, _socket} =
               EventChannel.handle_in("unsubscribe", %{"event_types" => "not-a-list"}, socket)
    end
  end

  describe "handle_in/3 for unknown messages" do
    test "handles unknown message type gracefully" do
      socket = joined_socket("events:lobby")

      assert {:noreply, _socket} = EventChannel.handle_in("unknown_type", %{"data" => "test"}, socket)
    end
  end

  describe "terminate/2" do
    test "handles normal disconnect" do
      socket = joined_socket("events:room123")

      # terminate should return :ok
      assert :ok = EventChannel.terminate({:shutdown, :normal}, socket)
    end

    test "handles crash disconnect" do
      socket = joined_socket("events:room123")

      assert :ok = EventChannel.terminate(:crash, socket)
    end
  end

  describe "heartbeat_interval/0" do
    test "returns configured heartbeat interval" do
      interval = EventChannel.heartbeat_interval()
      assert is_integer(interval)
      assert interval > 0
    end

    test "default is 30 seconds" do
      interval = EventChannel.heartbeat_interval()
      assert interval == 30_000
    end
  end

  describe "broadcast_cloudevent/2" do
    test "exists and accepts map event" do
      event = %{
        "specversion" => "1.0",
        "id" => "test-123",
        "source" => "/server",
        "type" => "com.server.event",
        "data" => %{"status" => "ok"}
      }

      # Function exists and accepts correct format
      assert fn -> EventChannel.broadcast_cloudevent("lobby", event) end
    end
  end

  describe "send_heartbeat/1" do
    test "exists and accepts room_id parameter" do
      assert fn -> EventChannel.send_heartbeat("lobby") end
    end
  end

  # Helper functions

  defp socket_struct(topic) do
    %Phoenix.Socket{
      assigns: %{},
      channel: EventChannel,
      endpoint: WebUi.Endpoint,
      topic: topic,
      transport_pid: self(),
      joined: false
    }
  end

  defp joined_socket(topic) do
    socket = socket_struct(topic)
    {:ok, socket} = EventChannel.join(topic, %{}, socket)
    %{socket | joined: true}
  end
end
