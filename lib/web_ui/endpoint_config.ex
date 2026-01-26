defmodule WebUi.EndpointConfig do
  @moduledoc """
  Configuration hooks for WebUi.Endpoint.

  This module allows user applications to extend the endpoint configuration.

  ## Usage

  In your application, you can define this module to customize the endpoint:

      defmodule WebUi.EndpointConfig do
        def init(config) do
          # Customize configuration before the endpoint starts
          Keyword.put(config, :custom_setting, true)
        end
      end
  """

  @doc """
  Hook for customizing the endpoint configuration.

  This function is called by `WebUi.Endpoint.init/2` before the endpoint starts.
  Override this in your application to customize the configuration.

  ## Example

      defmodule WebUi.EndpointConfig do
        def init(config) do
          config
          |> Keyword.put(:custom_middleware, MyMiddleware)
          |> Keyword.update(:watchers, [], fn watchers ->
            watchers ++ [custom: {MyWatcher, :run, []}]
          end)
        end
      end

  """
  @callback init(keyword()) :: keyword()

  @optional_callbacks [init: 1]

  @doc """
  Default implementation - returns config unchanged.
  """
  def init(config), do: config
end
