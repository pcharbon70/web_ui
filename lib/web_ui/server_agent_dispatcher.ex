defmodule WebUi.ServerAgentDispatcher do
  @moduledoc """
  Routes `Jido.Signal` events to configured backend targets.

  Supported target types:

  - legacy callback modules configured under `:agents` (must export `handles?/1` and `handle_signal/1`)
  - `Jido.Agent.Server` processes configured under `:jido_servers`
  """

  alias Jido.Agent.Server, as: JidoAgentServer
  alias Jido.Signal
  alias Jido.Signal.Error, as: JidoSignalError

  @type jido_server_ref :: pid() | atom() | String.t() | {atom() | String.t(), module()}
  @type dispatch_target :: {:legacy_agent, module()} | {:jido_server, jido_server_ref()}
  @type dispatch_result :: :unhandled | {:ok, [Signal.t()]} | {:error, term()}
  @default_jido_timeout 5_000

  @spec dispatch(Signal.t()) :: dispatch_result()
  def dispatch(%Signal{} = signal) do
    Enum.reduce_while(configured_targets(), :unhandled, fn target, _acc ->
      case dispatch_to_target(target, signal) do
        :skip ->
          {:cont, :unhandled}

        :unhandled ->
          {:cont, :unhandled}

        {:ok, signals} ->
          {:halt, {:ok, signals}}

        {:error, reason} ->
          {:halt, {:error, {target_identifier(target), reason}}}
      end
    end)
  end

  def dispatch(_), do: {:error, :invalid_signal}

  @spec configured_agents() :: [module()]
  def configured_agents do
    Application.get_env(:web_ui, __MODULE__, [])
    |> Keyword.get(:agents, [])
  end

  @spec configured_jido_servers() :: [jido_server_ref()]
  def configured_jido_servers do
    Application.get_env(:web_ui, __MODULE__, [])
    |> Keyword.get(:jido_servers, [])
    |> Enum.flat_map(&normalize_jido_server/1)
  end

  @spec configured_targets() :: [dispatch_target()]
  def configured_targets do
    legacy_targets = Enum.map(configured_agents(), &{:legacy_agent, &1})
    jido_targets = Enum.map(configured_jido_servers(), &{:jido_server, &1})
    legacy_targets ++ jido_targets
  end

  defp target_identifier({:legacy_agent, module}), do: module
  defp target_identifier({:jido_server, server_ref}), do: server_ref

  defp dispatch_to_target({:legacy_agent, agent_module}, %Signal{} = signal) do
    with true <- Code.ensure_loaded?(agent_module),
         true <- function_exported?(agent_module, :handles?, 1),
         true <- function_exported?(agent_module, :handle_signal, 1),
         true <- agent_module.handles?(signal) do
      case agent_module.handle_signal(signal) do
        :unhandled ->
          :unhandled

        {:ok, generated} ->
          normalize_generated_signals(generated)

        {:error, reason} ->
          {:error, reason}

        other ->
          {:error, {:invalid_agent_response, inspect(other)}}
      end
    else
      false -> :skip
    end
  end

  defp dispatch_to_target({:legacy_agent, _agent_module}, _signal), do: :skip

  defp dispatch_to_target({:jido_server, server_ref}, %Signal{} = signal) do
    case JidoAgentServer.call(server_ref, signal, jido_timeout()) do
      {:ok, generated} ->
        normalize_generated_signals(generated)

      {:error, :no_matching_route} ->
        :unhandled

      {:error, %JidoSignalError{type: :routing_error}} ->
        :unhandled

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    exception ->
      {:error, {:jido_server_call_failed, Exception.message(exception)}}
  catch
    kind, reason ->
      {:error, {:jido_server_call_failed, {kind, reason}}}
  end

  defp dispatch_to_target({:jido_server, _server_ref}, _signal), do: :skip

  defp normalize_jido_server(server_ref)
       when is_pid(server_ref) or is_atom(server_ref) or is_binary(server_ref) do
    [server_ref]
  end

  defp normalize_jido_server({name, registry} = server_ref)
       when (is_atom(name) or is_binary(name)) and is_atom(registry) do
    [server_ref]
  end

  defp normalize_jido_server(%{server: server_ref}), do: normalize_jido_server(server_ref)

  defp normalize_jido_server(server_opts) when is_list(server_opts) do
    case Keyword.fetch(server_opts, :server) do
      {:ok, server_ref} -> normalize_jido_server(server_ref)
      :error -> []
    end
  end

  defp normalize_jido_server(_), do: []

  defp jido_timeout do
    Application.get_env(:web_ui, __MODULE__, [])
    |> Keyword.get(:jido_timeout, @default_jido_timeout)
  end

  defp normalize_generated_signals(%Signal{} = signal), do: {:ok, [signal]}

  defp normalize_generated_signals(signals) when is_list(signals) do
    if Enum.all?(signals, &match?(%Signal{}, &1)) do
      {:ok, signals}
    else
      {:error, :generated_signals_must_be_jido_signals}
    end
  end

  defp normalize_generated_signals(_), do: {:error, :generated_signals_must_be_jido_signals}
end
