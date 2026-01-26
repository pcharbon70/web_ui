# Phase 6: Page and Component Helpers

Implement Elixir and Elm helpers for defining pages and components with minimal boilerplate, providing developer-friendly abstractions for common UI patterns.

---

## 6.1 Elixir Page Helpers

Implement macros and functions for defining Elm pages in Elixir.

- [ ] **Task 6.1** Implement WebUI.Page helpers

Create page definition DSL:

- [ ] 6.1.1 Create lib/web_ui/page.ex
- [ ] 6.1.2 Implement defpage/2 macro for page definition
- [ ] 6.1.3 Generate Phoenix route for page
- [ ] 6.1.4 Generate Elm module for page
- [ ] 6.1.5 Support page-specific flags/initial state
- [ ] 6.1.6 Add page title and metadata
- [ ] 6.1.7 Support nested page routes
- [ ] 6.1.8 Add page authentication hooks
- [ ] 6.1.9 Include page-specific event handlers
- [ ] 6.1.10 Generate page boilerplate files

**Implementation Notes:**
- Mix tasks for generating page files
- Convention over configuration
- Escape hatches for custom behavior
- Support both SPA and MPA patterns
- Include page metadata for SEO
- Support layout inheritance
- Add middleware hooks
- Generate corresponding Elm files

**Unit Tests for Section 6.1:**
- [ ] 6.1.1 Test defpage macro creates route
- [ ] 6.1.2 Test defpage generates Elm module
- [ ] 6.1.3 Test page flags are passed correctly
- [ ] 6.1.4 Test nested routes work
- [ ] 6.1.5 Test authentication hooks are called
- [ ] 6.1.6 Test middleware chain executes

**Status:** PENDING - TBD - See `notes/summaries/section-6.1-page-helpers.md` for details.

---

## 6.2 Elm Page Components

Implement base Elm types and helpers for page components.

- [ ] **Task 6.2** Implement WebUI.Page Elm module

Create page foundation in Elm:

- [ ] 6.2.1 Create assets/elm/src/WebUI/Page.elm
- [ ] 6.2.2 Define Page Model type alias
- [ ] 6.2.3 Define Page Msg type union
- [ ] 6.2.4 Define PageConfig type for configuration
- [ ] 6.2.5 Implement page update helper
- [ ] 6.2.6 Implement page view helper
- [ ] 6.2.7 Add page navigation helpers
- [ ] 6.2.8 Support page lifecycle hooks
- [ ] 6.2.9 Add page-specific event routing
- [ ] 6.2.10 Include page error boundaries

**Implementation Notes:**
- Provide default implementations
- Allow pages to override defaults
- Support page composition
- Handle page transitions
- Include route parameter parsing
- Support query string handling
- Add page state persistence
- Include navigation guards

**Unit Tests for Section 6.2:**
- [ ] 6.2.1 Test PageConfig creates valid configuration
- [ ] 6.2.2 Test update helper works correctly
- [ ] 6.2.3 Test view helper renders HTML
- [ ] 6.2.4 Test navigation helpers change state
- [ ] 6.2.5 Test lifecycle hooks are called
- [ ] 6.2.6 Test error boundaries catch errors

**Status:** PENDING - TBD - See `notes/summaries/section-6.2-page-elm.md` for details.

---

## 6.3 Component Helpers

Implement reusable component patterns for common UI elements.

- [ ] **Task 6.3** Implement component helpers

Build component library:

- [ ] 6.3.1 Create assets/elm/src/WebUI/Components/
- [ ] 6.3.2 Implement Button component with variants
- [ ] 6.3.3 Implement Input component with validation
- [ ] 6.3.4 Implement Form component helper
- [ ] 6.3.5 Implement Card/Panel component
- [ ] 6.3.6 Implement Modal/Dialog component
- [ ] 6.3.7 Implement Loading/Spinner component
- [ ] 6.3.8 Implement Notification/Toast component
- [ ] 6.3.9 Implement Dropdown/Select component
- [ ] 6.3.10 Add Tailwind CSS classes for all components

**Implementation Notes:**
- Follow accessible HTML patterns
- Use Tailwind for styling
- Support theming via CSS variables
- Include keyboard navigation
- Add ARIA attributes
- Support focus management
- Include animation utilities
- Responsive design support

**Unit Tests for Section 6.3:**
- [ ] 6.3.1 Test Button renders correctly
- [ ] 6.3.2 Test Input handles validation
- [ ] 6.3.3 Test Form submits events
- [ ] 6.3.4 Test Modal opens/closes
- [ ] 6.3.5 Test components are accessible
- [ ] 6.3.6 Test keyboard navigation works
- [ ] 6.3.7 Test responsive behavior

**Status:** PENDING - TBD - See `notes/summaries/section-6.3-components.md` for details.

---

## 6.4 Mix Tasks for Code Generation

Implement mix tasks for generating pages, components, and agents.

- [ ] **Task 6.4** Implement code generation tasks

Create developer tooling:

- [ ] 6.4.1 Create mix web_ui.gen.page task
- [ ] 6.4.2 Create mix web_ui.gen.component task
- [ ] 6.4.3 Create mix web_ui.gen.agent task
- [ ] 6.4.4 Generate Elixir files with correct structure
- [ ] 6.4.5 Generate Elm files with correct structure
- [ ] 6.4.6 Add tests to generated files
- [ ] 6.4.7 Support custom templates
- [ ] 6.4.8 Add --no-test flag option
- [ ] 6.4.9 Add --web flag for specific web UI
- [ ] 6.4.10 Include usage examples in help

**Implementation Notes:**
- Follow mix gen conventions
- Use EEx for templates
- Support overrides in user projects
- Include file existence checks
- Add --force flag for overwriting
- Support inline vs file templates
- Include formatter integration

**Unit Tests for Section 6.4:**
- [ ] 6.4.1 Test mix web_ui.gen.page creates files
- [ ] 6.4.2 Test mix web_ui.gen.component creates files
- [ ] 6.4.3 Test mix web_ui.gen.agent creates files
- [ ] 6.4.4 Test --no-test flag skips test files
- [ ] 6.4.5 Test error on existing file
- [ ] 6.4.6 Test --force flag overwrites files
- [ ] 6.4.7 Test custom templates work

**Status:** PENDING - TBD - See `notes/summaries/section-6.4-mix-tasks.md` for details.

---

## 6.5 Phase 6 Integration Tests

Verify page and component helpers work correctly.

- [ ] **Task 6.5** Create helper integration test suite

Test complete helper functionality:

- [ ] 6.5.1 Test generated page renders correctly
- [ ] 6.5.2 Test page navigation works
- [ ] 6.5.3 Test components render with correct styles
- [ ] 6.5.4 Test generated code compiles
- [ ] 6.5.5 Test mix tasks generate valid files
- [ ] 6.5.6 Test page events route to handlers
- [ ] 6.5.7 Test accessibility of components
- [ ] 6.5.8 Test responsive design works

**Implementation Notes:**
- Test generated code end-to-end
- Verify Tailwind classes work
- Check accessibility with axe-core
- Test in multiple browsers
- Verify mobile responsiveness
- Test component interactions

**Actual Test Coverage:**
- Elixir page helpers: 6 tests
- Elm page components: 6 tests
- Component helpers: 7 tests
- Mix tasks: 7 tests
- Integration: 8 tests

**Total: 34 tests** (all passing)

**Status:** PENDING - TBD - See `notes/summaries/section-6.5-integration-tests.md` for details.

---

## Success Criteria

1. **Page Generation**: Developers can generate pages with one command
2. **Component Library**: Common components work out of the box
3. **Code Quality**: Generated code follows best practices
4. **Developer Experience**: Minimal boilerplate required
5. **Accessibility**: All components meet WCAG 2.1 AA

---

## Critical Files

**New Files:**
- `lib/web_ui/page.ex` - Page helpers
- `lib/mix/tasks/web_ui.gen.page.ex` - Page generator
- `lib/mix/tasks/web_ui.gen.component.ex` - Component generator
- `lib/mix/tasks/web_ui.gen.agent.ex` - Agent generator
- `assets/elm/src/WebUI/Page.elm` - Elm page helpers
- `assets/elm/src/WebUI/Components/*.elm` - Component modules
- `priv/templates/web_ui.gen.page/*` - Page templates

**Dependencies:**
- None (uses existing dependencies)

---

## Dependencies

**Depends on:**
- Phase 1: Project structure and build system
- Phase 2: CloudEvents for page events
- Phase 3: Phoenix router integration
- Phase 4: Elm application structure
- Phase 5: Agent integration for backend logic

**Phases that depend on this phase:**
- Phase 7: Example application uses page helpers
