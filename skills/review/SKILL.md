---
name: review
description: >
  Review code changes on the current branch using checkpoint transcript context
  to understand developer intent before auditing the diff. Use when the user
  asks for a code review, wants to review branch changes, or asks to audit
  recent work before merging.
---

# Review

Review code changes on the current branch by first reading checkpoint transcripts to
understand the intent behind each change, then auditing the actual diff for issues.
This produces an intent-aware review that catches mismatches between what the developer
wanted and what the code actually does.

## Response Format

Begin the first response to this skill invocation with the line:

`Entire Review:`

followed by a blank line, then the content.

- Apply the header to the **first response of the invocation only.** Do not re-print it on
  follow-up turns within the same invocation.
- Do **not** include the header on error or early-exit responses (e.g. "not a git repository",
  "no commits found between branch and base").

## Rules

1. This is a **read-only audit**. Do not modify any files during the review.
2. Always show a scope banner before findings so the user knows what is being reviewed.
3. If checkpoint context is unavailable, still perform the review using only the diff and
   commit messages. Clearly state that the review lacks intent context.
4. Group findings by file. Within each file, order by severity (Critical > High > Medium > Low).
5. Every finding must include a concrete suggestion or explanation, not just flag the issue.
6. After presenting findings, ask the user if they want a fix plan. Do not auto-fix.
7. Do not review generated files, lock files, or binary files unless the user explicitly
   asks for them.

## Process

### 1. Verify environment

Run `entire version` to check if the CLI is available. If it is not installed, note that
the review will proceed without checkpoint intent context (degraded mode).

### 2. Detect base ref

Find the mainline branch to diff against. Try these refs in order and use the first that
exists:

```bash
git rev-parse --verify origin/HEAD 2>/dev/null
git rev-parse --verify origin/main 2>/dev/null
git rev-parse --verify origin/master 2>/dev/null
git rev-parse --verify main 2>/dev/null
git rev-parse --verify master 2>/dev/null
```

If none exist, tell the user no base ref was found and ask them to specify one.

### 3. Compute scope

```bash
git rev-list --count <base>..HEAD
git diff --stat <base>..HEAD
```

Record the number of commits and files changed. This forms the scope banner.

### 4. Gather checkpoint intent (skip in degraded mode)

```bash
git log --format='%H%x00%s%x00%b' <base>..HEAD
```

Extract `Entire-Checkpoint:` trailer values from commit bodies. Deduplicate checkpoint IDs.

For each unique checkpoint ID (up to 20):

```bash
entire explain --checkpoint <checkpoint-id> --json --no-pager
```

Parse the JSON to extract session metadata. For each non-review session in the checkpoint,
prefer the summary (intent + outcome). If no summary is available, fall back to the latest
user prompt. Truncate each checkpoint detail to 320 characters.

If `--json` fails for a checkpoint, fall back to the bare human-readable output:

```bash
entire explain --checkpoint <checkpoint-id> --no-pager
```

Do not use `--full` in the review workflow — it produces long narrative text harder for
agents to parse in bulk. If that also fails, skip the checkpoint and note it was unavailable.

Additionally, read the current in-progress session (if any) for uncommitted work context:

```bash
entire session current --json
```

If this returns valid JSON, extract `last_prompt` and `files_touched` — these represent
the intent behind uncommitted changes that are not yet captured in any checkpoint.

Build an intent map: for each file in the diff (committed + uncommitted), collect the
relevant intent context from all checkpoints and the active session that touched it.

### 5. Read the diff

```bash
git diff <base>..HEAD
```

Also include uncommitted changes:

```bash
git diff HEAD
```

For large diffs (>5000 lines total), focus on the most critical files:
- Files with the most changes
- Files mentioned in checkpoint intents
- Source files over generated/config files

Read individual file diffs as needed rather than loading the entire diff at once.

### 6. Perform the review

Read the review rules:

```
references/review-rules.md
```

For each file in the diff, review it considering:

**With checkpoint context:**
- Does the implementation match the stated intent?
- Were the constraints from the transcript respected?
- Did the agent miss edge cases it discussed?
- Are there leftover debugging artifacts or TODOs?

**Always (with or without context):**
- Logic errors, off-by-one, null safety
- Security issues (injection, auth bypass, data exposure)
- Performance concerns (N+1 queries, unnecessary allocations)
- Error handling gaps
- API contract violations
- Dead code or unreachable branches

### 7. Output findings

Present findings using severity prefixes that align with the `entire review --fix` parser:

```
Entire Review:

Reviewing <branch> vs <base>: N commits, M files changed
[Intent context: available from K checkpoints | unavailable — reviewing diff only]

## path/to/file.ts

Critical: <issue description>
  Intent: <what the checkpoint said this should do, if available>
  Actual: <what the code actually does>
  Fix: <concrete suggestion>

High: <issue description>
  Intent: <what the checkpoint said this should do, if available>
  Actual: <what the code actually does>
  Fix: <concrete suggestion>

Medium: <improvement opportunity>
  Issue: <what is wrong>
  Fix: <concrete suggestion>

## path/to/other-file.ts

Low: <observation that is not a bug but worth noting>

---

Found N issues (X critical, Y high, Z medium, W low).
Would you like me to create a fix plan for the critical and high issues?
```

When checkpoint context is unavailable for a finding, omit the `Intent:` line and use
`Issue:` / `Fix:` instead.

### 8. Offer follow-up

After presenting findings, wait for the user's response:
- If they say yes to a fix plan, outline specific steps to address each critical/high issue.
- If they ask to fix directly, switch to implementation mode and address the issues.
- If they decline, the review is complete.

## Degraded Mode (no Entire CLI or no checkpoints)

When checkpoint context is unavailable:
1. Skip step 4 entirely
2. In the scope banner, state: "Intent context unavailable — reviewing diff only"
3. Omit the "Intent:" line from findings
4. Still perform the full code-level review from step 6
5. Note at the end: "This review was performed without Entire checkpoint context. With
   checkpoints enabled, the review would also verify that implementation matches the
   original developer intent."

## Failure Modes

- **No commits between base and HEAD**: Tell the user the branch has no changes relative to
  the base. Do not output a review.
- **Cannot detect base ref**: Ask the user to specify the base branch or commit.
- **Diff too large (>100 files)**: Ask the user if they want to review all files or focus on
  a subset. Suggest reviewing only source files or files with checkpoint context.
- **`entire explain` fails**: Note the specific checkpoint was unavailable, continue reviewing
  remaining files without that context.
