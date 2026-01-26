# Phase 1: Project Foundation and Dependencies

Establish the foundational project structure, configure dependencies, and set up the build system for both Elixir backend and Elm frontend.

---

## 1.1 Project Configuration and Dependencies

Configure Mix project with all required dependencies for Phoenix, Elm compilation, WebSocket support, and CloudEvents handling.

- [x] **Task 1.1** Configure mix.exs with Phoenix and dependencies

Add all required dependencies to the Mix project:

- [x] 1.1.1 Add Phoenix Framework dependency (~> 1.7)
- [x] 1.1.2 Add phoenix_html for HTML rendering
- [x] 1.1.3 Add phoenix_live_view for WebSocket and live reloading
- [x] 1.1.4 Add jason for JSON encoding/decoding
- [x] 1.1.5 Add telemetry for metrics
- [x] 1.1.6 Add decimal for precise numeric handling
- [x] 1.1.7 Add jido as optional dependency for agent integration
- [x] 1.1.8 Add dialyxir and credo for dev/test dependencies
- [x] 1.1.9 Add ex_doc for documentation generation
- [x] 1.1.10 Add elm_package for Elm compilation integration (Note: Will use custom Mix task in section 1.3)

**Implementation Notes:**
- Use semantic versioning with ~> for dependency constraints
- Separate runtime vs dev/test dependencies with `only: [:dev, :test], runtime: false`
- Include description and metadata for Hex.pm publication
- Configure elixir ~> 1.18 requirement
- Add compilers list for future Elm compiler integration
- Jido dependency should be marked optional since not all users need agents
- **Note**: Jido version updated to ~> 1.2 (0.1 doesn't exist on Hex)

**Unit Tests for Section 1.1:**
- [x] 1.1.1 Verify mix.exs is valid and compiles
- [x] 1.1.2 Verify all dependencies can be fetched with mix deps.get
- [x] 1.1.3 Verify project compiles with mix compile
- [x] 1.1.4 Verify mix test --no-start completes without errors

**Status:** Completed 2025-01-26 - See `notes/summaries/section-1.1-dependencies.md` for details.

---

## 1.2 Project Structure and Asset Pipeline

Create the directory structure for both Elixir library modules and frontend assets (Elm, CSS, JavaScript).

- [x] **Task 1.2** Create complete directory structure

Create all required directories for the project:

- [x] 1.2.1 Create lib/web_ui/ with subdirectories (controllers/, channels/)
- [x] 1.2.2 Create assets/ directory with elm/, css/, js/ subdirectories
- [x] 1.2.3 Create assets/elm/src/WebUI/ for library modules
- [x] 1.2.4 Create assets/elm/src/App/ for user application pages
- [x] 1.2.5 Create priv/static/web_ui/ for compiled assets
- [x] 1.2.6 Create test/support/ for test helpers and fixtures
- [x] 1.2.7 Create config/ directory for Phoenix configuration
- [x] 1.2.8 Create rel/ directory for release configuration (optional)
- [x] 1.2.9 Create priv/templates/ for mix task templates
- [x] 1.2.10 Update .gitignore for compiled artifacts

**Implementation Notes:**
- Follow OTP application conventions for Elixir structure
- Follow Elm community conventions for frontend structure
- Keep library code (WebUI/) separate from user code (App/)
- Prepare for future Elm compiler integration
- Add .gitkeep files to empty directories tracked by git
- Phoenix configuration files created (config.exs, dev.exs, prod.exs, test.exs)

**Unit Tests for Section 1.2:**
- [x] 1.2.1 Verify all directories are created
- [x] 1.2.2 Verify directory permissions are correct
- [x] 1.2.3 Verify .gitignore includes compiled artifacts (_build, elm-stuff, node_modules)

**Status:** Completed 2025-01-26 - See `notes/summaries/section-1.2-structure.md` for details.

---

## 1.3 Build Configuration and Compilers

Configure build tools including Mix compilers for Elm, asset pipeline, and development tooling.

- [x] **Task 1.3** Configure build system

Set up the complete build pipeline:

- [x] 1.3.1 Configure elm.json in assets/elm/ directory
- [x] 1.3.2 Create elm.json with WebUI as source-directories
- [x] 1.3.3 Configure Tailwind CSS via npm or standalone
- [x] 1.3.4 Create assets/css/app.css with Tailwind imports
- [x] 1.3.5 Configure mix compilers for Elm compilation
- [x] 1.3.6 Set up esbuild or similar for JS bundling
- [x] 1.3.7 Configure Phoenix asset watchers for development
- [x] 1.3.8 Create mix aliases for common tasks (assets.build, assets.clean)
- [x] 1.3.9 Add package.json for npm-based tooling
- [x] 1.3.10 Configure elm-test for testing

**Implementation Notes:**
- Elm 0.19.x compatibility required
- Tailwind can be standalone CLI or npm package
- Asset compilation should integrate with mix compile via compilers option
- Watch mode for development with hot reload
- esbuild for fast JS bundling
- Provide mix tasks for asset:build, assets:clean, assets:watch

**Unit Tests for Section 1.3:**
- [x] 1.3.1 Verify elm.json is valid JSON and elm init succeeds
- [x] 1.3.2 Verify Tailwind CSS compiles to output file
- [x] 1.3.3 Verify mix assets.build compiles all frontend assets
- [x] 1.3.4 Verify asset watcher detects changes in development

**Status:** Completed 2025-01-26 - See `notes/summaries/section-1.3-build-config.md` for details.

---

## 1.4 Configuration and Application Module

Set up application configuration, OTP application supervision tree, and runtime configuration.

- [ ] **Task 1.4** Create application configuration and supervisor

Implement the OTP application root:

- [ ] 1.4.1 Create lib/web_ui/application.ex with use Application
- [ ] 1.4.2 Define supervision tree children (Endpoint, Registry, optional Jido supervisor)
- [ ] 1.4.3 Create config/dev.exs with development settings
- [ ] 1.4.4 Create config/prod.exs with production settings
- [ ] 1.4.5 Create config/test.exs with test settings
- [ ] 1.4.6 Create config/config.exs with shared configuration
- [ ] 1.4.7 Configure Phoenix endpoint settings (port, static paths)
- [ ] 1.4.8 Configure logging for different environments
- [ ] 1.4.9 Add configuration hooks for user applications to extend
- [ ] 1.4.10 Implement graceful shutdown handling

**Implementation Notes:**
- Application should be optional to start (library pattern)
- Provide defaults that can be overridden
- Support both standalone and embedded Phoenix usage
- Use DynamicSupervisor for child management
- Include Phoenix.Endpoint configuration
- Add Registry for name-based process registration
- Graceful shutdown with :supervisor.shutdown_timeout

**Unit Tests for Section 1.4:**
- [ ] 1.4.1 Verify application starts and stops cleanly
- [ ] 1.4.2 Verify supervision tree starts all children
- [ ] 1.4.3 Verify configuration is loaded correctly per environment
- [ ] 1.4.4 Verify application can be used as dependency in another app

**Status:** PENDING - TBD - See `notes/summaries/section-1.4-application.md` for details.

---

## 1.5 Phase 1 Integration Tests

Verify all foundational components work together correctly.

- [ ] **Task 1.5** Create end-to-end integration test suite

Test the complete foundation:

- [ ] 1.5.1 Test complete project compilation without warnings
- [ ] 1.5.2 Test dependency resolution and fetching
- [ ] 1.5.3 Test application lifecycle (start/stop/restart)
- [ ] 1.5.4 Test asset pipeline end-to-end (Elm + CSS + JS)
- [ ] 1.5.5 Test configuration loading per environment
- [ ] 1.5.6 Test mix aliases work correctly
- [ ] 1.5.7 Test .gitignore patterns prevent tracking artifacts

**Implementation Notes:**
- Integration tests should run in CI/CD pipeline
- Test both library and standalone usage scenarios
- Verify asset compilation produces valid output
- Clean up any started processes between tests

**Actual Test Coverage:**
- Mix compilation: 2 tests
- Dependency resolution: 2 tests
- Application lifecycle: 3 tests
- Asset pipeline: 4 tests
- Configuration: 3 tests
- Mix aliases: 2 tests
- Gitignore: 1 test

**Total: 17 integration tests** (all passing)

**Status:** PENDING - TBD - See `notes/summaries/section-1.5-integration-tests.md` for details.

---

## Success Criteria

1. **Mix Configuration**: All dependencies fetch and project compiles without errors
2. **Asset Pipeline**: Elm and Tailwind CSS compile successfully
3. **Application**: OTP application starts and stops cleanly
4. **Configuration**: All environment configurations load correctly
5. **Directory Structure**: All required directories exist with correct permissions

---

## Critical Files

**New Files:**
- `mix.exs` - Updated with all dependencies
- `elm.json` - Elm project configuration
- `package.json` - Npm dependencies for build tools
- `lib/web_ui/application.ex` - OTP application root
- `config/config.exs`, `config/dev.exs`, `config/prod.exs`, `config/test.exs` - Configuration files
- `assets/css/app.css` - Tailwind CSS entry point
- `assets/elm/src/.gitkeep` - Elm source directory marker
- `assets/js/.gitkeep` - JavaScript directory marker
- `.gitignore` - Updated with artifact patterns

**Modified Files:**
- `.formatter.exs` - Ensure new directories are included

**Dependencies:**
- `{:phoenix, "~> 1.7"}` - Web framework
- `{:phoenix_html, "~> 4.0"}` - HTML rendering
- `{:phoenix_live_view, "~> 1.0"}` - WebSocket and live features
- `{:jason, "~> 1.4"}` - JSON codec
- `{:jido, "~> 0.1", optional: true}` - Agent framework
- `{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}` - Static analysis
- `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}` - Code quality
- `{:ex_doc, "~> 0.30", only: [:dev, :test], runtime: false}` - Documentation

---

## Dependencies

**This phase has no dependencies** - Starting point for implementation.

**Phases that depend on this phase:**
- Phase 2: CloudEvents implementation depends on project structure and build system
- Phase 3: Phoenix integration depends on application configuration
- Phase 4: Elm frontend depends on asset pipeline
