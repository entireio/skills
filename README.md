# Skills

Cross-agent skills and commands powered by Entire.

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
- asks for a concrete file line, range, or snippet before running provenance commands
- deduplicates commit and checkpoint lookups before running expensive transcript commands
- asks before expanding broad ranges with many unique commits
- summarizes `entire explain` output without dumping raw transcripts by default; raw transcript expansion is opt-in
- falls back to clearly labeled current-code analysis when checkpoint-backed context is unavailable

Examples:

- "tell me why this code is like that"
- "why does this code look like this?"
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

### `code-tour`

Builds an onboarding-oriented overview of an unfamiliar repo by combining architecture signals from git and manifests with recent Entire activity, hot files, and key contributors.

Current behavior:

- summarizes what the repo is from `README.md`, manifests, and top-level layout
- uses `entire dispatch --since 30d` as the primary recent-activity narrative
- derives focused `entire search` queries to identify recurring topics, hot files, and checkpoint-backed drill-down suggestions
- uses `entire explain --short --no-pager` to collect current-branch checkpoint anchors for follow-up prompts
- fails clearly when `entire` is missing, authentication is required, or the command is run outside a git repo

## Installation

Install with [skills](https://skills.sh/) CLI (universal, works with any [Agent Skills](https://agentskills.io)-compatible tool):

```bash
npx skills add https://github.com/entireio/skills --all
# or a single skill:
npx skills add https://github.com/entireio/skills --skill session-handoff
```

<!-- prettier-ignore-start -->

<details>
<summary>Claude Code</summary>

```bash
/plugin marketplace add entireio/skills
/plugin install entire
```

</details>

<details>
<summary>Cursor</summary>

Copy skills into the cross-client discovery directory:

```bash
git clone https://github.com/entireio/skills.git ~/.cursor/skills/entire
```

Cursor auto-discovers skills from `.agents/skills/` and `.cursor/skills/`.

</details>

<details>
<summary>Gemini CLI</summary>

```bash
gemini extensions install https://github.com/entireio/skills
```

Update with `gemini extensions update entire`.

</details>

<details>
<summary>OpenCode</summary>

Copy skills into the cross-client discovery directory:

```bash
git clone https://github.com/entireio/skills.git ~/.agents/skills/entire
```

OpenCode auto-discovers skills from `.agents/skills/`, `.opencode/skills/`, and `.claude/skills/`.

</details>

<details>
<summary>Codex (OpenAI)</summary>

Clone into the cross-client discovery path:

```bash
git clone https://github.com/entireio/skills.git ~/.agents/skills/entire
```

Codex auto-discovers skills from `~/.agents/skills/` and `.agents/skills/`. Update with `cd ~/.agents/skills/entire && git pull`.

</details>

<details>
<summary>Copilot</summary>

```bash
/plugin install https://github.com/entireio/skills
# or
git clone https://github.com/entireio/skills.git ~/.copilot/skills/entire
```

Copilot auto-discovers skills from `.copilot/skills/`.

</details>

<details>
<summary>Antigravity</summary>

Clone and symlink into the cross-client discovery path:

```bash
git clone https://github.com/entireio/skills.git ~/.antigravity/skills/entire
```

Update with `cd ~/.antigravity/skills/entire && git pull`.

</details>

<!-- prettier-ignore-end -->

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
- "give me a repo overview"
- "onboard me to this codebase"
- "where do I start in this repo?"

## Checkpoint Resolution

Checkpoints are resolved in this order:

1. local `entire/checkpoints/v1` branch
2. `.entire/settings.json` `checkpoint_remote`
3. nearby local clone
