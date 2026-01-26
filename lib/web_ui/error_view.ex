defmodule WebUi.ErrorView do
  @moduledoc """
  Error view for rendering errors.

  In development, renders detailed error information.
  In production, renders generic error pages.
  """

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end

  def render("404.html", _assigns) do
    """
    <!DOCTYPE html>
    <html>
      <head>
        <title>Not Found</title>
        <style>
          body {
            font-family: system-ui, -apple-system, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background: #f8fafc;
          }
          .error-page {
            text-align: center;
            padding: 2rem;
          }
          h1 {
            font-size: 4rem;
            margin: 0;
            color: #3b82f6;
          }
          p {
            color: #64748b;
            font-size: 1.25rem;
          }
          a {
            color: #3b82f6;
            text-decoration: none;
          }
          a:hover {
            text-decoration: underline;
          }
        </style>
      </head>
      <body>
        <div class="error-page">
          <h1>404</h1>
          <p>Page not found</p>
          <a href="/">Go home</a>
        </div>
      </body>
    </html>
    """
  end

  def render("500.html", _assigns) do
    """
    <!DOCTYPE html>
    <html>
      <head>
        <title>Internal Server Error</title>
        <style>
          body {
            font-family: system-ui, -apple-system, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background: #f8fafc;
          }
          .error-page {
            text-align: center;
            padding: 2rem;
          }
          h1 {
            font-size: 4rem;
            margin: 0;
            color: #ef4444;
          }
          p {
            color: #64748b;
            font-size: 1.25rem;
          }
          a {
            color: #3b82f6;
            text-decoration: none;
          }
          a:hover {
            text-decoration: underline;
          }
        </style>
      </head>
      <body>
        <div class="error-page">
          <h1>500</h1>
          <p>Internal server error</p>
          <a href="/">Go home</a>
        </div>
      </body>
    </html>
    """
  end

  def render("404.json", _assigns) do
    %{
      error: %{
        code: 404,
        message: "Not Found"
      }
    }
  end

  def render("500.json", _assigns) do
    %{
      error: %{
        code: 500,
        message: "Internal Server Error"
      }
    }
  end
end
