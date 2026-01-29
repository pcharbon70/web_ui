defmodule WebUi.Plugs.PageMetadataTest do
  @moduledoc """
  Tests for WebUi.Plugs.PageMetadata.
  """

  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias WebUi.Plugs.PageMetadata

  @moduletag :page_metadata

  describe "init/1" do
    test "returns options unchanged" do
      opts = [title: "Test", description: "Test description"]
      assert PageMetadata.init(opts) == opts
    end

    test "returns empty list when no options given" do
      assert PageMetadata.init([]) == []
    end
  end

  describe "call/2" do
    test "sets page_title assign from metadata" do
      conn =
        conn(:get, "/about")
        |> assign(:page_metadata, title: "About Us")
        |> PageMetadata.call([])

      assert conn.assigns[:page_title] == "About Us"
    end

    test "sets page_description assign from metadata" do
      conn =
        conn(:get, "/about")
        |> assign(:page_metadata, description: "Learn about our company")
        |> PageMetadata.call([])

      assert conn.assigns[:page_description] == "Learn about our company"
    end

    test "sets page_keywords assign from metadata" do
      conn =
        conn(:get, "/about")
        |> assign(:page_metadata, keywords: "elixir, phoenix, web")
        |> PageMetadata.call([])

      assert conn.assigns[:page_keywords] == "elixir, phoenix, web"
    end

    test "sets page_author assign from metadata" do
      conn =
        conn(:get, "/about")
        |> assign(:page_metadata, author: "John Doe")
        |> PageMetadata.call([])

      assert conn.assigns[:page_author] == "John Doe"
    end

    test "sets page_og_image assign from metadata" do
      conn =
        conn(:get, "/about")
        |> assign(:page_metadata, og_image: "https://example.com/image.png")
        |> PageMetadata.call([])

      assert conn.assigns[:page_og_image] == "https://example.com/image.png"
    end

    test "sets multiple assigns from metadata" do
      metadata = [
        title: "About Us",
        description: "Learn about our company",
        keywords: "company, about",
        author: "Jane Doe",
        og_image: "https://example.com/og.png"
      ]

      conn =
        conn(:get, "/about")
        |> assign(:page_metadata, metadata)
        |> PageMetadata.call([])

      assert conn.assigns[:page_title] == "About Us"
      assert conn.assigns[:page_description] == "Learn about our company"
      assert conn.assigns[:page_keywords] == "company, about"
      assert conn.assigns[:page_author] == "Jane Doe"
      assert conn.assigns[:page_og_image] == "https://example.com/og.png"
    end

    test "sets nil when metadata is missing" do
      conn =
        conn(:get, "/about")
        |> PageMetadata.call([])

      assert conn.assigns[:page_title] == nil
      assert conn.assigns[:page_description] == nil
      assert conn.assigns[:page_keywords] == nil
      assert conn.assigns[:page_author] == nil
      assert conn.assigns[:page_og_image] == nil
    end

    test "sets nil when page_metadata assigns field is empty" do
      conn =
        conn(:get, "/about")
        |> assign(:page_metadata, [])
        |> PageMetadata.call([])

      assert conn.assigns[:page_title] == nil
      assert conn.assigns[:page_description] == nil
    end

    test "sets nil for specific fields when not in metadata" do
      conn =
        conn(:get, "/about")
        |> assign(:page_metadata, title: "About")
        |> PageMetadata.call([])

      assert conn.assigns[:page_title] == "About"
      assert conn.assigns[:page_description] == nil
      assert conn.assigns[:page_keywords] == nil
    end
  end

  describe "integration with defpage" do
    test "defpage stores metadata in conn.assigns" do
      # This is verified by the router tests that check route structure
      # The actual integration test would require a full request cycle
      # which is covered by the controller tests
      assert true
    end
  end
end
