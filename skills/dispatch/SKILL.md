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
agent work. Outputs a `DISPATCH.md` file in the repo root.

## Response Format

Begin the first response to this skill invocation with the line:

`Entire Dispatch:`

followed by a blank line, then the content.

- Apply the header to the **first response of the invocation only.** Do not re-print it on
  follow-up turns within the same invocation.
- Do **not** include the header on error or early-exit responses (e.g. "not a git repository",
  "no commits found in the time window").

## Rules

1. Scope is always the **current repo** and **current branch** unless the user explicitly
   asks for all branches.
2. Default time window is **7 days**. If the user specifies a different window (e.g.
   "last two weeks", "14 days", "since Monday"), use it.
3. Do not require `entire login`. This skill works with local data only.
4. Write the final dispatch to `DISPATCH.md` at the repo root. If the file already exists,
   overwrite it.

## Process

### 1. Verify environment

Run `entire version` to confirm the CLI is available. If it fails, note the degraded mode
and proceed with the fallback workflow (skip to step 3b).

### 2. Determine time window

Default: 7 days ago from now. If the user specified a window (e.g. "last week",
"since Monday", "last 14 days", "past month"), parse it accordingly.

### 3a. Generate via CLI (preferred)

When the `entire` CLI is available, use the native dispatch generator:

```bash
entire dispatch --local --since <N>d
```

This command enumerates committed checkpoints in the time window, reads their metadata
(summary or prompt), applies a fallback chain (local_summary → commit_message), and
generates a markdown dispatch.

Capture the stdout output — it is the complete markdown dispatch text.

If `--all-branches` is appropriate (user asked for all branches), add the flag:

```bash
entire dispatch --local --since <N>d --all-branches
```

### 3b. Fallback workflow (no CLI)

When the `entire` CLI is not available, build the dispatch manually:

1. Gather commits with checkpoints in the time window:

```bash
git log --format='%H%x00%s%x00%b' --since="<N days ago>" HEAD
```

2. Parse the output to find commits with `Entire-Checkpoint:` trailers. Extract the 12-hex
   checkpoint ID from each trailer. Also collect commits without checkpoints for fallback
   coverage.

3. For each unique checkpoint ID:

```bash
entire explain --checkpoint <checkpoint-id> --json --no-pager
```

If `--json` fails, fall back to:

```bash
entire explain --checkpoint <checkpoint-id> --no-pager
```

4. Build bullet points using this priority:
   - Checkpoint summary outcome (if present and concise)
   - Latest user prompt in the session
   - Commit message subject line (fallback)

5. Generate a markdown document with this structure:

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

Group related work items thematically when patterns emerge. Fall back to chronological
ordering if no theme is apparent.

### 4. Write the file

Write the generated markdown to `DISPATCH.md` at the repo root.

### 5. Report

Present a brief summary to the user confirming what was generated:
- Time window covered
- Number of commits and checkpoints included
- Whether any commits lacked checkpoint context

## Degraded Mode (no Entire CLI)

If `entire` is not installed and `entire explain` is unavailable:
1. Use only commit messages as bullets
2. Add a note at the top of the dispatch: "Generated without Entire checkpoint context.
   Install the Entire CLI for richer dispatch output."
3. Still write `DISPATCH.md`

## Failure Modes

- **No commits in window**: Tell the user no commits were found and suggest widening the
  time window. Do not write an empty file.
- **No checkpoints but commits exist**: Generate dispatch from commit messages only.
  Note the limitation in the output.
- **`entire explain` fails for a specific checkpoint**: Skip that checkpoint and note it
  was unavailable. Continue with remaining checkpoints.
- **`entire dispatch --local` fails**: Fall back to the manual workflow in step 3b.
