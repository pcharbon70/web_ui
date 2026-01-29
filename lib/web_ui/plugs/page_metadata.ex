defmodule WebUi.Plugs.PageMetadata do
  @moduledoc """
  Plug to extract page metadata from route assigns and set them as top-level assigns.

  This plug works with the `defpage/2` macro in `WebUi.Router` to provide
  page-specific metadata like title, description, and Open Graph tags.

  ## Usage

  The plug is automatically added to the `:browser` pipeline and retrieves
  metadata stored by the `defpage` macro:

      defpage "/about", title: "About Us", description: "Learn about our company"

  This makes the metadata available as assigns in the controller:

      - @page_title
      - @page_description
      - @page_keywords
      - @page_author
      - @page_og_image

  ## Configuration

  No configuration required. The plug reads from `conn.assigns[:page_metadata]`
  which is set by the `defpage` macro via Phoenix's route assigns mechanism.

  """
  import Plug.Conn

  @type opts :: [
    title: String.t(),
    description: String.t(),
    keywords: String.t(),
    author: String.t(),
    og_image: String.t()
  ]

  @doc """
  Initializes the plug.

  ## Options

  All options are passed through from the `defpage` macro:
  * `:title` - Page title
  * `:description` - Page description for SEO
  * `:keywords` - Page keywords
  * `:author` - Page author
  * `:og_image` - Open Graph image URL

  """
  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @doc """
  Calls the plug, extracting metadata and setting assigns.
  """
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    # Get metadata from conn.assigns (set by defpage macro via Phoenix route assigns)
    metadata = Map.get(conn.assigns, :page_metadata, [])

    # Extract common metadata fields
    title = Keyword.get(metadata, :title)
    description = Keyword.get(metadata, :description)
    keywords = Keyword.get(metadata, :keywords)
    author = Keyword.get(metadata, :author)
    og_image = Keyword.get(metadata, :og_image)

    # Set assigns for use in controller/views
    conn
    |> assign(:page_title, title)
    |> assign(:page_description, description)
    |> assign(:page_keywords, keywords)
    |> assign(:page_author, author)
    |> assign(:page_og_image, og_image)
  end
end
