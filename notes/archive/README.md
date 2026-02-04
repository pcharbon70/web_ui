# Archived Notes

This directory contains historical documentation that is **no longer current** due to the migration from WebUi.Agent/Dispatcher/CloudEvent to Jido.

## Migration Date

2026-02-04: Migrated from WebUi.Agent system to Jido.Agent.Server and Jido.Signal

## What Was Archived

### Summaries (`summaries/`)
- **section-2.\***: CloudEvent struct and builders (migrated to Jido.Signal)
- **section-4.1-elm-config**: Original Elm configuration (consolidated into phase-4.1-elm-setup)
- **section-5.\***: Agent behaviour, supervision, dispatch (migrated to Jido.Agent.Server)
- **phase-3.3-dispatcher**: Dispatcher implementation (replaced by Jido.Signal.Bus)

### Reviews (`reviews/`)
- **phase-3-architecture-review**: Pre-migration architecture review
- **phase-3-review**: Pre-migration Phase 3 review
- **phase-5-review**: Pre-migration Agent system review

### Feature (`feature/`)
- **section-2.\***: CloudEvent feature plans (replaced by Jido.Signal)
- **section-5.\***: Agent feature plans (replaced by Jido.Agent.Server)
- **phase-3.3-dispatcher**: Dispatcher feature (replaced by Jido.Signal.Bus)
- **phase-5-review-fixes**: Agent system review fixes (obsolete after migration)

### Phoenix Integration (`phoenix_integration/`)
- Original Phoenix integration notes (referenced old WebUi.CloudEvent)

## Current Implementation

For current implementation, see:
- **MIGRATION_TO_JIDO.md** (in parent notes/ directory) - Migration guide
- **Jido.Signal** - CloudEvents v1.0.2 implementation
- **Jido.Agent.Server** - Agent runtime with GenServer
- **Jido.Signal.Bus** - Event routing and pubsub
