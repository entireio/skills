# Gemini Packaging Design

**Date:** 2026-04-10

## Goal

Make this repository's Gemini integration match the upstream `obra/superpowers` pattern by exposing a root-level `gemini-extension.json` manifest and a root-level `GEMINI.md` entrypoint, while removing the legacy Gemini-specific install document.

## Current State

- Gemini support is currently documented only through [`.gemini/INSTALL.md`](/Users/alisha/Projects/agent-plugins/.gemini/INSTALL.md).
- Other agent integrations already use package or manifest-style entrypoints at predictable locations.
- Upstream Superpowers exposes Gemini through:
  - root `gemini-extension.json`
  - root `GEMINI.md`

## Chosen Approach

Adopt the upstream root-level manifest approach directly.

### Files to add

- `gemini-extension.json`
- `GEMINI.md`

### Files to update

- `README.md`

### Files to remove

- `.gemini/INSTALL.md`

## Design Details

### `gemini-extension.json`

Create a root manifest shaped like the upstream file:

- `name`
- `description`
- `version`
- `contextFileName`

The values should use this repository's metadata, with `contextFileName` set to `GEMINI.md`.

### `GEMINI.md`

Create a root Gemini entrypoint that points Gemini at this repo's skill bootstrap path. Since this repo does not mirror Superpowers' `skills/using-superpowers` tree, the file should reference the actual local skill entrypoint:

- `@./plugins/entire/skills/session-handoff/SKILL.md`

This keeps the Gemini experience aligned with the upstream packaging model while remaining correct for this repository's structure.

### README changes

Update the Gemini installation guidance so it no longer points to `.gemini/INSTALL.md`. The README should describe Gemini as using the root-level manifest and entrypoint, consistent with the Superpowers layout.

## Non-Goals

- No changes to the `session-handoff` skill behavior.
- No changes to Codex, Claude, Cursor, or OpenCode packaging.
- No attempt to preserve the old `.gemini/INSTALL.md` flow.

## Verification

- Confirm `gemini-extension.json` exists at the repository root.
- Confirm `GEMINI.md` exists at the repository root.
- Confirm `README.md` no longer references `.gemini/INSTALL.md`.
- Confirm `.gemini/INSTALL.md` has been removed.
