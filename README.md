# Skills

Cross-agent skills and commands powered by Entire.

This repo is a shared skill collection for:

- Codex
- Claude
- OpenCode
- Cursor
- Gemini

## Skills

### `session-handoff`

Reads Entire session metadata and helps move work from one agent to another without making the user reconstruct the context manually.

Current behavior:

- auto-detects the most recent session from `.git/entire-sessions/`
- reads the raw transcript at the path stored in session metadata
- produces a structured compaction summary (Task Overview, Current State, Important Discoveries, Next Steps, Context to Preserve) instead of dumping raw transcript lines
- surfaces unanswered questions from the previous agent for the user to answer
- supports checkpoint handoff via `entire explain --checkpoint <id> --full --no-pager`
- falls back to `entire explain --checkpoint <id> --raw-transcript --no-pager` if full output is unavailable
- resolves checkpoints from: local `entire/checkpoints/v1` branch, `.entire/settings.json` `checkpoint_remote`, or nearby local clone
- filters sessions by agent name (e.g. "codex", "gemini") when mentioned

### `explain`

Traces source code back to the original conversation where it was created. Use `/explain` with a function, file, or line of code to understand _why_ it exists.

Current behavior:

- identifies the commit that introduced the code via git blame/log
- reads the session transcript via `entire explain --no-pager --commit <sha>`
- works with functions, files, and individual line changes
- reports clearly when code is untracked, uncommitted, or created outside an Entire session

### `what-happened`

Explains what happened to a specific code block by tracing the latest change for a file line,
range, or pasted snippet through git blame and Entire checkpoints.

Current behavior:

- resolves file lines, ranges, or pasted snippets to exact line numbers
- groups matching blame ranges by unique commit before running `entire explain`
- summarizes `entire explain` output without dumping raw transcripts by default
- falls back to clearly labeled current-code analysis when checkpoint-backed context is unavailable

Examples:

- "what happened here: `src/auth.ts:42-57`"
- "what happened at `src/auth.ts:42`"
- "what happened to this block?" plus a pasted snippet

### `search`

Searches Entire checkpoint history and transcripts to find prior work by topic, repo, branch, author, or time window.

Current behavior:

- runs `entire search "<query>" --json` and summarizes the top matches
- supports filters: `--repo`, `--branch`, `--author`, `--date`, and inline query filters like `author:<name>`, `date:week`
- drills into a specific result with `entire explain --checkpoint <id> --full --no-pager`
- broadens searches progressively when initial results are empty (remove branch filter, widen date, simplify terms)

## Installation

Install the agent that matches your workflow from its marketplace, manifest, or install-doc entrypoint:

### Claude Code (via Plugin Marketplace)

In Claude Code, register the marketplace first:

```bash
/plugin marketplace add entireio/skills
```

Then install the plugin from this marketplace:

```bash
/plugin install entire 
```

### Codex

Use `plugins/entire/.codex-plugin/plugin.json`.

### OpenCode

Use the package-based flow in `.opencode/INSTALL.md`.

### Cursor

Use `.cursor-plugin/plugin.json`.

### Gemini

```bash
gemini extensions install https://github.com/entireio/skills
```

## Quick Start

Natural language examples:

- "hand off this session"
- "hand off the codex session"
- "pick up where codex left off"
- "hand off checkpoint 7b7c2be8a262"
- `/explain parseConfig` — why does this function exist?
- `/explain src/auth.ts` — what drove this file's creation?
- "search past work for rate limiting"
- "find checkpoints about the migration"
- "have we done this before?"

## Checkpoint Resolution

Checkpoints are resolved in this order:

1. local `entire/checkpoints/v1` branch
2. `.entire/settings.json` `checkpoint_remote`
3. nearby local clone
