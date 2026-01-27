# ADR-002: Elm Asset Pipeline Strategy

**Status:** Accepted
**Date:** 2025-01-27
**Context:** Phase 1 Implementation
**Related:** Concern 2 from Phase 1 Review

## Context

The planning document suggested using `elm_toolbox` as a Mix compiler for Elm compilation. The implementation uses standard Elm tooling (npm/elm) instead.

## Decision

Use standard Elm tooling (elm-cli via npm) rather than elm_toolbox Mix compiler.

## Rationale

1. **Standard Tooling**: Using the official Elm compiler ensures:
   - Access to latest Elm features and bug fixes
   - Community-tested tooling
   - Official documentation applies directly

2. **Build Reliability**: The elm_toolbox project has had inconsistent maintenance. Standard elm-cli is actively maintained by the Elm core team.

3. **Developer Experience**: Most Elm developers are familiar with:
   - `elm make` for compilation
   - `elm test` for testing
   - `elm format` for code formatting
   - Standard elm.json project format

4. **Integration Strategy**: WebUI uses Phoenix asset watchers which work well with standard build tools:
   - Mix aliases for asset compilation (`mix assets.build`)
   - Phoenix detects file changes and triggers rebuilds
   - No need for custom Mix compiler complexity

5. **CI/CD Compatibility**: Standard Elm tooling integrates better with:
   - GitHub Actions
   - Docker containers
   - Various CI platforms

## Implementation Details

### Asset Pipeline Configuration

```elixir
# mix.exs aliases
aliases: [
  "assets.build": ["cmd npm --prefix assets run build"],
  "assets.clean": ["cmd npm --prefix assets run clean"],
  "assets.watch": ["cmd npm --prefix assets run watch"]
]
```

### Package.json Scripts

```json
{
  "scripts": {
    "build": "elm make src/Main.elm --optimize --output=../priv/static/assets/main.js",
    "watch": "elm watch src/Main.elm --output=../priv/static/assets/main.js",
    "clean": "rm -rf ../priv/static/assets/main.js"
  }
}
```

### Phoenix Endpoint Configuration

The Phoenix endpoint watches Elm source files and triggers rebuilds on changes.

## Consequences

**Positive:**
- Standard, well-documented tooling
- Active maintenance from Elm core team
- Better developer onboarding (Elm docs apply directly)
- Improved CI/CD compatibility

**Negative:**
- Slight deviation from planning document (documented here)
- Requires Node.js/npm in addition to Erlang/Elixir
- Manual Mix aliases instead of automatic compiler

## Alternatives Considered

1. **elm_toolbox Mix Compiler**: Rejected due to maintenance concerns and non-standard approach
2. **webpack-elm-loader**: Rejected as overkill for Elm compilation
3. **elixir-elm**: Rejected due to limited features compared to elm-cli

## References

- Elm Language: https://elm-lang.org/
- Elm Guide: https://guide.elm-lang.org/
- Planning Document: notes/feature/section-1.3-build-config.md
