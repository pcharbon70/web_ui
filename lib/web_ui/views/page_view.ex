defmodule WebUi.PageView do
  @moduledoc """
  View module for PageController templates.

  This view provides functions for rendering page templates
  used by the PageController.
  """

  # Templates are in lib/web_ui/templates/page/
  # We need to specify the path relative to the project root
  import Phoenix.Template
  import Phoenix.HTML, only: [raw: 1]

  embed_templates "../templates/page/*"
end
