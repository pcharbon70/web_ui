# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**WebUI** is an Elixir library designed to provide a streamlined, declarative way to build web applications using Elm for the frontend and Elixir/Phoenix for the backend. The architecture follows CloudEvents specification for client-server communication and integrates with Jido agents for server-side state management and business logic.

The goal is to provide an experience as streamlined as `TermUi` (for terminal UIs) but for web applications.

## Architecture

### High-Level Design

The application follows a layered architecture:

1. **Frontend (Elm SPA)** - Single Page Application following The Elm Architecture
2. **Communication Layer** - CloudEvents over WebSockets
3. **Backend (Elixir/Phoenix)** - Web server with Phoenix channels
4. **Service Layer (Jido)** - Agent-based business logic and state management

### Key Components

- **CloudEvents** - All client-server communication follows the CloudEvents specification
- **Phoenix Channels** - WebSocket handling for bi-directional CloudEvents
- **Jido Agents** - Server-side state management and business logic
- **Co-located JavaScript** - JS interop via Elm ports for browser-specific features
- **Tailwind CSS** - Styling for Elm-generated HTML

## Development Commands

### Building and Compiling

```bash
# Compile Elixir code
mix compile

# Format Elixir code (automatically runs via hooks)
mix format

# Check code quality with Credo
mix credo

# Run static analysis with Dialyzer
mix dialyzer
```

### Testing

```bash
# Run all tests
mix test

# Run a specific test file
mix test path/to/file_test.exs

# Run a specific test line
mix test path/to/file_test.exs:42

# Run tests with coverage
mix test --cover
```

### Security

```bash
# Run security audit
mix deps.audit

# Check for security vulnerabilities
mix sobelow
```

## Project Structure

```
web_ui/
├── lib/web_ui/           # Library core modules
├── assets/               # Frontend assets (planned)
│   ├── elm/             # Elm source files
│   ├── css/             # Tailwind CSS
│   └── js/              # JavaScript interop
├── notes/research/       # Architecture and design docs
└── test/                 # Test files
```

## Agent System Integration

This repository uses a specialized agent orchestration system. Key points:

- **elixir-expert**: MANDATORY for all Elixir/Phoenix work
- **research-agent**: MANDATORY for technical research and unfamiliar libraries
- **architecture-agent**: Consult for code placement and module organization
- **ALL REVIEWERS**: Run in parallel after any Elixir changes (elixir-reviewer, qa-reviewer, security-reviewer, consistency-reviewer, etc.)

### Four-Phase Workflow

For complex features:
1. `/research` - Codebase impact analysis
2. `/plan` - Strategic implementation planning
3. `/breakdown` - Task decomposition
4. `/execute` - Implementation execution

## Code Formatting

A post-tool hook automatically formats files after Edit/Write operations:
- Elixir files (`.ex`, `.exs`) → `mix format`
- JavaScript/TypeScript → Prettier (if available)
- Markdown → Prettier (if available)

The hook is located at `.claude/hooks/format-code.sh`.

## References

See `notes/research/1.01-architecture/` for detailed architectural design documents:
- `1.01.1-original-design.md` - Original architecture overview
- `1.01.2-elm-architecture.md` - Detailed Elm integration design
