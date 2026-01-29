ExUnit.start()

# By default, exclude integration tests to avoid state pollution.
# Run integration tests explicitly with: mix test test/web_ui/phase3_integration_test.exs
unless System.get_env("PHASE3_INTEGRATION") == "true" do
  ExUnit.configure(exclude: [phase3_integration: true])
end
