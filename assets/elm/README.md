# WebUI Elm Frontend

Elm Single Page Application for WebUI library.

## Setup

1. Install Elm:
   ```bash
   # On macOS
   brew install elm

   # On Linux
   npm install -g elm

   # Or download from https://elm-lang.org/
   ```

2. Install dependencies:
   ```bash
   cd assets/elm
   elm install
   ```

3. Install dev tools (via npm):
   ```bash
   npm install
   ```

## Development

### Run tests:
```bash
npm run test:elm
# or directly
elm-test
```

### Format code:
```bash
npm run format:elm
# or check formatting
npm run format:elm:check
```

### Run code review:
```bash
npm run review:elm
# or directly
elm-review
```

## Build

The elm-optimize-level is set to 2 (full optimization) for production builds.

## Project Structure

```
assets/elm/
├── elm.json           # Elm package configuration
├── src/
│   ├── WebUI/         # WebUI library code
│   └── App/           # User application code
└── tests/             # Elm tests
    └── elm.json       # Test configuration
```

## Review Configuration

The `review/` directory contains elm-review configuration for code quality enforcement.

See `review/src/ReviewConfig.elm` for configured rules.
