defmodule WebUi.Persistence.ReplayLog do
  @moduledoc """
  Deterministic replay-log helpers for runtime dispatch and reconciliation traces.
  """

  alias WebUi.TypedError

  @export_format "web_ui.replay_log.export.v1"
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
      checkpoint_id = restored_checkpoint_id(cursor(log), entries(log))

      {:ok,
       %{
         format: @export_format,
         cursor: cursor(log),
         checkpoint_id: checkpoint_id,
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

  @spec restore(map()) :: {:ok, t()} | {:error, TypedError.t()}
  def restore(payload) when is_map(payload) do
    with :ok <- validate_export_format(payload),
         {:ok, cursor} <- normalize_export_cursor(fetch_any(payload, :cursor), payload),
         {:ok, entries} <- normalize_export_entries(fetch_any(payload, :entries), payload),
         :ok <- validate_restored_entry_cursors(entries, cursor, payload),
         {:ok, checkpoint_id} <-
           normalize_export_checkpoint_id(fetch_any(payload, :checkpoint_id), payload),
         computed_checkpoint_id <- restored_checkpoint_id(cursor, entries),
         :ok <-
           validate_restored_checkpoint_match(
             checkpoint_id,
             computed_checkpoint_id,
             payload
           ) do
      {:ok, %{cursor: cursor, entries: entries, last_checkpoint_id: computed_checkpoint_id}}
    end
  end

  def restore(payload) do
    {:error,
     TypedError.new(
       "replay_log.invalid_restore_payload",
       "validation",
       false,
       %{reason: "restore payload must be a map", payload: payload}
     )}
  end

  @spec compare(t(), t()) :: {:ok, map()} | {:error, TypedError.t()}
  def compare(actual_log, expected_log) when is_map(actual_log) and is_map(expected_log) do
    with :ok <- validate_log(actual_log),
         :ok <- validate_log(expected_log) do
      actual_cursor = cursor(actual_log)
      expected_cursor = cursor(expected_log)
      actual_entries = entries(actual_log)
      expected_entries = entries(expected_log)
      actual_checkpoint_id = restored_checkpoint_id(actual_cursor, actual_entries)
      expected_checkpoint_id = restored_checkpoint_id(expected_cursor, expected_entries)
      first_drift = first_drift(actual_entries, expected_entries)

      status =
        if is_nil(first_drift) and actual_cursor == expected_cursor and
             actual_checkpoint_id == expected_checkpoint_id do
          "match"
        else
          "drift"
        end

      {:ok,
       %{
         status: status,
         actual_cursor: actual_cursor,
         expected_cursor: expected_cursor,
         actual_checkpoint_id: actual_checkpoint_id,
         expected_checkpoint_id: expected_checkpoint_id,
         first_drift: first_drift
       }}
    end
  end

  def compare(actual_log, expected_log) do
    {:error,
     TypedError.new(
       "replay_log.invalid_log_state",
       "validation",
       false,
       %{reason: "both logs must be maps", actual_log: actual_log, expected_log: expected_log}
     )}
  end

  @spec verify_export(t(), map()) :: {:ok, map()} | {:error, TypedError.t()}
  def verify_export(actual_log, expected_export_payload)
      when is_map(actual_log) and is_map(expected_export_payload) do
    with {:ok, expected_log} <- restore(expected_export_payload),
         {:ok, comparison} <- compare(actual_log, expected_log) do
      {:ok, Map.put(comparison, :expected_source, "export")}
    end
  end

  def verify_export(actual_log, expected_export_payload) do
    {:error,
     TypedError.new(
       "replay_log.invalid_restore_payload",
       "validation",
       false,
       %{
         reason: "expected export payload must be a map",
         actual_log: actual_log,
         expected_export_payload: expected_export_payload
       }
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

  defp validate_export_format(payload) when is_map(payload) do
    case fetch_any(payload, :format) do
      @export_format ->
        :ok

      format ->
        {:error,
         TypedError.new(
           "replay_log.invalid_export_format",
           "validation",
           false,
           %{reason: "unsupported replay export format", format: format, payload: payload}
         )}
    end
  end

  defp normalize_export_cursor(cursor, _payload) when is_integer(cursor) and cursor >= 0,
    do: {:ok, cursor}

  defp normalize_export_cursor(cursor, payload) do
    {:error,
     TypedError.new(
       "replay_log.invalid_restore_payload",
       "validation",
       false,
       %{reason: "cursor must be a non-negative integer", cursor: cursor, payload: payload}
     )}
  end

  defp normalize_export_entries(entries, payload) when is_list(entries) do
    entries
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {entry, index}, {:ok, acc} ->
      case normalize_export_entry(entry, index, payload) do
        {:ok, normalized_entry} -> {:cont, {:ok, acc ++ [normalized_entry]}}
        {:error, _error} = error -> {:halt, error}
      end
    end)
  end

  defp normalize_export_entries(entries, payload) do
    {:error,
     TypedError.new(
       "replay_log.invalid_restore_payload",
       "validation",
       false,
       %{reason: "entries must be a list", entries: entries, payload: payload}
     )}
  end

  defp normalize_export_entry(entry, index, payload) when is_map(entry) do
    cursor = fetch_any(entry, :cursor)
    direction = fetch_any(entry, :direction)
    event = fetch_any(entry, :event)
    metadata = fetch_any(entry, :metadata)
    fingerprint = fetch_any(entry, :payload_fingerprint)

    with {:ok, normalized_cursor} <- normalize_export_entry_cursor(cursor, index, payload),
         {:ok, normalized_direction} <-
           normalize_export_entry_direction(direction, index, payload),
         {:ok, normalized_event} <- normalize_export_entry_event(event, index, payload),
         {:ok, normalized_metadata} <- normalize_export_entry_metadata(metadata, index, payload),
         {:ok, normalized_fingerprint} <-
           normalize_export_entry_fingerprint(fingerprint, normalized_metadata) do
      {:ok,
       %{
         cursor: normalized_cursor,
         direction: normalized_direction,
         event: normalized_event,
         payload_fingerprint: normalized_fingerprint,
         metadata: normalized_metadata
       }}
    end
  end

  defp normalize_export_entry(entry, index, payload) do
    {:error,
     TypedError.new(
       "replay_log.invalid_restore_payload",
       "validation",
       false,
       %{
         reason: "entries must contain maps",
         entry_index: index,
         entry: entry,
         payload: payload
       }
     )}
  end

  defp normalize_export_entry_cursor(cursor, _index, _payload)
       when is_integer(cursor) and cursor >= 1,
       do: {:ok, cursor}

  defp normalize_export_entry_cursor(cursor, index, payload) do
    {:error,
     TypedError.new(
       "replay_log.invalid_restore_payload",
       "validation",
       false,
       %{
         reason: "entry cursor must be a positive integer",
         entry_index: index,
         cursor: cursor,
         payload: payload
       }
     )}
  end

  defp normalize_export_entry_direction(direction, _index, _payload)
       when direction in [:outbound, :inbound],
       do: {:ok, direction}

  defp normalize_export_entry_direction("outbound", _index, _payload), do: {:ok, :outbound}
  defp normalize_export_entry_direction("inbound", _index, _payload), do: {:ok, :inbound}

  defp normalize_export_entry_direction(direction, index, payload) do
    {:error,
     TypedError.new(
       "replay_log.invalid_restore_payload",
       "validation",
       false,
       %{
         reason: "entry direction must be outbound or inbound",
         entry_index: index,
         direction: direction,
         payload: payload
       }
     )}
  end

  defp normalize_export_entry_event(event, _index, _payload) when is_atom(event),
    do: {:ok, Atom.to_string(event)}

  defp normalize_export_entry_event(event, _index, _payload)
       when is_binary(event) and event != "",
       do: {:ok, event}

  defp normalize_export_entry_event(event, index, payload) do
    {:error,
     TypedError.new(
       "replay_log.invalid_restore_payload",
       "validation",
       false,
       %{
         reason: "entry event must be a non-empty string or atom",
         entry_index: index,
         event: event,
         payload: payload
       }
     )}
  end

  defp normalize_export_entry_metadata(metadata, _index, _payload) when is_map(metadata),
    do: {:ok, metadata}

  defp normalize_export_entry_metadata(metadata, index, payload) do
    {:error,
     TypedError.new(
       "replay_log.invalid_restore_payload",
       "validation",
       false,
       %{
         reason: "entry metadata must be a map",
         entry_index: index,
         metadata: metadata,
         payload: payload
       }
     )}
  end

  defp normalize_export_entry_fingerprint(fingerprint, _metadata)
       when is_integer(fingerprint) and fingerprint >= 0,
       do: {:ok, fingerprint}

  defp normalize_export_entry_fingerprint(nil, metadata) when is_map(metadata),
    do: {:ok, :erlang.phash2(metadata)}

  defp normalize_export_entry_fingerprint(_fingerprint, metadata) when is_map(metadata),
    do: {:ok, :erlang.phash2(metadata)}

  defp validate_restored_entry_cursors([], cursor, payload)
       when is_integer(cursor) and cursor >= 0 do
    if cursor == 0 do
      :ok
    else
      {:error,
       TypedError.new(
         "replay_log.invalid_restore_payload",
         "validation",
         false,
         %{reason: "cursor must be 0 when entries are empty", cursor: cursor, payload: payload}
       )}
    end
  end

  defp validate_restored_entry_cursors(entries, cursor, payload)
       when is_list(entries) and is_integer(cursor) do
    entry_cursors = Enum.map(entries, &Map.get(&1, :cursor))

    cond do
      entry_cursors != Enum.sort(entry_cursors) ->
        {:error,
         TypedError.new(
           "replay_log.invalid_restore_payload",
           "validation",
           false,
           %{
             reason: "entry cursors must be ascending",
             entry_cursors: entry_cursors,
             payload: payload
           }
         )}

      length(entry_cursors) != length(Enum.uniq(entry_cursors)) ->
        {:error,
         TypedError.new(
           "replay_log.invalid_restore_payload",
           "validation",
           false,
           %{
             reason: "entry cursors must be unique",
             entry_cursors: entry_cursors,
             payload: payload
           }
         )}

      List.last(entry_cursors) != cursor ->
        {:error,
         TypedError.new(
           "replay_log.invalid_restore_payload",
           "validation",
           false,
           %{
             reason: "cursor must match the last entry cursor",
             cursor: cursor,
             entry_cursors: entry_cursors,
             payload: payload
           }
         )}

      true ->
        :ok
    end
  end

  defp normalize_export_checkpoint_id(nil, _payload), do: {:ok, nil}

  defp normalize_export_checkpoint_id(checkpoint_id, _payload) when is_binary(checkpoint_id),
    do: {:ok, checkpoint_id}

  defp normalize_export_checkpoint_id(checkpoint_id, payload) do
    {:error,
     TypedError.new(
       "replay_log.invalid_restore_payload",
       "validation",
       false,
       %{
         reason: "checkpoint_id must be a string or nil",
         checkpoint_id: checkpoint_id,
         payload: payload
       }
     )}
  end

  defp validate_restored_checkpoint_match(exported_checkpoint_id, computed_checkpoint_id, payload) do
    if exported_checkpoint_id == computed_checkpoint_id do
      :ok
    else
      {:error,
       TypedError.new(
         "replay_log.restore_checkpoint_mismatch",
         "validation",
         false,
         %{
           reason: "checkpoint_id does not match replay entries",
           exported_checkpoint_id: exported_checkpoint_id,
           computed_checkpoint_id: computed_checkpoint_id,
           payload: payload
         }
       )}
    end
  end

  defp restored_checkpoint_id(0, []), do: nil
  defp restored_checkpoint_id(cursor, entries), do: checkpoint_id(cursor, entries)

  defp first_drift(actual_entries, expected_entries)
       when is_list(actual_entries) and is_list(expected_entries) do
    normalized_actual = Enum.map(actual_entries, &normalized_entry/1)
    normalized_expected = Enum.map(expected_entries, &normalized_entry/1)

    case first_entry_mismatch(normalized_actual, normalized_expected) do
      {:mismatch, index, actual_entry, expected_entry} ->
        %{
          reason: "entry_mismatch",
          index: index,
          cursor:
            mismatch_cursor(actual_entry, expected_entry, normalized_actual, normalized_expected),
          actual_entry: actual_entry,
          expected_entry: expected_entry
        }

      :none ->
        if length(normalized_actual) == length(normalized_expected) do
          nil
        else
          %{
            reason: "entry_count_mismatch",
            index: min(length(normalized_actual), length(normalized_expected)),
            cursor: trailing_cursor(normalized_actual, normalized_expected),
            actual_entry_count: length(normalized_actual),
            expected_entry_count: length(normalized_expected)
          }
        end
    end
  end

  defp normalized_entry(entry) when is_map(entry) do
    %{
      cursor: fetch_any(entry, :cursor),
      direction: fetch_any(entry, :direction),
      event: normalize_entry_event(fetch_any(entry, :event)),
      payload_fingerprint: fetch_any(entry, :payload_fingerprint),
      metadata: fetch_any(entry, :metadata)
    }
  end

  defp first_entry_mismatch(actual_entries, expected_entries)
       when is_list(actual_entries) and is_list(expected_entries) do
    actual_entries
    |> Enum.zip(expected_entries)
    |> Enum.with_index()
    |> Enum.reduce_while(:none, fn {{actual_entry, expected_entry}, index}, _acc ->
      if actual_entry == expected_entry do
        {:cont, :none}
      else
        {:halt, {:mismatch, index, actual_entry, expected_entry}}
      end
    end)
  end

  defp mismatch_cursor(actual_entry, expected_entry, _actual_entries, _expected_entries)
       when is_map(actual_entry) and is_map(expected_entry) do
    fetch_any(actual_entry, :cursor) || fetch_any(expected_entry, :cursor)
  end

  defp mismatch_cursor(_actual_entry, _expected_entry, actual_entries, expected_entries) do
    trailing_cursor(actual_entries, expected_entries)
  end

  defp trailing_cursor(actual_entries, expected_entries)
       when is_list(actual_entries) and is_list(expected_entries) do
    case length(actual_entries) > length(expected_entries) do
      true ->
        actual_entries
        |> Enum.at(length(expected_entries))
        |> fetch_any(:cursor)

      false ->
        expected_entries
        |> Enum.at(length(actual_entries))
        |> fetch_any(:cursor)
    end
  end

  defp normalize_entry_event(event) when is_atom(event), do: Atom.to_string(event)
  defp normalize_entry_event(event), do: event

  defp fetch_any(map, key) when is_map(map) and is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
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
