---
name: search
description: Use when the user wants to find prior work, checkpoints, or agent conversations by topic, repo, branch, author, or recent time window, or to search code content across repositories
---

# Search Checkpoints and Code

Use `entire search` to find relevant checkpoints before guessing from memory, or `entire search --code` to search code content across repositories.

## Response Format

Begin the first response to this skill invocation with the line:

`Entire Search:`

followed by a blank line, then the content.

- Apply the header to the **first response of the invocation only.** Do not re-print it on follow-up turns within the same invocation (e.g. after the user answers a clarifying question).
- Do **not** include the header on error or early-exit responses (e.g. "Entire CLI not installed", "authentication required", "no matches"). The header's presence should signal that the skill ran and produced real output.

## When to Use

- The user asks things like "have we done this before?", "search past work", "find the previous implementation", or "look for checkpoints about X"
- You need prior context from another branch, repo, author, or recent time period
- You want likely matches first, then a deeper transcript read only for the best hit
- The user wants to find code across repositories they have access to, e.g. "where is X implemented?", "find usages of Y in our other repos" — use code search (`--code`)

Do not use this for the current active session. Use `session-handoff` for that. For searching files in the current working copy, prefer local tools (grep, ripgrep) over code search.

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
entire checkpoint explain --checkpoint <checkpoint-id> --full --no-pager
```

If `--full` fails, fall back to:

```bash
entire checkpoint explain --checkpoint <checkpoint-id> --raw-transcript --no-pager
```

## Code Search

Add `--code` to search code content instead of checkpoints:

```bash
entire search "<query>" --code --json
```

Scope and refine with flags:

```bash
entire search "<query>" --code --json --repo owner/name --limit 20 --case-sensitive
```

- By default results are scoped to the current repository; add `--all-repos` (or `repo:*`) to search every repo the user can access
- `--case-sensitive` only applies with `--code`
- `--limit` is the total result count for code search (not per page)
- `--author`, `--branch`, and `--date` are checkpoint filters — do not combine them with `--code`
- Present results as file paths with matching snippets; do not dump raw JSON unless asked

### Code Search Heuristics

- Search for distinctive tokens: function names, error strings, config keys — not natural-language descriptions
- Prefer exact identifiers over partial words; add `--case-sensitive` when the identifier casing matters (e.g. `HttpClient` vs `httpclient`)
- Scope with `--repo` when the user names a repo; otherwise start with the current repo and widen with `--all-repos` if nothing hits
- If a query is too broad, add a second distinctive term or increase specificity before raising `--limit`

### Code Search Fallback

Code search is currently limited to admins and users on the insider list. If a `--code` search fails with "not yet available" or an access/permission error, do not retry — fall back:

1. Tell the user code search requires admin or insider access
2. If the target repo is checked out locally, search it with local tools (ripgrep, grep) instead
3. For cross-repo questions, run a checkpoint search (`entire search "<query>" --json`, optionally `repo:*`) to find prior work that touches the code in question

## Search Heuristics

- Start with the user's domain terms, feature name, error text, file name, or ticket ID
- Prefer narrower searches before increasing `--limit`
- Add `--repo` or `repo:*` explicitly when repository scope matters
- If there are no useful hits, broaden in this order: remove branch filter, widen date, simplify query terms

## Failure Modes

- If search says authentication is required, tell the user to run `entire login`
- If code search says it is not available or access is denied, it is limited to admins and insiders — use the Code Search Fallback above rather than retrying
- If there are no matches, say that clearly and mention the filters or query terms you tried
- If the user really wants the current session, switch to `session-handoff` instead of searching checkpoints
