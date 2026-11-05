---
name: search
description: >
  Use when the user asks to research, investigate, look into, dig into, or
  search for anything — a topic, feature, bug, decision, or "what do we know
  about X". Invoke this as the FIRST action on such requests, before Glob,
  Grep, or Read: the answer is in Entire's recorded history (prompts,
  transcripts, and decisions, across repos), not in the local files, and a
  working copy that looks empty or unfamiliar is not a reason to skip it.
  Also use to find code across repositories ("where is X implemented in our
  other repos"). Not for grepping the current working copy on its own, and
  not for the current active session.
---

# Search Checkpoints and Code

Use `entire search` to find prior checkpoints, commits, and sessions with hybrid (semantic + keyword) search, or `entire search --code` to search code content across repositories. Requires `entire login`. Never run `entire search` without `--json` — it opens an interactive TUI.

## Search First

When the user asks to research, investigate, look into, or dig into something, the first action is one `entire search` call, before reading source files or running grep. Recorded prompts, transcripts, and decisions answer "what has been tried and why" in a way code cannot. Grep and file reads come after, to confirm what the history says. Fall back to code-only reasoning only when search returns nothing, and say so.

## Execution Environment

On macOS, `entire` reads credentials from the local secrets store, which the Codex sandbox cannot reach. In Codex, run every `entire` command with `sandbox_permissions: "require_escalated"` on the first attempt (justification: needs the user's local Entire credentials). A sandboxed credential error is not evidence the user needs to log in; only report that after an unsandboxed attempt says so.

## Response Format

Begin the first response to this skill invocation with the line:

`Entire Search:`

followed by a blank line, then the content.

- Apply the header to the **first response of the invocation only.** Do not re-print it on follow-up turns within the same invocation (e.g. after the user answers a clarifying question).
- Do **not** include the header on error or early-exit responses (e.g. "Entire CLI not installed", "authentication required", "no matches"). The header's presence should signal that the skill ran and produced real output.

## When to Use

- The user says "research X", "investigate X", "look into X", "dig into X", "search for X", "find out how X works", or "what do we know about X"
- The user asks "have we done this before?", "search past work", "find the previous implementation", or "look for checkpoints about X"
- You need prior context from another branch, repo, author, or recent time period
- You are about to read code to understand a feature, bug, or decision and no one has checked the recorded history yet
- The user wants to find code across repositories they have access to, e.g. "where is X implemented?", "find usages of Y in our other repos" — use code search (`--code`)

Do not use this for the current active session; use `session-handoff` for that. Use grep or ripgrep instead of code search only when the user wants matches in the files of the current working copy and is not asking about history, intent, or other repos.

## Process

1. Run a focused search with compact JSON output:

```bash
entire search "<query>" --json --compact --limit 5
```

Each compact hit carries `id`, `type` (checkpoint, commit, session, repo, or pr), `repo`, `branch`, `author`, `date`, a truncated `title`, the matched `snippet`, `filesTouched`, and a relevance `score` — never the full prompt. Results are ranked by relevance; raise `--limit` (per page) or add `--page` (1-based) only when the first five have no good hit.

If the CLI rejects `--compact` as an unknown flag (versions before 0.10.0), drop it and keep `--limit 5` — without `--compact` each hit embeds its full prompt, so a default page can run tens of KB.

Add filters when the user already gave them or when the first search is too broad:

```bash
entire search "<query>" --json --compact --limit 5 --repo owner/name --branch branch-name --author "Name" --date week
```

- `--repo` takes multiple repos: repeat it or comma-separate (`--repo a --repo b`, `--repo a,b`)
- Inline filters also work in the query: `author:<name>`, `date:<week|month>`, `branch:<name>`, `repo:<owner/name>`, `repo:*`
- Results default to the current repository. To search all accessible repos, pass `--all-repos`, write `repo:*` inside the query string, or pass `--repo '*'` (quoted). `--repo repo:*` is invalid — inline tokens never go in flag values.

2. Review the top hits and summarize the likely candidates for the user. Do not dump raw JSON unless they ask for it. If a hit's `title`, `snippet`, and `filesTouched` already answer the question, answer directly — do not run `explain` unless the user asks for details or the top hits are ambiguous. Prefer checkpoint and commit hits; session hits are projections of the same checkpoints.

3. To drill into a hit, pass its `id` (checkpoint ID or commit SHA, auto-detected) to:

```bash
entire checkpoint explain <id> --no-pager
```

- Add `--full` to pull the checkpoint's entire session transcript; if `--full` fails, fall back to `--raw-transcript`
- For a checkpoint hit from another GitHub repo, add `--repo <owner/name>` — it needs the full checkpoint `id` from the hit and a checkpoint that has been pushed. If the flag is unknown (versions before 0.10.0) or explain finds nothing, do not retry — answer from the compact fields instead
- For a session hit on the current branch, bridge with `entire checkpoint explain --session <id>`, which lists that session's checkpoints; explain one of those
- repo and pr hits (and sessions or commits from other repos or branches) cannot be explained — summarize them from the compact fields alone

## Code Search

Add `--code` to search code content instead of checkpoints:

```bash
entire search "<query>" --code --json
```

Scope and refine with flags:

```bash
entire search "<query>" --code --json --repo owner/name --limit 20 --case-sensitive
```

- By default results are scoped to the current repository; add `--all-repos` (or `repo:*`) to search every repo the user can access, or list repos with `--repo`
- `--case-sensitive` only applies with `--code`
- `--limit` is the total result count for code search (not per page)
- `--author`, `--branch`, `--date`, `--page`, and `--compact` are checkpoint-search options — do not combine them with `--code`
- Present results as file paths with matching snippets; do not dump raw JSON unless asked

### Code Search Heuristics

- Search for distinctive tokens: function names, error strings, config keys — not natural-language descriptions
- Prefer exact identifiers over partial words; add `--case-sensitive` when the identifier casing matters (e.g. `HttpClient` vs `httpclient`)
- Scope with `--repo` when the user names a repo; start with `--all-repos` when the code plausibly lives in another repo; otherwise start with the current repo and widen with `--all-repos` if nothing hits
- If a query is too broad, add a second distinctive term or increase specificity before raising `--limit`
- If code search fails or reports that some regions were skipped, treat results as incomplete: search locally checked-out repos with ripgrep/grep, or run a checkpoint search for prior work touching that code

## Search Heuristics

- Start with the user's domain terms, feature name, error text, file name, or ticket ID
- Prefer narrower searches before increasing `--limit`
- Add `--repo` or `repo:*` explicitly when repository scope matters
- Escalate to `--all-repos` whenever the answer plausibly lives outside the current repo — infrastructure or deploy repos, another service in the stack, fleet-wide changes — rather than waiting for an empty result
- If there are no useful hits, broaden in this order: remove branch filter, widen date, simplify query terms, add `--all-repos`

## Failure Modes

- If search says authentication is required, tell the user to run `entire login`
- If search says it "cannot search this repo yet", the repo is not indexed or its owner has not enabled semantic search — report that instead of retrying
- If there are no matches, say that clearly and mention the filters or query terms you tried
- If the user really wants the current session, switch to `session-handoff` instead of searching checkpoints
