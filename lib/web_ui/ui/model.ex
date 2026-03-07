defmodule WebUi.Ui.Model do
  @moduledoc """
  Deterministic UI runtime model baseline used to mirror Elm Model semantics.
  """

  alias WebUi.Transport.Naming

  @type connection_state :: :disconnected | :connecting | :connected | :error

  @enforce_keys [:connection_state, :runtime_context, :view_state, :transport]
  defstruct [
    :connection_state,
    :runtime_context,
    :view_state,
    :transport,
    :last_error,
    outbound_queue: [],
    inbound_history: [],
    telemetry_events: []
  ]

  @type t :: %__MODULE__{
          connection_state: connection_state(),
          runtime_context: map(),
          view_state: map(),
          transport: map(),
          last_error: map() | nil,
          outbound_queue: [map()],
          inbound_history: [map()],
          telemetry_events: [map()]
        }

  @default_runtime_context %{
    correlation_id: "bootstrap-correlation",
    request_id: "bootstrap-request",
    session_id: nil,
    client_id: nil,
    user_id: nil,
    trace_id: nil
  }

  @default_view_state %{
    screen: :booting,
    ui_error: nil,
    notices: []
  }

  @default_transport %{
    topic: Naming.default_topic(),
    joined?: false,
    last_pong_at: nil
  }

  @spec new(map()) :: t()
  def new(opts \\ %{}) when is_map(opts) do
    runtime_context = Map.merge(@default_runtime_context, Map.get(opts, :runtime_context, %{}))
    view_state = Map.merge(@default_view_state, Map.get(opts, :view_state, %{}))
    transport = Map.merge(@default_transport, Map.get(opts, :transport, %{}))

    %__MODULE__{
      connection_state: Map.get(opts, :connection_state, :disconnected),
      runtime_context: runtime_context,
      view_state: view_state,
      transport: transport,
      last_error: Map.get(opts, :last_error),
      outbound_queue: Map.get(opts, :outbound_queue, []),
      inbound_history: Map.get(opts, :inbound_history, []),
      telemetry_events: Map.get(opts, :telemetry_events, [])
    }
  end
end
