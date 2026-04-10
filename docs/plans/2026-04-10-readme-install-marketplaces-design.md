# README Marketplace Installation Design

**Date:** 2026-04-10

## Goal

Rewrite the repository README installation guidance so it matches the marketplace-oriented style used by `obra/superpowers`, while limiting changes to `README.md` only.

## Current State

- The installation section is organized as one heading per agent.
- Some entries point to install docs instead of marketplace or manifest entrypoints.
- The Codex entry references a `.codex/INSTALL.md` file that does not exist in this checkout.
- The repository already contains platform-facing artifacts that are better README targets:
  - `.claude-plugin/marketplace.json`
  - `plugins/entire/.codex-plugin/plugin.json`
  - `.cursor-plugin/plugin.json`
  - `.opencode/INSTALL.md`
  - `gemini-extension.json`
  - `GEMINI.md`

## Chosen Approach

Replace the current per-agent install-doc wording in `README.md` with a marketplace-oriented installation section that points each platform at its primary package or manifest entrypoint.

## Design Details

### Installation section structure

The README installation section should remain concise and should:

- open with a short sentence that installation differs by agent platform
- list each supported platform with the artifact or package reference users should start from
- prefer marketplace/manifests over secondary install docs

### Platform guidance

- Claude Code: point to `.claude-plugin/marketplace.json`
- Codex: point to `plugins/entire/.codex-plugin/plugin.json`
- Cursor: point to `.cursor-plugin/plugin.json`
- OpenCode: reference the package-based install flow already described in `.opencode/INSTALL.md`
- Gemini: point to `gemini-extension.json` and `GEMINI.md`

### Non-goals

- No changes to any install docs or plugin manifests
- No new platform support
- No attempt to standardize installation mechanics across all agents in this pass

## Verification

- Confirm `README.md` no longer refers to `.codex/INSTALL.md`
- Confirm the installation section references marketplace or manifest entrypoints for Claude, Codex, Cursor, and Gemini
- Confirm OpenCode wording references its package-style install path without modifying `.opencode/INSTALL.md`
