# WebUi

**A streamlined Elixir library for building web applications with Elm frontend and Phoenix backend.**

WebUi provides a declarative approach to building single-page applications following The Elm Architecture (TEA), with CloudEvents v1.0.2 for client-server communication via WebSockets.

## Features

- **Phoenix Backend**: Plug-and-play Phoenix channels for WebSocket communication
- **Elm Frontend**: Pre-configured Elm SPA with CloudEvents, WebSocket client, and routing
- **CloudEvents Support**: Built-in CloudEvents v1.0.2 implementation via Jido.Signal
- **Jido Integration**: Seamless integration with Jido agents for server-side business logic
- **Developer Tooling**: elm-review, elm-format, and 87 passing tests

## Architecture

```
┌─────────────┐           WebSocket           ┌──────────────┐
│             │  <───────────────────────>    │              │
│   Elm SPA   │     CloudEvents JSON         │  Phoenix     │
│  (Frontend)  │                              │  (Backend)    │
│             │                               │              │
└─────────────┘                               └──────┬───────┘
                                                     │
                                                     v
                                             ┌───────────────┐
                                             │  Jido Agents   │
                                             │  (Business     │
                                             │   Logic)       │
                                             └───────────────┘
```

## Installation

Add `web_ui` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:web_ui, "~> 0.1.0"},
    {:jido, "~> 1.2"}  # Required for CloudEvents and agents
  ]
end
```

## Quick Start

### 1. Install Dependencies

```bash
mix deps.get
cd assets && npm install
```

### 2. Configure WebSocket URL

In your Phoenix endpoint configuration:

```elixir
config :web_ui, WebUi.Endpoint,
  websocket_url: "ws://localhost:4000/socket",
  # ... other config
```

### 3. Initialize Elm from JavaScript

```javascript
var app = Elm.Main.init({
    flags: {
        websocketUrl: "ws://localhost:4000/socket/websocket",
        pageMetadata: {
            title: "My App",
            description: "My Application"
        }
    }
});
```

### 4. Run Tests

```bash
# Elixir tests
mix test

# Elm tests
cd assets && npm run elm:test

# Code quality
cd assets && npm run elm:review
```

## Project Structure

```
web_ui/
├── lib/web_ui/           # Elixir backend
│   ├── channels/         # Phoenix channels
│   ├── controllers/      # Page controllers
│   └── plugs/           # Security plugs
├── assets/              # Frontend assets
│   ├── elm/             # Elm source
│   │   ├── src/         # Application modules
│   │   └── tests/       # Elm tests (87 passing)
│   ├── css/             # Stylesheets
│   └── js/              # JavaScript interop
└── notes/               # Documentation
```

## Elm Modules

| Module | Description |
|--------|-------------|
| `WebUI.CloudEvents` | CloudEvents v1.0.2 type and codecs |
| `WebUI.Ports` | Elm-JavaScript interop ports |
| `WebUI.Internal.WebSocket` | WebSocket client with reconnection |
| `Main` | SPA entry point following TEA |

## Communication Protocol

WebUi uses **CloudEvents v1.0.2** for all client-server communication:

```json
{
  "specversion": "1.0",
  "id": "A234-1234-1234",
  "source": "/my-source",
  "type": "com.example.event",
  "data": {
    "message": "Hello!"
  }
}
```

## Jido Integration

WebUi uses [Jido](https://hexdocs.pm/jido) for:

- **Jido.Signal** - CloudEvents v1.0.2 implementation
- **Jido.Agent.Server** - Agent runtime with routing and lifecycle
- **Jido.Signal.Bus** - Event routing and pubsub

See `notes/MIGRATION_TO_JIDO.md` for migration details.

## Development

### Running the Application

```bash
mix phx.server
```

### Elm Development Tools

```bash
cd assets

# Run tests
npm run elm:test

# Code quality checks
npm run elm:review

# Format code
npm run elm:format

# Format check
npm run elm:format:check
```

## Documentation

- **Architecture**: See `notes/architecture/`
- **Migration Guide**: See `notes/MIGRATION_TO_JIDO.md`
- **Archived Notes**: See `notes/archive/` for historical documentation

## License

Same as Elixir/Phoenix - See LICENSE file.
