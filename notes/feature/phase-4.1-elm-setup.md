# Phase 4.1: Elm Project Setup and Configuration

**Branch:** `feature/phase-4.1-elm-setup`
**Date:** 2026-01-29
**Status:** In Progress

## Overview

Complete the Elm project configuration for the WebUI library. Most dependencies are already configured in elm.json, but we need to add production optimizations, code quality tools, and formatting configuration.

## Current State Analysis

### Already Configured (in assets/elm/elm.json)
- ✅ elm/browser: "1.0.2" - DOM manipulation
- ✅ elm/json: "1.1.3" - JSON encoding/decoding
- ✅ elm/time: "1.0.0" - Timestamp handling
- ✅ elm/html: "1.0.0" - HTML rendering
- ✅ elm/url: "1.0.0" - URL parsing
- ✅ elm-explorations/test: "2.1.1" - Testing framework
- ✅ source-directories: ["src"]
- ✅ Test elm.json exists

### Still Needed
- ❌ elm-optimize-level configuration for production builds
- ❌ elm-review configuration for code quality
- ❌ elm-format configuration for code formatting

## Implementation Plan

### 1. elm-optimize-level Configuration

Add optimization configuration to elm.json for production builds.

**File:** `assets/elm/elm.json`

Add `"elm-optimize-level": 2` for production (or 0 for development).

### 2. elm-review Configuration

Set up elm-review for code quality enforcement.

**Files to create:**
- `review/elm.json` - elm-review configuration
- `review/src/NoUnusedCustomTypeConstructorArgs.elm` - Example custom rule (optional)

**Dependencies:** elm-review (npm package)

### 3. elm-format Configuration

Add elm-format configuration for consistent code formatting.

**File:** `elm.json` or `.elmformat`

## Implementation Steps

### Step 1: Add elm-optimize-level to elm.json
- [ ] Add `"elm-optimize-level": 2` to assets/elm/elm.json
- [ ] Verify JSON is valid

### Step 2: Set up elm-review
- [ ] Create `review/elm.json` configuration
- [ ] Add elm-review npm script to package.json (if exists)
- [ ] Configure basic rules (NoUnused.CustomTypeConstructorArgs, etc.)

### Step 3: Add elm-format configuration
- [ ] Create `.elmformat` file
- [ ] Configure formatting preferences

### Step 4: Update mix.exs for elm-review
- [ ] Add elm-review command to compilers or aliases

### Step 5: Write tests
- [ ] Verify elm.json is valid JSON
- [ ] Verify elm make compiles (once Main.elm exists)
- [ ] Verify elm-test runs successfully
- [ ] Verify all dependencies are compatible

### Step 6: Documentation
- [ ] Update phase-4-elm-frontend.md planning document
- [ ] Create summary in notes/summaries/

## Files to Modify

1. **assets/elm/elm.json** - Add elm-optimize-level
2. **review/elm.json** - NEW - elm-review configuration
3. **.elmformat** - NEW - elm-format configuration
4. **mix.exs** - Add elm-review command alias
5. **notes/planning/poc/phase-4-elm-frontend.md** - Mark tasks complete

## Success Criteria

- [x] Feature branch created
- [ ] elm.json has elm-optimize-level configured
- [ ] elm-review is configured and can run
- [ ] elm-format is configured
- [ ] All tests pass
- [ ] Planning document updated
- [ ] Summary written

## Notes

- elm-optimize-level: 0 = no optimization, 1 = basic, 2 = full (production)
- elm-review helps catch common errors and enforce code style
- elm-format ensures consistent code style across the project

## Questions for Developer

None at this time. Proceeding with implementation.
