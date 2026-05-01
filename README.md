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

### `session-to-skill`

Turns Entire session history into a focused reusable skill draft without making the user manually find, paste, or reconstruct old agent conversations.

Current behavior:

- asks what reusable behavior the user wants to extract before reading transcripts
- accepts an explicit session ID or checkpoint ID when the user already has one
- searches Entire history with `entire search "<query>" --json` when the user describes a repeated workflow
- expands selected checkpoints with `entire explain --checkpoint <id> --full --no-pager`
- reads active session metadata from `.git/entire-sessions/<session-id>.json` when needed
- extracts durable lessons such as repo conventions, validation commands, user corrections, required inputs, and behaviors to avoid
- drafts a focused `SKILL.md` instead of recapping the whole session
- asks before writing, installing, or overwriting a skill

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

### `recall`

Turns "have we done this before?" into a task playbook by recalling the closest prior session for a described task and synthesizing what worked, gotchas, files touched, and a suggested approach for the new task.

Current behavior:

- runs paired `entire search` queries (the original task phrasing plus an alternate phrasing) and deduplicates by checkpoint ID
- scores hits by topical overlap with recency as a tiebreak, then reads the top 1-3 transcripts via `entire explain --checkpoint <id> --full --no-pager` (falls back to `--raw-transcript`)
- produces a playbook with sections for closest precedent, what worked, gotchas, files touched, suggested approach, and other relevant precedents
- broadens progressively (simplify query, drop date filter, drop branch filter) and reports each empty attempt before giving up

### `teach`

Builds a topic-focused guided lesson from 3-5 canonical checkpoints, with a mental model and patterns to remember rather than a flat list of search results.

Current behavior:

- searches over a 180-day window so the lesson uses canonical examples, not just recent activity
- scores hits by topical specificity (topic in prompt/title), transcript depth, and recency, and prefers diversity (different files, different authors) when picking the 3-5 anchors
- reads each anchor with `entire explain --checkpoint <id> --full --no-pager` (falls back to `--raw-transcript`)
- produces a lesson with what-you'll-learn, mental model, per-anchor lessons, patterns to remember, and where-to-go-next
- adds an optional small Mermaid diagram only when the topic has a clear behavioral flow worth illustrating

### `replay`

Steps through a feature's checkpoints chronologically, pausing for questions at each step instead of dumping a summary.

Current behavior:

- resolves either a topic ("how X was built") or a time window ("replay last week"), using `entire dispatch` to derive seed terms when needed
- builds a chronological sequence of up to 10 checkpoints by default and collapses near-duplicate prompts within a 30-minute window
- opens with a session card (topic, total steps, date range, primary authors) and then shows step 1 with a paired pause prompt
- on `next` / `continue` / `yes`, advances; on a question, answers from the current step's transcript only and re-prompts
- closes with 3-5 journey takeaways generalized across the steps

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
- "turn my blog publishing workflow into a skill"
- "make a skill from session 019ddbc1-a5bf-77e2-8b7a-b4094e850347"
- "I keep doing the same release notes workflow; find the sessions and draft a skill"
- `/explain parseConfig` — why does this function exist?
- `/explain src/auth.ts` — what drove this file's creation?
- "search past work for rate limiting"
- "find checkpoints about the migration"
- "have we done this before?"
- "recall how we added a tenant-scoped field last time"
- "find similar work for migrating a worker pool"
- "teach me how this repo handles auth"
- "school me on hooks"
- "give me a lesson on billing webhooks"
- "walk me through how the v2 checkpoints feature was built"
- "replay last week"
- "step me through how the doctor command was implemented"

## Checkpoint Resolution

Checkpoints are resolved in this order:

1. local `entire/checkpoints/v1` branch
2. `.entire/settings.json` `checkpoint_remote`
3. nearby local clone
