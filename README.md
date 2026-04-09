# Entire Agent Skills

Entire-specific skills modeled after `obra/superpowers`.

This repo is a shared skills pack for:

- Codex
- Claude
- OpenCode
- Cursor
- Gemini

## What You Get

- Cross-agent skills for Entire workflows
- Shared commands and install docs by agent
- A consistent handoff workflow across Codex, Claude, OpenCode, Cursor, and Gemini

## First Skill: `hand-off-session`

`hand-off-session` reads Entire session metadata and helps move work from one agent to another without making the user reconstruct the context manually.

Current behavior:

- uses `entire` CLI as the primary backend for session and checkpoint explanation
- reads sessions from `.entire/metadata`
- uses `entire explain --checkpoint <id> --full --no-pager` to read full checkpoint transcripts privately
- falls back to `entire explain --checkpoint <id> --raw-transcript --no-pager` if full transcript output is unavailable
- falls back to direct repo parsing when the CLI path is unavailable
- supports external checkpoint repos configured via `.entire/settings.json` `checkpoint_remote`
- allows explicit checkpoint repo override with `--checkpoint-repo <local-clone-path>`
- if no local checkpoint clone is available, tells the user that access to the remote checkpoint repo is required
- supports `list`, `latest`, `show`, and `all`
- keeps transcript content private by default
- returns a small summary instead of dumping raw transcript lines

## Installation

### Claude Code

Use the local plugin in `.claude-plugin/`.

Package contents:

- marketplace: `.claude-plugin/marketplace.json`
- skill: `hand-off-session`
- command: `hand-off-session`

### Codex

Open `.codex/INSTALL.md` and follow the install instructions for Codex.

### OpenCode

Open `.opencode/INSTALL.md` and follow the install instructions for OpenCode.

### Cursor

Open `.cursor/INSTALL.md` and follow the install instructions for Cursor.

### Gemini

Open `.gemini/INSTALL.md` and follow the install instructions for Gemini.

## Quick Start

Natural language examples:

- "hand off this session to codex"
- "get the latest active session"
- "get the latest active session for codex"
- "get the most recent session"
- "list current sessions"
- "show checkpoint `<id>`"

Command-style examples:

- `hand-off-session`
- `hand-off-session list`
- `hand-off-session latest`
- `hand-off-session active`
- `hand-off-session --agent codex latest`
- `hand-off-session --agent codex active`
- `hand-off-session show <session-id>`
- `hand-off-session show checkpoint <checkpoint-id>`
- `hand-off-session --checkpoint-repo <local-clone-path> show checkpoint <checkpoint-id>`

## External Checkpoint Repos

If a repo uses Entire `checkpoint_remote`, `hand-off-session` resolves checkpoints in this order:

1. explicit `--checkpoint-repo <path>`
2. `entire` CLI resolution when available in the current repo
3. local `entire/checkpoints/v1` branch
4. nearby local clone inferred from `.entire/settings.json`

If no local clone is available, the helper does not fetch automatically. It tells the user:

- which checkpoint repo is configured
- the derived remote URL when it can infer one
- that remote checkpoint repo access is required
- to either clone it locally or pass `--checkpoint-repo <path>`

## Repo Layout

The repo follows the same general shape as `superpowers`:

- `skills/` for source-of-truth skill instructions
