defmodule WebUi.Ui.Message do
  @moduledoc """
  Typed UI runtime message envelope mirroring Elm Msg semantics.
  """

  @enforce_keys [:type, :payload]
  defstruct [:type, :payload]

  @type type ::
          :ws_joined
          | :ws_join_failed
          | :ws_event_received
          | :ws_error_received
          | :ws_pong_received
          | :widget_event
          | :port_event

  @type t :: %__MODULE__{type: type(), payload: map()}

  @spec websocket_joined(map()) :: t()
  def websocket_joined(payload \\ %{}) when is_map(payload), do: %__MODULE__{type: :ws_joined, payload: payload}

  @spec websocket_join_failed(map()) :: t()
  def websocket_join_failed(payload) when is_map(payload), do: %__MODULE__{type: :ws_join_failed, payload: payload}

  @spec websocket_recv(map()) :: t()
  def websocket_recv(payload) when is_map(payload), do: %__MODULE__{type: :ws_event_received, payload: payload}

  @spec websocket_error(map()) :: t()
  def websocket_error(payload) when is_map(payload), do: %__MODULE__{type: :ws_error_received, payload: payload}

  @spec websocket_pong(map()) :: t()
  def websocket_pong(payload) when is_map(payload), do: %__MODULE__{type: :ws_pong_received, payload: payload}

  @spec widget_event(map()) :: t()
  def widget_event(payload) when is_map(payload), do: %__MODULE__{type: :widget_event, payload: payload}

  @spec port_event(map()) :: t()
  def port_event(payload) when is_map(payload), do: %__MODULE__{type: :port_event, payload: payload}
end
