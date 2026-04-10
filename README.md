# Agent Plugins

Cross-agent skills and commands powered by Entire, modeled after `obra/superpowers`.

This repo is a shared plugin collection for:

- Codex
- Claude
- OpenCode
- Cursor
- Gemini

## What You Get

- Cross-agent skills for Entire workflows
- Root Gemini extension files at `gemini-extension.json` and `GEMINI.md`
- A Codex plugin package at `plugins/entire`
- A Cursor plugin manifest at `.cursor-plugin/`
- Install docs and manifests per agent platform
- A consistent handoff workflow across Codex, Claude, OpenCode, Cursor, and Gemini

## First Skill: `session-handoff`

`session-handoff` reads Entire session metadata and helps move work from one agent to another without making the user reconstruct the context manually.

Current behavior:

- auto-detects the most recent session from `.git/entire-sessions/`
- reads the raw transcript at the path stored in session metadata
- produces a structured compaction summary (Task Overview, Current State, Important Discoveries, Next Steps, Context to Preserve) instead of dumping raw transcript lines
- surfaces unanswered questions from the previous agent for the user to answer
- supports checkpoint handoff via `entire explain --checkpoint <id> --full --no-pager`
- falls back to `entire explain --checkpoint <id> --raw-transcript --no-pager` if full output is unavailable
- resolves checkpoints from: local `entire/checkpoints/v1` branch, `.entire/settings.json` `checkpoint_remote`, or nearby local clone
- filters sessions by agent name (e.g. "codex", "gemini") when mentioned

## Installation

Install the agent that matches your workflow from its marketplace or manifest entrypoint:

### Claude Code

Use `.claude-plugin/marketplace.json`.

### Codex

Use `plugins/entire/.codex-plugin/plugin.json`.

### OpenCode

Use the package-based flow in `.opencode/INSTALL.md`.

### Cursor

Use `.cursor-plugin/plugin.json`.

### Gemini

Use `gemini-extension.json` and `GEMINI.md`.

## Quick Start

Natural language examples:

- "hand off this session"
- "hand off the codex session"
- "pick up where codex left off"
- "hand off checkpoint 7b7c2be8a262"

## Checkpoint Resolution

Checkpoints are resolved in this order:

1. local `entire/checkpoints/v1` branch
2. `.entire/settings.json` `checkpoint_remote`
3. nearby local clone
