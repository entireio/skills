---
name: dispatch
description: >
  Generate a markdown engineering dispatch summarizing recent agent work and
  write it to DISPATCH.md. Use when the user asks for a weekly summary, wants
  to know what was accomplished recently, or needs a status update of
  agent-driven development.
---

# Dispatch

Generate a concise markdown engineering dispatch summarizing recent checkpoint-backed
agent work on the current branch. Outputs a `DISPATCH.md` file in the repo root.

## Response Format

Begin the first response to this skill invocation with the line:

`Entire Dispatch:`

followed by a blank line, then the content.

- Apply the header to the **first response of the invocation only.** Do not re-print it on
  follow-up turns within the same invocation.
- Do **not** include the header on error or early-exit responses (e.g. "not a git repository",
  "no commits found in the time window").

## Rules

1. Scope is always the **current repo** and **current branch**. Do not attempt cross-repo or
   cross-branch aggregation.
2. Default time window is **7 days**. If the user specifies a different window (e.g.
   "last two weeks", "14 days", "since Monday"), use it.
3. Do not call any remote API. This is a purely local workflow.
4. Do not require `entire login`. The skill uses only local git history and `entire explain`.
5. If `entire` CLI is not installed, fall back to a commit-message-only dispatch and note the
   limitation clearly in the output.
6. Write the final dispatch to `DISPATCH.md` at the repo root. If the file already exists,
   overwrite it.

## Process

### 1. Verify environment

Run `entire version` to confirm the CLI is available. If it fails, note the degraded mode
and proceed with commit messages only (skip steps 4-5).

### 2. Determine time window

Default: 7 days ago from now. If the user specified a window (e.g. "last week",
"since Monday", "last 14 days", "past month"), parse it accordingly.

### 3. Gather commits with checkpoints

```bash
git log --format='%H%x00%s%x00%b' --since="<N days ago>" HEAD
```

Parse the output to find commits with `Entire-Checkpoint:` trailers. Extract the 12-hex
checkpoint ID from each trailer. Also collect commits without checkpoints for fallback
coverage.

### 4. Read checkpoint metadata

For each unique checkpoint ID found:

```bash
entire explain --checkpoint <checkpoint-id> --json --no-pager
```

Parse the JSON to extract session metadata. For each non-review session in the checkpoint,
prefer the summary (intent + outcome). If no summary is available, fall back to the latest
user prompt.

For long transcripts (>50KB), focus on the first 2000 chars (initial prompt) and last
5000 chars (final state) to extract the bullet.

If `--json` fails for a checkpoint, fall back to the bare human-readable output:

```bash
entire explain --checkpoint <checkpoint-id> --no-pager
```

Which shows the first prompt and associated commits — use the first prompt + commit
subject as the bullet. Do not use `--full` (it produces long narrative text harder
for agents to parse than structured JSON). If that also fails, skip the checkpoint
and note it was unavailable.

### 5. Build bullet points

For each checkpoint, determine the best "bullet" using this priority:
1. Final assistant summary from the transcript (if present and concise)
2. First user prompt in the session (what the user asked for)
3. Commit message subject line (fallback)

Combine the user's intent with what was actually accomplished. A good bullet reads like:
"Implemented X because the user asked for Y" or "Fixed X — user reported Y".

For commits without checkpoints, use the commit message subject line.

### 6. Generate the dispatch

Compose a markdown document with this structure:

```markdown
# Dispatch — <branch-name>

> <date-range>, <N> commits, <M> checkpoints

## Summary

<2-3 sentence high-level overview of what was accomplished>

## Work Items

### <grouped-by-theme-or-chronology>
- <bullet describing checkpoint/commit work>
- <bullet describing checkpoint/commit work>

## Files Changed

<top 10 most-touched files across all checkpoints, with change counts>
```

Group related work items thematically when patterns emerge (e.g. multiple checkpoints
touching the same feature). Fall back to chronological ordering if no theme is apparent.

### 7. Write the file

Write the generated markdown to `DISPATCH.md` at the repo root.

Present a brief summary to the user confirming what was generated:
- Time window covered
- Number of commits and checkpoints included
- Whether any commits lacked checkpoint context

## Degraded Mode (no Entire CLI)

If `entire` is not installed:
1. Skip checkpoint metadata retrieval
2. Use only commit messages as bullets
3. Add a note at the top of the dispatch: "Generated without Entire checkpoint context.
   Install the Entire CLI for richer dispatch output."
4. Still write `DISPATCH.md`

## Failure Modes

- **No commits in window**: Tell the user no commits were found and suggest widening the
  time window. Do not write an empty file.
- **No checkpoints but commits exist**: Generate dispatch from commit messages only.
  Note the limitation in the output.
- **`entire explain` fails for a specific checkpoint**: Skip that checkpoint and note it
  was unavailable. Continue with remaining checkpoints.
