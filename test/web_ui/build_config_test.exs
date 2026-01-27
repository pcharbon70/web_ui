defmodule WebUi.BuildConfigTest do
  use ExUnit.Case, async: true

  @moduletag :build_config

  describe "elm.json" do
    test "elm.json exists and is valid JSON" do
      elm_json_path = Path.join(["assets", "elm", "elm.json"])

      assert File.exists?(elm_json_path), "elm.json should exist"

      case File.read(elm_json_path) do
        {:ok, content} ->
          assert {:ok, _json} = Jason.decode(content), "elm.json should be valid JSON"

          {:ok, json} = Jason.decode(content)

          # Verify required fields
          assert Map.has_key?(json, "type"), "elm.json should have 'type' field"

          assert Map.has_key?(json, "source-directories"),
                 "elm.json should have 'source-directories'"

          assert Map.has_key?(json, "dependencies"), "elm.json should have 'dependencies'"

          # Verify source directories
          assert "src" in json["source-directories"], "src should be in source-directories"

        {:error, reason} ->
          flunk("Could not read elm.json: #{reason}")
      end
    end

    test "elm test configuration exists" do
      test_elm_json = Path.join(["assets", "elm", "tests", "elm.json"])

      assert File.exists?(test_elm_json), "tests/elm.json should exist"

      {:ok, content} = File.read(test_elm_json)
      {:ok, json} = Jason.decode(content)

      # Elm test configuration uses "test-dependencies" key
      assert Map.has_key?(json, "test-dependencies") or Map.has_key?(json, "dependencies"),
             "tests/elm.json should have test dependencies"
    end
  end

  describe "Tailwind CSS" do
    test "tailwind config exists" do
      tailwind_config = Path.join(["assets", "tailwind.config.js"])

      assert File.exists?(tailwind_config), "tailwind.config.js should exist"
    end

    test "app.css exists with Tailwind imports" do
      app_css = Path.join(["assets", "css", "app.css"])

      assert File.exists?(app_css), "app.css should exist"

      {:ok, content} = File.read(app_css)

      assert content =~ "@tailwind", "app.css should contain @tailwind directives"
      assert content =~ "base;", "app.css should import Tailwind base"
      assert content =~ "components;", "app.css should import Tailwind components"
      assert content =~ "utilities;", "app.css should import Tailwind utilities"
    end
  end

  describe "Mix compilers" do
    test "Elm compiler module exists" do
      code_path = Path.join(["lib", "mix", "tasks", "compile.elm.ex"])

      assert File.exists?(code_path), "Elm compiler module should exist"
    end

    test "mix.exs includes :elm in compilers" do
      mix_exs = Path.join(["mix.exs"])

      {:ok, content} = File.read(mix_exs)

      assert content =~ "compilers:", "mix.exs should have compilers"
      assert content =~ ":elm", "mix.exs should include :elm in compilers"
    end
  end

  describe "Asset tasks" do
    test "assets.build task exists" do
      task_path = Path.join(["lib", "mix", "tasks", "assets.build.ex"])

      assert File.exists?(task_path), "assets.build task should exist"
    end

    test "assets.clean task exists" do
      task_path = Path.join(["lib", "mix", "tasks", "assets.clean.ex"])

      assert File.exists?(task_path), "assets.clean task should exist"
    end

    test "assets.watch task exists" do
      task_path = Path.join(["lib", "mix", "tasks", "assets.watch.ex"])

      assert File.exists?(task_path), "assets.watch task should exist"
    end
  end

  describe "JavaScript interop" do
    test "web_ui_interop.js exists" do
      js_path = Path.join(["assets", "js", "web_ui_interop.js"])

      assert File.exists?(js_path), "web_ui_interop.js should exist"
    end

    test "web_ui_interop.js contains Elm init function" do
      js_path = Path.join(["assets", "js", "web_ui_interop.js"])

      {:ok, content} = File.read(js_path)

      assert content =~ "initElm", "web_ui_interop.js should export initElm function"
      assert content =~ "WebSocket", "web_ui_interop.js should handle WebSocket"
      assert content =~ "sendCloudEvent", "web_ui_interop.js should have sendCloudEvent function"

      assert content =~ "receiveCloudEvent",
             "web_ui_interop.js should have receiveCloudEvent function"
    end
  end

  describe "package.json" do
    test "package.json exists and is valid JSON" do
      package_json = Path.join(["package.json"])

      assert File.exists?(package_json), "package.json should exist"

      {:ok, content} = File.read(package_json)

      assert {:ok, _json} = Jason.decode(content), "package.json should be valid JSON"

      {:ok, json} = Jason.decode(content)

      assert Map.has_key?(json, "devDependencies"), "package.json should have devDependencies"
      assert Map.has_key?(json, "scripts"), "package.json should have scripts"
    end

    test "package.json includes esbuild" do
      {:ok, content} = File.read("package.json")
      {:ok, json} = Jason.decode(content)

      assert Map.has_key?(json["devDependencies"], "esbuild"),
             "package.json should include esbuild"
    end

    test "package.json includes tailwindcss" do
      {:ok, content} = File.read("package.json")
      {:ok, json} = Jason.decode(content)

      assert Map.has_key?(json["devDependencies"], "tailwindcss"),
             "package.json should include tailwindcss"
    end
  end

  describe "Mix aliases" do
    test "mix.exs defines aliases function" do
      {:ok, content} = File.read("mix.exs")

      assert content =~ "defp aliases", "mix.exs should define aliases function"
    end

    test "mix.exs includes assets.build alias" do
      {:ok, content} = File.read("mix.exs")

      assert content =~ ~s("assets.build"), "mix.exs should include assets.build alias"
    end

    test "mix.exs includes assets.clean alias" do
      {:ok, content} = File.read("mix.exs")

      assert content =~ ~s("assets.clean"), "mix.exs should include assets.clean alias"
    end

    test "mix.exs includes assets.watch alias" do
      {:ok, content} = File.read("mix.exs")

      assert content =~ ~s("assets.watch"), "mix.exs should include assets.watch alias"
    end

    test "mix.exs includes setup alias" do
      {:ok, content} = File.read("mix.exs")

      assert content =~ ~s(setup:), "mix.exs should include setup alias"
    end

    test "mix.exs includes test.elm alias" do
      {:ok, content} = File.read("mix.exs")

      assert content =~ ~s("test.elm"), "mix.exs should include test.elm alias"
    end
  end

  describe "Configuration" do
    test "config.exs includes Elm configuration" do
      {:ok, content} = File.read("config/config.exs")

      assert content =~ ":elm,", "config.exs should have Elm configuration"
      assert content =~ "elm_path", "config.exs should configure elm_path"
      assert content =~ "elm_output", "config.exs should configure elm_output"
    end

    test "config.exs includes Tailwind configuration" do
      {:ok, content} = File.read("config/config.exs")

      assert content =~ ":tailwind,", "config.exs should have Tailwind configuration"
      assert content =~ "tailwind.config.js", "config.exs should reference tailwind config"
    end

    test "config.exs includes esbuild configuration" do
      {:ok, content} = File.read("config/config.exs")

      assert content =~ ":esbuild,", "config.exs should have esbuild configuration"
      assert content =~ "web_ui_interop.js", "config.exs should reference interop file"
    end

    test "prod.exs enables optimization" do
      {:ok, content} = File.read("config/prod.exs")

      assert content =~ "elm_optimize: true", "prod.exs should enable Elm optimization"
      assert content =~ "minify: true", "prod.exs should enable CSS/JS minification"
    end

    test "dev.exs includes asset watchers" do
      {:ok, content} = File.read("config/dev.exs")

      assert content =~ "watchers:", "dev.exs should include watchers"
      assert content =~ "tailwind:", "dev.exs should watch Tailwind"
    end
  end

  describe "Output directory" do
    test "output directory exists or can be created" do
      output_dir = Path.join(["priv", "static", "web_ui", "assets"])

      # Create if it doesn't exist (for testing purposes)
      File.mkdir_p(output_dir)

      assert File.dir?(output_dir), "output directory should exist"
    end
  end
end
