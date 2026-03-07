defmodule WebUi.Ui.Runtime do
  @moduledoc """
  UI runtime bootstrap contracts mirroring Elm init command flow.
  """

  alias WebUi.Transport.Naming
  alias WebUi.TypedError
  alias WebUi.Ui.Model

  @spec init(map()) :: {:ok, Model.t(), [map()]}
  def init(opts \\ %{}) when is_map(opts) do
    model =
      opts
      |> Model.new()
      |> Map.put(:connection_state, :connecting)
      |> Map.update!(:view_state, &Map.put(&1, :screen, :connecting))

    commands = [join_command(model.transport.topic), ping_command(model.runtime_context)]

    {:ok, model, commands}
  end

  @spec join_command(String.t()) :: map()
  def join_command(topic) when is_binary(topic) do
    %{
      kind: :ws_join,
      topic: topic,
      expected_events: Naming.server_events()
    }
  end

  @spec ping_command(map()) :: map()
  def ping_command(runtime_context) when is_map(runtime_context) do
    %{
      kind: :ws_push,
      event_name: "runtime.event.ping.v1",
      payload: %{
        correlation_id: Map.get(runtime_context, :correlation_id),
        request_id: Map.get(runtime_context, :request_id)
      }
    }
  end

  @spec handle_bootstrap_result(Model.t(), {:ok, map()} | {:error, term()}) :: Model.t()
  def handle_bootstrap_result(%Model{} = model, {:ok, payload}) when is_map(payload) do
    model
    |> Map.put(:connection_state, :connected)
    |> Map.update!(:view_state, fn view_state ->
      view_state
      |> Map.put(:screen, :ready)
      |> Map.put(:ui_error, nil)
    end)
    |> Map.update!(:transport, &Map.put(&1, :joined?, true))
    |> Map.update!(:inbound_history, fn history -> [%{event: :ws_joined, payload: payload} | history] end)
  end

  def handle_bootstrap_result(%Model{} = model, {:error, reason}) do
    typed_error = normalize_join_error(reason, model.runtime_context)

    model
    |> Map.put(:connection_state, :error)
    |> Map.update!(:view_state, fn view_state ->
      view_state
      |> Map.put(:screen, :error)
      |> Map.put(:ui_error, %{code: typed_error.error_code, message: "Channel bootstrap failed"})
    end)
    |> Map.put(:last_error, typed_error)
    |> Map.update!(:transport, &Map.put(&1, :joined?, false))
    |> Map.update!(:inbound_history, fn history ->
      [%{event: :ws_join_failed, payload: %{error_code: typed_error.error_code}} | history]
    end)
  end

  defp normalize_join_error(%TypedError{} = error, _runtime_context), do: error

  defp normalize_join_error(reason, runtime_context) do
    TypedError.new(
      "ui.bootstrap_join_failed",
      "protocol",
      true,
      %{reason: inspect(reason)},
      Map.get(runtime_context, :correlation_id, "unknown")
    )
  end
end
