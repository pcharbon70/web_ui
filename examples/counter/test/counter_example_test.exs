defmodule CounterExampleTest do
  use ExUnit.Case, async: true

  test "web_ui endpoint module is available" do
    assert Code.ensure_loaded?(WebUi.Endpoint)
  end
end
