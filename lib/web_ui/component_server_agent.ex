defmodule WebUi.ComponentServerAgent do
  @moduledoc """
  Behaviour for backend component agents that consume and emit `Jido.Signal`.

  Frontend components communicate via CloudEvents JSON. The channel converts those
  events to `Jido.Signal` structs, dispatches to a component server agent, and
  converts resulting signals back to CloudEvents for the wire.
  """

  @callback handles?(Jido.Signal.t()) :: boolean()
  @callback handle_signal(Jido.Signal.t()) ::
              :unhandled | {:ok, Jido.Signal.t() | [Jido.Signal.t()]} | {:error, term()}
end
