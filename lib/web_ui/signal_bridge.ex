defmodule WebUi.SignalBridge do
  @moduledoc """
  Bridge utilities between wire-format CloudEvent maps and `Jido.Signal`.

  The frontend wire protocol currently uses CloudEvents `specversion: "1.0"`.
  Internally, `Jido.Signal` expects `specversion: "1.0.2"`.
  """

  alias Jido.Signal

  @wire_specversion "1.0"
  @internal_specversion "1.0.2"

  @spec from_cloudevent_map(map()) :: {:ok, Signal.t()} | {:error, term()}
  def from_cloudevent_map(cloud_event) when is_map(cloud_event) do
    cloud_event
    |> stringify_top_level_keys()
    |> normalize_for_signal()
    |> Signal.from_map()
  end

  def from_cloudevent_map(_), do: {:error, :invalid_cloudevent_format}

  @spec to_cloudevent_map(Signal.t()) :: map()
  def to_cloudevent_map(%Signal{} = signal) do
    %{
      "specversion" => @wire_specversion,
      "id" => signal.id,
      "source" => signal.source,
      "type" => signal.type,
      "data" => signal.data || %{}
    }
    |> maybe_put("time", signal.time)
    |> maybe_put("subject", signal.subject)
    |> maybe_put("datacontenttype", signal.datacontenttype)
    |> maybe_put("dataschema", signal.dataschema)
  end

  defp stringify_top_level_keys(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), value)
    end)
  end

  defp normalize_for_signal(event_map) do
    event_map
    |> Map.put("specversion", @internal_specversion)
    |> Map.put_new("data", %{})
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
