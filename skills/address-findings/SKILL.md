---
name: address-findings
description: >
  Address the review findings posted on an Entire trail: fetch the trail's open
  findings, fix the code, and resolve them on the trail. Use when the user gives
  a trail URL or number and asks to address, fix, or resolve its findings or
  review comments. Not for local diff review — that is the `review` skill.
argument-hint: <trail url or number>
---

# Address Findings

Fix and resolve the open review findings on an Entire trail. A finding is a
review comment posted to a trail on entire.io: it has a file/line location, a
body, a severity, and sometimes a suggested unified-diff patch. This skill
fetches the open findings, applies or hand-fixes each one in the current
worktree, and marks it resolved on the trail.

## When to use / not use

Use when the user points at a trail — a URL like
`https://<host>/<forge>/<owner>/<repo>/trails/<number>/<slug>`, or a bare trail
number or branch — and asks to **address / fix / resolve** its findings or
review comments.

Do **not** use this skill for:

- A code review of the current diff — that is the `review` skill (read-only).
- Creating new findings — use `entire trail finding add`.

## Response Format

Begin the first response to this skill invocation with the line:

`Entire Address Findings:`

followed by a blank line, then the content. Apply the header to the **first
response only**. Omit it on error / early-exit responses (CLI missing, not
authenticated, trail not found, branch mismatch, no open findings).

## Rules

1. Make the smallest correct change that addresses each finding. Do not expand scope.
2. Only mark a finding resolved when you actually addressed it. If a finding is
   ambiguous or needs a human decision, leave it open and report it.
3. Do not commit or push. Leave changes in the working tree for the user to review.
4. Never weaken a test or assertion just to clear a finding.

## Process

### 1. Verify the CLI

Run `entire version`. If the command is not found, stop and tell the user:
"The Entire CLI is required but not installed. Install it from
https://entire.io/docs/cli and try again."

### 2. Resolve the trail selector

- If the argument is a trail URL, take the number from the `/trails/<number>/`
  path segment and use that number.
- If it is a bare trail number, id, or branch name, use it as-is.
- If you cannot determine a trail, stop and ask the user for the trail URL or number.

Use this value as the `<trail>` selector for every command below. `entire trail`
accepts a trail number, id, or branch name interchangeably, so no number lookup
is needed — a branch name works directly.

### 3. Fetch open findings

```bash
entire trail finding list <trail> --json --status open
```

- If the output reports that authentication is required, stop and tell the user:
  "`entire trail finding list` requires authentication. Run `entire login` and try again."
- If the `trail finding` subcommand is unavailable, or the API reports the
  feature is not enabled, stop and tell the user that trail findings may not be
  enabled for this account or repository. Do not invent findings.
- Parse the JSON. Each finding has an id, a severity, a status, a body, a
  location (file path + line range), and may include a suggested change (a
  unified diff).
- If there are no open findings, report "No open findings on this trail." and stop.

### 4. Branch guard (you must be on the trail's branch)

`entire trail finding apply` edits the local worktree, so you must be on the
trail's branch before changing files.

```bash
git rev-parse --abbrev-ref HEAD                # current branch
entire trail list --json --status any -n 200   # locate the trail's branch
```

Find the trail whose `number` or `branch` matches your selector and read its `branch`.

- If the trail's branch differs from the current branch, stop and tell the user:
  "Trail `<trail>` targets branch `<trail-branch>`, but you are on
  `<current-branch>`. Check it out first (`entire trail checkout <trail>`) and
  re-run." Do not edit files.
- If you cannot find the trail in the list (e.g. pagination), do not hard-fail:
  warn that you could not verify the branch, and ask the user to confirm they are
  on the trail's branch before you continue.

### 5. Address each finding

Process findings highest severity first (high → medium → low). For each:

1. **If it has a suggested unified-diff change**, dry-run it first:

   ```bash
   entire trail finding apply <trail> <finding-id> --check
   ```

   If it applies cleanly, apply and resolve in one step:

   ```bash
   entire trail finding apply <trail> <finding-id> --resolve
   ```

2. **Otherwise** (no patch, the patch conflicts, or the fix needs reasoning):
   read the finding body, open the file at its location, and make the smallest
   correct edit that addresses it. If a fast, relevant local check exists for the
   touched code (a build or a focused test), run it. Then resolve:

   ```bash
   entire trail finding resolve <trail> <finding-id> -m "<one line: what you changed>"
   ```

3. **If you cannot confidently address it** (ambiguous, needs a product/design
   decision, or out of scope): leave it open, do not resolve it, and record it
   for the report.

### 6. Report

Summarize:

- Resolved via suggested patch — list finding ids and files.
- Resolved via manual edit — list finding ids, files, and a one-line of what changed.
- Left open for your decision — list finding ids and why.
- Any errors encountered.

Remind the user the changes are uncommitted and ready for review.

## Failure modes

- **CLI not installed** → install message (step 1).
- **Not authenticated** → "`entire trail finding list` requires authentication. Run `entire login` and try again."
- **Trail findings not enabled / API error** → tell the user the feature may be
  unavailable; do not fabricate findings.
- **Trail not found** → tell the user to check the URL or number; suggest
  `entire trail list --status any`.
- **Wrong branch** → stop with the checkout instruction (step 4).
- **Patch does not apply** → fall back to a manual edit; if you cannot fix it
  confidently, leave the finding open and report it.
- **Not a git repository** → stop and tell the user to run from inside the trail's repo.
