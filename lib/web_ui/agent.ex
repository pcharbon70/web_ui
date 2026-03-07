defmodule WebUi.Agent do
  @moduledoc """
  Runtime authority dispatch boundary for routing events into host-owned handlers.
  """

  alias WebUi.RuntimeContext
  alias WebUi.ServiceRequestEnvelope
  alias WebUi.TypedError

  @enforce_keys [:routes]
  defstruct routes: %{}, default_timeout_ms: 1_000

  @type route :: %{
          event_type: String.t(),
          service: String.t(),
          operation: String.t(),
          handler: (ServiceRequestEnvelope.t() -> term())
        }

  @type dispatch_success :: %{
          service: String.t(),
          operation: String.t(),
          payload: map(),
          context: RuntimeContext.t(),
          request: ServiceRequestEnvelope.t()
        }

  @type t :: %__MODULE__{routes: %{String.t() => route()}, default_timeout_ms: pos_integer()}

  @spec new([route()], keyword()) :: {:ok, t()} | {:error, TypedError.t()}
  def new(routes, opts \\ [])

  def new(routes, opts) when is_list(routes) and is_list(opts) do
    with {:ok, route_map} <- build_route_map(routes) do
      {:ok,
       %__MODULE__{
         routes: route_map,
         default_timeout_ms: Keyword.get(opts, :default_timeout_ms, 1_000)
       }}
    end
  end

  def new(_routes, _opts) do
    {:error,
     TypedError.new(
       "agent.invalid_route_table",
       "validation",
       false,
       %{reason: "routes must be a list"},
       "unknown"
     )}
  end

  @spec dispatch(t(), map(), map(), keyword()) :: {:ok, dispatch_success()} | {:error, TypedError.t()}
  def dispatch(agent, event_envelope, context, opts \\ [])

  def dispatch(%__MODULE__{} = agent, event_envelope, context, opts)
      when is_map(event_envelope) and is_map(context) and is_list(opts) do
    with {:ok, runtime_context} <- RuntimeContext.validate(context),
         {:ok, route} <- resolve_route(agent, event_envelope, runtime_context),
         {:ok, request} <- ServiceRequestEnvelope.from_event(route.service, route.operation, event_envelope, runtime_context),
         {:ok, payload} <- invoke_handler(route.handler, request, runtime_context, Keyword.get(opts, :timeout_ms, agent.default_timeout_ms)) do
      {:ok,
       %{
         service: route.service,
         operation: route.operation,
         payload: payload,
         context: runtime_context,
         request: request
       }}
    end
  end

  def dispatch(%__MODULE__{}, _event_envelope, context, _opts) do
    {:error,
     TypedError.new(
       "agent.invalid_event_shape",
       "protocol",
       false,
       %{reason: "event envelope must be a map"},
       fetch_any(context || %{}, :correlation_id) || "unknown"
     )}
  end

  defp build_route_map(routes) do
    Enum.reduce_while(routes, {:ok, %{}}, fn route, {:ok, acc} ->
      with {:ok, normalized} <- validate_route(route) do
        event_type = normalized.event_type

        if Map.has_key?(acc, event_type) do
          {:halt,
           {:error,
            TypedError.new(
              "agent.duplicate_route",
              "validation",
              false,
              %{event_type: event_type},
              "unknown"
            )}}
        else
          {:cont, {:ok, Map.put(acc, event_type, normalized)}}
        end
      else
        {:error, %TypedError{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp validate_route(route) when is_map(route) do
    event_type = fetch_any(route, :event_type)
    service = fetch_any(route, :service)
    operation = fetch_any(route, :operation)
    handler = fetch_any(route, :handler)

    cond do
      not (is_binary(event_type) and event_type != "") ->
        {:error,
         TypedError.new("agent.invalid_route_event_type", "validation", false, %{route: route}, "unknown")}

      not (is_binary(service) and service != "") ->
        {:error,
         TypedError.new("agent.invalid_route_service", "validation", false, %{route: route}, "unknown")}

      not (is_binary(operation) and operation != "") ->
        {:error,
         TypedError.new("agent.invalid_route_operation", "validation", false, %{route: route}, "unknown")}

      not is_function(handler, 1) ->
        {:error,
         TypedError.new("agent.invalid_route_handler", "validation", false, %{route: route}, "unknown")}

      true ->
        {:ok,
         %{
           event_type: event_type,
           service: service,
           operation: operation,
           handler: handler
         }}
    end
  end

  defp validate_route(_route) do
    {:error,
     TypedError.new(
       "agent.invalid_route_shape",
       "validation",
       false,
       %{reason: "route must be a map"},
       "unknown"
     )}
  end

  defp resolve_route(%__MODULE__{routes: routes}, event_envelope, runtime_context) do
    event_type = fetch_any(event_envelope, :type)

    case Map.get(routes, event_type) do
      nil ->
        {:error,
         TypedError.new(
           "agent.unknown_event_type",
           "protocol",
           false,
           %{event_type: event_type},
           runtime_context.correlation_id
         )}

      route ->
        {:ok, route}
    end
  end

  defp invoke_handler(handler, request, runtime_context, timeout_ms) do
    task = Task.async(fn -> safe_call(handler, request) end)

    case Task.yield(task, timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, payload}} when is_map(payload) ->
        {:ok, payload}

      {:ok, {:ok, _payload}} ->
        {:error,
         TypedError.new(
           "agent.invalid_handler_payload",
           "internal",
           false,
           %{reason: "handler success payload must be a map"},
           runtime_context.correlation_id
         )}

      {:ok, {:error, %TypedError{} = error}} ->
        {:error, normalize_error_correlation(error, runtime_context)}

      {:ok, {:error, {:dependency, reason}}} ->
        {:error,
         TypedError.new(
           "agent.runtime_dependency_error",
           "dependency",
           true,
           %{reason: inspect(reason)},
           runtime_context.correlation_id
         )}

      {:ok, {:error, {:timeout, timeout_reason}}} ->
        {:error,
         TypedError.new(
           "agent.runtime_timeout",
           "timeout",
           true,
           %{reason: inspect(timeout_reason), timeout_ms: timeout_ms},
           runtime_context.correlation_id
         )}

      {:ok, {:error, reason}} ->
        {:error,
         TypedError.new(
           "agent.runtime_internal_error",
           "internal",
           false,
           %{reason: inspect(reason)},
           runtime_context.correlation_id
         )}

      {:ok, {:exception, kind, reason, stacktrace}} ->
        {:error,
         TypedError.new(
           "agent.runtime_internal_error",
           "internal",
           false,
           %{kind: inspect(kind), reason: inspect(reason), stacktrace: Exception.format_stacktrace(stacktrace)},
           runtime_context.correlation_id
         )}

      nil ->
        {:error,
         TypedError.new(
           "agent.runtime_timeout",
           "timeout",
           true,
           %{timeout_ms: timeout_ms},
           runtime_context.correlation_id
         )}

      other ->
        {:error,
         TypedError.new(
           "agent.runtime_internal_error",
           "internal",
           false,
           %{unexpected_result: inspect(other)},
           runtime_context.correlation_id
         )}
    end
  end

  defp safe_call(handler, request) do
    handler.(request)
  rescue
    exception ->
      {:exception, :error, exception, __STACKTRACE__}
  catch
    kind, reason ->
      {:exception, kind, reason, __STACKTRACE__}
  end

  defp normalize_error_correlation(%TypedError{} = error, runtime_context) do
    if error.correlation_id in [nil, "", "unknown"] do
      %{error | correlation_id: runtime_context.correlation_id}
    else
      error
    end
  end

  defp fetch_any(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
end
