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

  @spec snapshot(t(), map()) :: {:ok, map()} | {:error, TypedError.t()}
  def snapshot(log, opts \\ %{})

  def snapshot(log, opts) when is_map(log) and is_map(opts) do
    with :ok <- validate_log(log),
         {:ok, from_cursor} <- normalize_from_cursor(Map.get(opts, :from_cursor, 0), opts),
         {:ok, limit} <- normalize_limit(Map.get(opts, :limit), opts) do
      entries =
        log
        |> entries_since(from_cursor)
        |> maybe_limit_entries(limit)

      {:ok,
       %{
         cursor: cursor(log),
         checkpoint_id: Map.get(log, :last_checkpoint_id),
         entry_count: length(entries),
         entries: entries
       }}
    end
  end

  def snapshot(_log, opts) do
    {:error,
     TypedError.new(
       "replay_log.invalid_log_state",
       "validation",
       false,
       %{reason: "log must be a map", opts: opts}
     )}
  end

  @spec compact(t(), map()) :: {:ok, t()} | {:error, TypedError.t()}
  def compact(log, opts) when is_map(log) and is_map(opts) do
    with :ok <- validate_log(log),
         {:ok, keep_last} <- normalize_keep_last(Map.get(opts, :keep_last), opts) do
      retained_entries =
        log
        |> entries()
        |> Enum.take(-keep_last)

      current_cursor = cursor(log)

      {:ok,
       %{
         cursor: current_cursor,
         entries: retained_entries,
         last_checkpoint_id: checkpoint_id(current_cursor, retained_entries)
       }}
    end
  end

  def compact(_log, opts) do
    {:error,
     TypedError.new(
       "replay_log.invalid_log_state",
       "validation",
       false,
       %{reason: "log must be a map", opts: opts}
     )}
  end

  @spec export(t()) :: {:ok, map()} | {:error, TypedError.t()}
  def export(log) when is_map(log) do
    with :ok <- validate_log(log) do
      {:ok,
       %{
         format: "web_ui.replay_log.export.v1",
         cursor: cursor(log),
         checkpoint_id: Map.get(log, :last_checkpoint_id),
         entries: entries(log)
       }}
    end
  end

  def export(_log) do
    {:error,
     TypedError.new(
       "replay_log.invalid_log_state",
       "validation",
       false,
       %{reason: "log must be a map"}
     )}
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

  defp normalize_from_cursor(from_cursor, _opts)
       when is_integer(from_cursor) and from_cursor >= 0,
       do: {:ok, from_cursor}

  defp normalize_from_cursor(from_cursor, opts) do
    {:error,
     TypedError.new(
       "replay_log.invalid_snapshot_options",
       "validation",
       false,
       %{
         reason: "from_cursor must be a non-negative integer",
         from_cursor: from_cursor,
         opts: opts
       }
     )}
  end

  defp normalize_limit(nil, _opts), do: {:ok, nil}
  defp normalize_limit(limit, _opts) when is_integer(limit) and limit >= 0, do: {:ok, limit}

  defp normalize_limit(limit, opts) do
    {:error,
     TypedError.new(
       "replay_log.invalid_snapshot_options",
       "validation",
       false,
       %{reason: "limit must be a non-negative integer when provided", limit: limit, opts: opts}
     )}
  end

  defp normalize_keep_last(keep_last, _opts)
       when is_integer(keep_last) and keep_last >= 0,
       do: {:ok, keep_last}

  defp normalize_keep_last(keep_last, opts) do
    {:error,
     TypedError.new(
       "replay_log.invalid_compaction_options",
       "validation",
       false,
       %{reason: "keep_last must be a non-negative integer", keep_last: keep_last, opts: opts}
     )}
  end

  defp maybe_limit_entries(entries, nil) when is_list(entries), do: entries
  defp maybe_limit_entries(_entries, 0), do: []

  defp maybe_limit_entries(entries, limit) when is_list(entries) and is_integer(limit),
    do: Enum.take(entries, limit)

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
