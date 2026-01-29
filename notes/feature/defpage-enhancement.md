# Feature: defpage Macro Enhancement

**Branch:** `feature/defpage-enhancement`
**Date:** 2026-01-29
**Status:** In Progress

## Overview

Enhance the `defpage` macro to actually pass metadata (title, description, etc.) to the controller so it can be rendered in the HTML template.

## Problem Statement

Currently, the `defpage` macro accepts metadata options but ignores them:

```elixir
defmacro defpage(path, _opts \\ []) do
  quote do
    Phoenix.Router.get(unquote(path), PageController, :index)
  end
end
```

The `_opts` are prefixed with underscore, indicating they're intentionally unused. This means metadata like `title`, `description`, `keywords`, etc. cannot be used by the application.

## Requirements

### Task 1: Pass Metadata to Controller

**Status:** Pending

Modify the `defpage` macro to pass metadata to the controller via a private plug or route metadata.

### Task 2: Update PageController

**Status:** Pending

Update `PageController.index/2` to handle and use page metadata.

### Task 3: Update HTML Template

**Status:** Pending

Update the SPA template to render metadata tags (title, meta description, Open Graph, etc.).

### Task 4: Update pages/1 Macro

**Status:** Pending

Update the `pages/1` macro to also pass metadata.

### Task 5: Add Tests

**Status:** Pending

Add tests for defpage metadata passing and rendering.

## Design Decisions

### Approach: Private Plug with Metadata

The cleanest approach is to use a private plug that runs before the controller:

```elixir
defmacro defpage(path, opts \\ []) do
  quote do
    pipeline :browser do
      plug(WebUi.Plugs.PageMetadata, unquote(opts))
    end

    Phoenix.Router.get(unquote(path), PageController, :index)
  end
end
```

However, this has issues with pipeline ordering. A better approach is to store metadata in module attributes and retrieve it at runtime, or use a plug that sets assigns based on a lookup.

### Alternative: Route Metadata via Private Plug

Create a plug that sets assigns based on the current path:

```elixir
defmodule WebUi.Plugs.PageMetadata do
  def init(opts), do: opts

  def call(conn, metadata) do
    # Set assigns for title, description, etc.
    conn
    |> assign(:page_title, Keyword.get(metadata, :title))
    |> assign(:page_description, Keyword.get(metadata, :description))
    # ... other metadata
  end
end
```

### Chosen Approach: Inline Plug in Route Definition

Use Phoenix's ability to add plugs directly to routes:

```elixir
defmacro defpage(path, opts \\ []) do
  quote do
    opts = unquote(opts)

    Phoenix.Router.get(
      unquote(path),
      PageController,
      :index,
      private: %{page_metadata: opts}
    )
  end
end
```

Then a plug can retrieve this from `conn.private[:page_metadata]` and set assigns.

## Progress Tracking

| Task | Status | Notes |
|------|--------|-------|
| 1: Pass metadata to controller | Pending | |
| 2: Update PageController | Pending | |
| 3: Update HTML template | Pending | |
| 4: Update pages/1 macro | Pending | |
| 5: Add tests | Pending | |

## Questions for Developer

*No questions yet.*
