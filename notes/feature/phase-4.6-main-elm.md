# Phase 4.6: Elm Main Application Entry Point

**Branch:** `feature/phase-4.6-main-elm`
**Date:** 2026-01-29
**Status:** Complete

## Overview

Implement the Main.elm entry point that ties together all Elm modules. This is the root of the Elm SPA following The Elm Architecture (TEA).

## Types to Define

### Flags

```elm
type alias Flags =
    { websocketUrl : String
    , pageMetadata : PageMetadata
    }

type alias PageMetadata =
    { title : Maybe String
    , description : Maybe String
    }
```

### Model

```elm
type alias Model =
    { wsModel : WebSocket.Model
    , page : Page
    , flags : Flags
    , key : Nav.Key
    }
```

### Page

```elm
type Page
    = HomePage
    | NotFound
```

### Msg

```elm
type Msg
    = WebSocketMsg WebSocket.Msg
    | ReceivedCloudEvent String
    | ConnectionChanged WebSocket.State
    | LinkClicked Url.Request
    | UrlChanged Url.Url
    | SentCloudEvent String
```

## Implementation Plan

### Step 1: Create Main.elm

Create `assets/elm/src/Main.elm` with:
- Platform.programWithFlags
- Model and Msg types
- init, update, view, subscriptions

### Step 2: Implement init

Create init function that:
- Parses flags
- Initializes WebSocket model
- Sets up routing
- Returns initial commands

### Step 3: Implement update

Create update function that:
- Handles WebSocket messages
- Handles CloudEvents
- Handles navigation
- Routes messages to page handlers

### Step 4: Implement view

Create view function that:
- Renders connection status indicator
- Renders current page
- Provides navigation links

### Step 5: Implement subscriptions

Subscriptions for:
- WebSocket messages
- Connection status
- Navigation changes

## Files to Create

1. `assets/elm/src/Main.elm` - Main application module
2. `assets/elm/tests/MainTest.elm` - Tests
3. `notes/summaries/section-4.6-main-elm.md` - Summary

## Files to Modify

1. `notes/planning/poc/phase-4-elm-frontend.md` - Mark tasks complete
2. `assets/elm/elm.json` - Add elm/browser dependency (already there)

## Success Criteria

- [x] Feature branch created
- [ ] Main.elm module created
- [ ] Model, Msg, Flags types defined
- [ ] init, update, view, subscriptions implemented
- [ ] WebSocket lifecycle handled
- [ ] CloudEvent handling implemented
- [ ] Basic routing implemented
- [ ] All tests pass
- [ ] Planning document updated
- [ ] Summary written

## Notes

- Follow The Elm Architecture strictly
- Keep Main minimal - delegate to page modules
- WebSocket connection starts from flags
- URL routing for SPA navigation
- Connection status indicator in UI

## Questions for Developer

None at this time. Proceeding with implementation.
