defmodule WebUi.ServerAgentDispatcher do
  @moduledoc """
  Routes `Jido.Signal` events to configured component server agents.
  """

  alias Jido.Signal

  @type dispatch_result :: :unhandled | {:ok, [Signal.t()]} | {:error, term()}

  @spec dispatch(Signal.t()) :: dispatch_result()
  def dispatch(%Signal{} = signal) do
    Enum.reduce_while(configured_agents(), :unhandled, fn agent_module, _acc ->
      case dispatch_to_agent(agent_module, signal) do
        :skip ->
          {:cont, :unhandled}

        :unhandled ->
          {:cont, :unhandled}

        {:ok, signals} ->
          {:halt, {:ok, signals}}

        {:error, reason} ->
          {:halt, {:error, {agent_module, reason}}}
      end
    end)
  end

  def dispatch(_), do: {:error, :invalid_signal}

  @spec configured_agents() :: [module()]
  def configured_agents do
    Application.get_env(:web_ui, __MODULE__, [])
    |> Keyword.get(:agents, [])
  end

  defp dispatch_to_agent(agent_module, %Signal{} = signal) when is_atom(agent_module) do
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

  defp dispatch_to_agent(_agent_module, _signal), do: :skip

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
