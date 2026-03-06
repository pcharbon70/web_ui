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

  @type event_pattern :: String.t()
  @type jido_server_ref :: pid() | atom() | String.t() | {atom() | String.t(), module()}
  @type jido_route :: {event_pattern(), jido_server_ref()}
  @type dispatch_target :: {:legacy_agent, module()} | {:jido_server, jido_server_ref()}
  @type dispatch_result :: :unhandled | {:ok, [Signal.t()]} | {:error, term()}
  @default_jido_timeout 5_000

  @spec dispatch(Signal.t()) :: dispatch_result()
  def dispatch(%Signal{} = signal) do
    case dispatch_to_jido_routes(signal) do
      :no_route_match -> dispatch_to_targets(configured_targets(), signal)
      route_result -> route_result
    end
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

  @spec configured_jido_routes() :: [jido_route()]
  def configured_jido_routes do
    Application.get_env(:web_ui, __MODULE__, [])
    |> Keyword.get(:jido_routes, [])
    |> normalize_jido_routes()
  end

  @spec configured_targets() :: [dispatch_target()]
  def configured_targets do
    legacy_targets = Enum.map(configured_agents(), &{:legacy_agent, &1})
    jido_targets = Enum.map(configured_jido_servers(), &{:jido_server, &1})
    legacy_targets ++ jido_targets
  end

  defp dispatch_to_jido_routes(%Signal{type: type} = signal) when is_binary(type) do
    configured_jido_routes()
    |> Enum.filter(fn {pattern, _server_ref} -> signal_type_matches_pattern?(type, pattern) end)
    |> Enum.map(fn {_pattern, server_ref} -> {:jido_server, server_ref} end)
    |> Enum.uniq()
    |> case do
      [] ->
        :no_route_match

      routed_targets ->
        dispatch_to_targets(routed_targets, signal)
    end
  end

  defp dispatch_to_jido_routes(_signal), do: :no_route_match

  defp dispatch_to_targets(targets, %Signal{} = signal) do
    Enum.reduce_while(targets, :unhandled, fn target, _acc ->
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

  defp normalize_jido_routes(routes) when is_map(routes) do
    Enum.flat_map(routes, fn {pattern, server_ref} ->
      normalize_jido_route_entry(pattern, server_ref)
    end)
  end

  defp normalize_jido_routes(routes) when is_list(routes) do
    Enum.flat_map(routes, fn
      {pattern, server_ref} ->
        normalize_jido_route_entry(pattern, server_ref)

      %{pattern: pattern, server: server_ref} ->
        normalize_jido_route_entry(pattern, server_ref)

      %{"pattern" => pattern, "server" => server_ref} ->
        normalize_jido_route_entry(pattern, server_ref)

      route_opts when is_list(route_opts) ->
        with {:ok, pattern} <- Keyword.fetch(route_opts, :pattern),
             {:ok, server_ref} <- Keyword.fetch(route_opts, :server) do
          normalize_jido_route_entry(pattern, server_ref)
        else
          _ -> []
        end

      _invalid ->
        []
    end)
  end

  defp normalize_jido_routes(_), do: []

  defp normalize_jido_route_entry(pattern, server_ref) when is_binary(pattern) do
    server_ref
    |> normalize_jido_server()
    |> Enum.map(fn normalized_server_ref -> {pattern, normalized_server_ref} end)
  end

  defp normalize_jido_route_entry(_pattern, _server_ref), do: []

  defp signal_type_matches_pattern?(signal_type, pattern)
       when is_binary(signal_type) and is_binary(pattern) do
    if String.contains?(pattern, "*") do
      wildcard_match?(signal_type, pattern)
    else
      signal_type == pattern
    end
  end

  defp signal_type_matches_pattern?(_signal_type, _pattern), do: false

  defp wildcard_match?(signal_type, pattern) do
    pattern
    |> Regex.escape()
    |> String.replace("\\*", ".*")
    |> then(fn escaped_pattern -> Regex.compile!("^#{escaped_pattern}$") end)
    |> Regex.match?(signal_type)
  end

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
