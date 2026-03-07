defmodule WebUi.Persistence.ReplayLog do
  @moduledoc """
  Deterministic replay-log helpers for runtime dispatch and reconciliation traces.
  """

  alias WebUi.TypedError

  @checkpoint_width 6
  @hash_width 10

  @type entry :: %{
          cursor: non_neg_integer(),
          direction: :outbound | :inbound,
          event: String.t(),
          payload_fingerprint: non_neg_integer(),
          metadata: map()
        }

  @type t :: %{
          cursor: non_neg_integer(),
          entries: [entry()],
          last_checkpoint_id: String.t() | nil
        }

  @spec new() :: t()
  def new do
    %{cursor: 0, entries: [], last_checkpoint_id: nil}
  end

  @spec append(t(), map()) :: {:ok, t()} | {:error, TypedError.t()}
  def append(log, attrs) when is_map(log) and is_map(attrs) do
    with :ok <- validate_log(log),
         {:ok, direction} <- normalize_direction(Map.get(attrs, :direction), attrs),
         {:ok, event} <- normalize_event(Map.get(attrs, :event), attrs),
         {:ok, metadata} <- normalize_metadata(Map.get(attrs, :metadata), attrs) do
      next_cursor = Map.get(log, :cursor) + 1

      entry = %{
        cursor: next_cursor,
        direction: direction,
        event: event,
        payload_fingerprint: :erlang.phash2(metadata),
        metadata: metadata
      }

      entries = Map.get(log, :entries, []) ++ [entry]
      checkpoint_id = checkpoint_id(next_cursor, entries)

      {:ok,
       %{
         cursor: next_cursor,
         entries: entries,
         last_checkpoint_id: checkpoint_id
       }}
    end
  end

  def append(_log, attrs) do
    {:error,
     TypedError.new(
       "replay_log.invalid_log_state",
       "validation",
       false,
       %{reason: "log must be a map", attrs: attrs}
     )}
  end

  @spec cursor(t()) :: non_neg_integer()
  def cursor(log) when is_map(log) do
    case Map.get(log, :cursor) do
      value when is_integer(value) and value >= 0 -> value
      _ -> 0
    end
  end

  @spec entries(t()) :: [entry()]
  def entries(log) when is_map(log) do
    case Map.get(log, :entries) do
      value when is_list(value) -> value
      _ -> []
    end
  end

  @spec entries_since(t(), non_neg_integer()) :: [entry()]
  def entries_since(log, from_cursor)
      when is_map(log) and is_integer(from_cursor) and from_cursor >= 0 do
    log
    |> entries()
    |> Enum.filter(fn entry ->
      is_map(entry) and Map.get(entry, :cursor, 0) > from_cursor
    end)
  end

  @spec checkpoint(t()) :: %{cursor: non_neg_integer(), checkpoint_id: String.t() | nil}
  def checkpoint(log) when is_map(log) do
    %{
      cursor: cursor(log),
      checkpoint_id: Map.get(log, :last_checkpoint_id)
    }
  end

  defp validate_log(log) when is_map(log) do
    cond do
      not is_integer(Map.get(log, :cursor)) ->
        invalid_log_error(log, "cursor must be a non-negative integer")

      Map.get(log, :cursor) < 0 ->
        invalid_log_error(log, "cursor must be a non-negative integer")

      not is_list(Map.get(log, :entries)) ->
        invalid_log_error(log, "entries must be a list")

      true ->
        :ok
    end
  end

  defp normalize_direction(direction, _attrs) when direction in [:outbound, :inbound],
    do: {:ok, direction}

  defp normalize_direction(direction, attrs) do
    {:error,
     TypedError.new(
       "replay_log.invalid_entry_shape",
       "validation",
       false,
       %{reason: "direction must be :outbound or :inbound", direction: direction, attrs: attrs}
     )}
  end

  defp normalize_event(event, _attrs) when is_atom(event), do: {:ok, Atom.to_string(event)}

  defp normalize_event(event, _attrs) when is_binary(event) and event != "" do
    {:ok, event}
  end

  defp normalize_event(event, attrs) do
    {:error,
     TypedError.new(
       "replay_log.invalid_entry_shape",
       "validation",
       false,
       %{reason: "event must be a non-empty string or atom", event: event, attrs: attrs}
     )}
  end

  defp normalize_metadata(nil, _attrs), do: {:ok, %{}}
  defp normalize_metadata(metadata, _attrs) when is_map(metadata), do: {:ok, metadata}

  defp normalize_metadata(metadata, attrs) do
    {:error,
     TypedError.new(
       "replay_log.invalid_entry_shape",
       "validation",
       false,
       %{reason: "metadata must be a map", metadata: metadata, attrs: attrs}
     )}
  end

  defp checkpoint_id(cursor, entries)
       when is_integer(cursor) and cursor >= 0 and is_list(entries) do
    cursor_part =
      cursor
      |> Integer.to_string()
      |> String.pad_leading(@checkpoint_width, "0")

    hash_part =
      entries
      |> :erlang.phash2()
      |> Integer.to_string()
      |> String.pad_leading(@hash_width, "0")

    "replay-" <> cursor_part <> "-" <> hash_part
  end

  defp invalid_log_error(log, reason) do
    {:error,
     TypedError.new(
       "replay_log.invalid_log_state",
       "validation",
       false,
       %{reason: reason, log: log}
     )}
  end
end
