defmodule WebUi.Plugs.RateLimitTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias WebUi.Plugs.RateLimit

  @moduletag :rate_limit

  setup do
    # Start the storage if not already started
    case Process.whereis(RateLimit.ETSStorage) do
      nil ->
        {:ok, _pid} = RateLimit.ETSStorage.start_link([])

      _pid ->
        :ok
    end

    # Clean up any existing data
    RateLimit.ETSStorage.cleanup_identifier("test_127.0.0.1")
    RateLimit.ETSStorage.cleanup_identifier("test_127.0.0.2")

    :ok
  end

  describe "init/1" do
    test "returns options when enabled" do
      opts = RateLimit.init(name: :test, limits: [{10, 60_000}])

      assert opts[:name] == :test
      assert opts[:limits] == [{10, 60_000}]
      assert is_function(opts[:identifier])
      assert is_function(opts[:on_limit_exceeded])
    end

    test "uses default limits when not provided" do
      opts = RateLimit.init(name: :test)

      assert opts[:name] == :test
      assert is_list(opts[:limits])
      assert length(opts[:limits]) > 0
    end

    test "returns disabled option when rate limiting disabled" do
      # Temporarily disable rate limiting
      Application.put_env(:web_ui, WebUi.Plugs.RateLimit, enabled: false)

      opts = RateLimit.init(name: :test)

      assert opts[:enabled] == false

      # Restore to test default
      Application.put_env(:web_ui, WebUi.Plugs.RateLimit, enabled: true)
    end
  end

  describe "call/2" do
    test "allows requests within limit" do
      opts = RateLimit.init(name: :test, limits: [{5, 1000}])

      conn =
        conn(:get, "/")
        |> RateLimit.call(opts)

      assert conn.status != 429
      assert get_resp_header(conn, "x-ratelimit-limit") == ["5"]
    end

    test "adds rate limit headers" do
      opts = RateLimit.init(name: :test, limits: [{5, 1000}])

      conn =
        conn(:get, "/")
        |> RateLimit.call(opts)

      assert get_resp_header(conn, "x-ratelimit-limit") == ["5"]
      assert get_resp_header(conn, "x-ratelimit-remaining") |> List.first() |> String.to_integer() <= 5
      assert get_resp_header(conn, "x-ratelimit-reset") != []
    end

    test "tracks request count" do
      opts = RateLimit.init(name: :test, limits: [{3, 1000}])

      # First request
      conn1 =
        conn(:get, "/")
        |> RateLimit.call(opts)

      assert get_resp_header(conn1, "x-ratelimit-remaining") |> List.first() |> String.to_integer() == 2

      # Second request
      conn2 =
        conn(:get, "/")
        |> RateLimit.call(opts)

      remaining = get_resp_header(conn2, "x-ratelimit-remaining") |> List.first() |> String.to_integer()
      assert remaining <= 2
    end

    test "blocks requests exceeding limit" do
      opts = RateLimit.init(name: :test, limits: [{3, 1000}])
      identifier = fn _conn -> "test_127.0.0.2" end

      # Make 3 requests (limit)
      for _ <- 1..3 do
        conn(:get, "/")
        |> Map.put(:remote_ip, {127, 0, 0, 2})
        |> RateLimit.call(Keyword.put(opts, :identifier, identifier))
      end

      # Fourth request should be blocked
      conn =
        conn(:get, "/")
        |> Map.put(:remote_ip, {127, 0, 0, 2})
        |> RateLimit.call(Keyword.put(opts, :identifier, identifier))

      assert conn.status == 429
      assert conn.resp_body =~ "Rate limit exceeded"
    end

    test "resets after window expires" do
      opts = RateLimit.init(name: :test, limits: [{2, 500}])

      # Make 2 requests
      for _ <- 1..2 do
        conn(:get, "/")
        |> RateLimit.call(opts)
      end

      # Wait for window to expire
      Process.sleep(600)

      # Should be able to make requests again
      conn =
        conn(:get, "/")
        |> RateLimit.call(opts)

      assert conn.status != 429
    end

    test "does not limit errors" do
      opts = RateLimit.init(name: :test, limits: [{2, 1000}])

      # First request succeeds
      conn1 =
        conn(:get, "/")
        |> RateLimit.call(opts)

      assert conn1.status != 429
      # Check remaining - should be 1 after first request
      remaining1 = get_resp_header(conn1, "x-ratelimit-remaining") |> List.first() |> String.to_integer()
      assert remaining1 == 1

      # Second request also succeeds and is counted
      # Note: With the new implementation, all requests are counted immediately
      # regardless of the eventual response status
      conn2 =
        conn(:get, "/")
        |> RateLimit.call(opts)

      assert conn2.status != 429

      # Third request should be rate limited since we've now made 2 requests
      conn3 =
        conn(:get, "/")
        |> RateLimit.call(opts)

      assert conn3.status == 429
    end
  end

  describe "allow_request?/2" do
    test "returns :ok when within limit" do
      assert RateLimit.allow_request?("test_127.0.0.1", [{10, 1000}]) == :ok
    end

    test "returns error when limit exceeded" do
      # Record requests up to limit
      for _ <- 1..5 do
        RateLimit.ETSStorage.record_request("test_127.0.0.2", [{5, 1000}])
      end

      assert RateLimit.allow_request?("test_127.0.0.2", [{5, 1000}]) == {:error, :rate_limit_exceeded}
    end
  end

  describe "get_state/2" do
    test "returns current state for identifier" do
      state = RateLimit.get_state("test_127.0.0.1", [{10, 1000}])

      assert state.limit == 10
      assert state.remaining >= 0
      assert state.remaining <= 10
      assert is_integer(state.reset)
    end
  end

  describe "ETSStorage" do
    alias WebUi.Plugs.RateLimit.ETSStorage

    test "check_limits/3 returns ok for new identifier" do
      assert {:ok, state} = ETSStorage.check_limits("new_id", [{10, 1000}], dry_run: true)
      assert state.limit == 10
      assert state.remaining == 10
    end

    test "check_limits/3 tracks request count" do
      id = "tracking_test"

      # Record some requests
      ETSStorage.record_request(id, [{10, 1000}])
      ETSStorage.record_request(id, [{10, 1000}])
      ETSStorage.record_request(id, [{10, 1000}])

      {:ok, state} = ETSStorage.check_limits(id, [{10, 1000}], dry_run: true)
      assert state.remaining == 7
    end

    test "check_limits/3 returns error when limit exceeded" do
      id = "exceed_test"

      # Record up to limit
      for _ <- 1..10 do
        ETSStorage.record_request(id, [{10, 1000}])
      end

      # One more request to exceed the limit
      ETSStorage.record_request(id, [{10, 1000}])

      # Should be exceeded now
      assert {:error, :rate_limit_exceeded, _state} = ETSStorage.check_limits(id, [{10, 1000}], dry_run: true)
    end

    test "record_request/2 stores request timestamps" do
      id = "timestamp_test"

      ETSStorage.record_request(id, [{10, 1000}])

      {:ok, state} = ETSStorage.check_limits(id, [{10, 1000}], dry_run: true)
      assert state.remaining == 9
    end

    test "cleanup_identifier/1 removes all data for identifier" do
      id = "cleanup_test"

      # Add some data
      ETSStorage.record_request(id, [{10, 1000}])
      {:ok, _state} = ETSStorage.check_limits(id, [{10, 1000}], dry_run: true)

      # Cleanup
      ETSStorage.cleanup_identifier(id)

      # Should be fresh
      {:ok, state} = ETSStorage.check_limits(id, [{10, 1000}], dry_run: true)
      assert state.remaining == 10
    end

    test "respects sliding window" do
      id = "window_test"

      # Make some requests
      for _ <- 1..5 do
        ETSStorage.record_request(id, [{10, 1000}])
      end

      # Check we're at 5/10
      {:ok, state} = ETSStorage.check_limits(id, [{10, 1000}], dry_run: true)
      assert state.remaining == 5

      # Wait for requests to expire
      Process.sleep(1100)

      # Should be reset
      {:ok, state} = ETSStorage.check_limits(id, [{10, 1000}], dry_run: true)
      assert state.remaining == 10
    end

    test "handles multiple limit tiers" do
      id = "multi_tier_test"

      # Make 6 requests
      for _ <- 1..6 do
        ETSStorage.record_request(id, [{5, 1000}, {10, 2000}])
      end

      # Check with first limit (5/1000) - should be exceeded
      assert {:error, :rate_limit_exceeded, _state} = ETSStorage.check_limits(id, [{5, 1000}, {10, 2000}], dry_run: true)

      # Check with second limit (10/2000) - should be ok
      {:ok, state} = ETSStorage.check_limits(id, [{10, 2000}], dry_run: true)
      assert state.remaining == 4
    end
  end
end
