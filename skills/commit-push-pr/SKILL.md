---
name: commit-push-pr
description: Commit, push, and open a draft PR using `entire` checkpoint context for the commit message and PR title/body. Use when the user wants to ship a branch with rich, agent-aware PR descriptions — e.g. "open a PR with entire context", "commit and PR this work", "push this branch and write the PR for me", or any commit-and-PR request in a repo where Entire has captured agent sessions.
---

# Commit + Push + PR (Entire-powered)

Commit local work, push, and open a draft PR. Unlike a git-only flow, this skill mines `entire` checkpoint transcripts for the commit message and PR content, so the resulting PR explains *why* the changes were made — not just *what* changed.

For the upstream git-only equivalent, see `commit-commands:commit-push-pr`. Pick this skill when the branch was driven by Entire-tracked agent work; pick the upstream one when there is no Entire history to draw on.

## Response Format

Begin the first successful response to this skill invocation with the line:

`Entire Commit:`

followed by a blank line, then the content.

- Apply the header to the **first response of the invocation only.** Do not re-print it on follow-up turns within the same invocation.
- Do **not** include the header on error or early-exit responses (e.g. `gh` not installed, not in a git repo, push refused, no upstream branch). The header signals that the skill ran end-to-end and produced real output.

## Tooling rules

1. Use the installed `entire` from `PATH`, not a `./entire` checked into the repo.
2. `entire search` hits a server-side index that does **not** contain unpushed local checkpoints. Do not use it. Permitted Entire commands:
   - `entire explain --commit <sha> --short --no-pager` — primary per-commit intent.
   - `entire explain --commit <sha> --no-pager` — fuller per-commit context if `--short` is too thin.
   - `entire explain <checkpoint-id> --short --no-pager` — most recent current-branch checkpoint when synthesizing a commit message for newly staged work.
   - `entire dispatch --local --since <window>` — prose summary; fallback only when the push range exceeds `MAX_PER_COMMIT_LOOKUPS` (= 10) commits.
3. Always pass `--no-pager` to `entire explain` calls so output stays non-interactive. Do not invent `--no-pager` on commands that do not support it (`entire dispatch` does not).
4. Stage with explicit paths. Never use `git add -A` or `git add .` (per the user's git-safety rules).
5. Always create the PR as `--draft`.

## Process

Run independent steps' independent commands in parallel where the host agent supports it.

### 1. Preflight

- `entire version` and `gh --version`. If `entire` is missing, fall through to the git-only fallback (see below). If `gh` is missing, stop with a clear error (no header).
- `git rev-parse --is-inside-work-tree`. If not in a repo, stop (no header).
- Resolve the base branch:
  1. `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` if authenticated.
  2. Else `git symbolic-ref --short refs/remotes/origin/HEAD` (strip `origin/`).
  3. Else `main`.
- Compute `MERGE_BASE = git merge-base origin/<base> HEAD`. If `origin/<base>` is missing, run `git fetch origin <base>` once and retry. If still missing, stop and ask the user.
- Do **not** finalize the push range yet if the working tree is dirty — the commit created in Step 3 must be included.

### 2. Branch from base if needed

If the current branch IS the base branch, create a new branch first:

- Build a seed using the same heuristics as Step 3's commit message seed.
- Sanitize to `kebab-case` and prefix with `agent/`.
- If the seed is empty or vague, fall back to `agent/<YYYYMMDD-HHMMSS>`.

Do not prompt the user for a branch name in v1.

### 3. Stage + commit any uncommitted work

- `git status --porcelain`. Skip this step if clean.
- Stage with explicit paths.
- Build the commit message seed:
  - Inspect the newest checkpoint on the current branch via `entire explain --no-pager`. If a relevant checkpoint exists, run `entire explain <checkpoint-id> --short --no-pager` and use its intent line as the seed.
  - If there is no relevant checkpoint, or the intent clearly does not match `git diff --staged`, fall back to a `git diff --staged` summary (the upstream skill's path).
- Commit with the standard `Co-Authored-By` trailer. Use a HEREDOC for the message:

```bash
git commit -m "$(cat <<'EOF'
<seed-derived subject>

<optional body>

Co-Authored-By: <agent name> <noreply@anthropic.com>
EOF
)"
```

- After committing, recompute the push range so the new commit is included:

```bash
git log --reverse --format=%H "$MERGE_BASE"..HEAD
```

### 4. Push

- `git push -u origin HEAD`.

### 5. Build the PR content

For each commit SHA in the push range, run **in parallel**:

```bash
entire explain --commit <sha> --short --no-pager
```

Cap at `MAX_PER_COMMIT_LOOKUPS = 10`. If the push range exceeds the cap, skip the per-commit loop and instead run a single `entire dispatch --local --since <window>` where `<window>` is the timestamp of the oldest commit in the push range minus a 1-hour buffer (`git log --reverse --format=%aI "$MERGE_BASE"..HEAD | head -1`).

Deduplicate per-checkpoint output where multiple commits share a checkpoint. Classify each commit:

- `checkpoint-backed` — has an intent/summary line.
- `no-checkpoint` — commit was authored outside an Entire session (manual commit, rebase). Detected by the literal output `No associated Entire checkpoint` (or its `--short` equivalent), or by a zero-exit run with no intent line. Use the commit subject verbatim for this commit.
- `lookup-failed` — non-zero exit. Log to stderr; treat as `no-checkpoint`.

**Title.** Derive from the **most recent** `checkpoint-backed` commit's intent, trimmed to ≤70 chars. If no commit is checkpoint-backed, fall back to the git-only title (most recent commit subject).

**If zero commits in the push range are `checkpoint-backed`, switch the entire PR-content path (title and body) to the git-only fallback below.** Don't synthesize Summary/Changes from empty Entire data.

**Body.** Use this exact template:

```markdown
## Summary

<2-4 sentences synthesized from the per-commit intents>

## Changes

- <commit-subject> — <one-line "why" from entire explain --short>
- <commit-subject> — <one-line "why" from entire explain --short>

## Test plan

- [ ] <derived from `git diff --stat "$MERGE_BASE"..HEAD`>
```

Notes:

- The Summary paragraph is **synthesized**, not a literal concatenation of per-commit output.
- "Changes" lists every commit in chronological order. Mixed-author branches naturally show some commits with rich Entire-derived "why" and some with bare subjects — that's informative, not a bug.
- The Test plan is derived from `git diff --stat "$MERGE_BASE"..HEAD` file types. Examples: touched `*.ts` → "type-check + test the affected component"; touched `*.go` → "go test + go vet".
- This repo has no checked-in PR template, so the skill defines the body shape itself.

### 6. Open or update the PR

Run `gh pr view --json number,isDraft,state` for the current branch.

- If a PR exists with `state == "OPEN"`: update title and body with `gh pr edit`. **Do not** toggle draft state if the PR is already non-draft.
- If a PR exists but is `CLOSED` or `MERGED`: ignore it; create a fresh draft PR.
- If `gh pr view` exits non-zero (no PR found): create a fresh draft PR.

Always `--draft` on create:

```bash
gh pr create --draft --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

### 7. Print the PR URL

Echo the PR URL as the final line of output.

## Fallback: no Entire data

If `entire` is not installed, not configured for the repo, or the push range produced **zero** `checkpoint-backed` commits, fall back silently to a git-only flow equivalent to `commit-commands:commit-push-pr`:

- Commit message seed from `git diff --staged` (Step 3) or last commit subject.
- Title: most recent commit subject, trimmed to ≤70 chars.
- Body: `## Summary` (1-3 bullets from `git log "$MERGE_BASE"..HEAD --format=%s`), `## Test plan` (derived from `git diff --stat`).
- Steps 1, 2, 4, 6, 7 unchanged.

The fallback emits no error — it just produces a git-only PR.

## Examples of when to trigger

- "commit and PR this work"
- "open a draft PR with entire context"
- "push this branch and write the PR for me"
- "ship this with an entire-powered description"
- "/commit-push-pr" or "/entire:commit-push-pr"
