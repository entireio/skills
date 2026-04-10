---
description: Use when the user wants to find prior work, checkpoints, or agent conversations by topic, repo, branch, author, or recent time window
---

# Search Checkpoints

Use `entire search` to find relevant checkpoints before guessing from memory.

## When to Use

- The user asks things like "have we done this before?", "search past work", "find the previous implementation", or "look for checkpoints about X"
- You need prior context from another branch, repo, author, or recent time period
- You want likely matches first, then a deeper transcript read only for the best hit

Do not use this for the current active session. Use `session-handoff` for that.

## Process

1. Run a focused search with JSON output so results are easy to inspect:

```bash
entire search "<query>" --json
```

Add filters when the user already gave them or when the first search is too broad:

```bash
entire search "<query>" --json --repo owner/name --branch branch-name --author "Name" --date week
```

Inline filters are also supported in the query: `author:<name>`, `date:<week|month>`, `branch:<name>`, `repo:<owner/name>`, `repo:*`.

2. Review the top matches and summarize the likely candidates for the user. Do not dump raw JSON unless they ask for it.

3. If the user wants details on a specific result, open the checkpoint with:

```bash
entire explain --checkpoint <checkpoint-id> --full --no-pager
```

If `--full` fails, fall back to:

```bash
entire explain --checkpoint <checkpoint-id> --raw-transcript --no-pager
```

## Search Heuristics

- Start with the user's domain terms, feature name, error text, file name, or ticket ID
- Prefer narrower searches before increasing `--limit`
- Add `--repo` or `repo:*` explicitly when repository scope matters
- If there are no useful hits, broaden in this order: remove branch filter, widen date, simplify query terms

## Failure Modes

- If search says authentication is required, tell the user to run `entire login`
- If there are no matches, say that clearly and mention the filters or query terms you tried
- If the user really wants the current session, switch to `session-handoff` instead of searching checkpoints
