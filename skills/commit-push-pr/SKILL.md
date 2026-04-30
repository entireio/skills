---
name: commit-push-pr
description: Commit, push, and open a draft PR using `entire` checkpoint context for the commit message and PR title/body. Use when the user wants to ship a branch with rich, agent-aware PR descriptions — e.g. "open a PR with entire context", "commit and PR this work", "push this branch and write the PR for me", or any commit-and-PR request in a repo where Entire has captured agent sessions.
---

# Commit + Push + PR (Entire-powered)

Commit local work, push, and open a draft PR. Unlike a git-only flow, this skill mines `entire` checkpoint transcripts for the commit message and PR content, so the resulting PR explains *why* the changes were made — not just *what* changed.

For the upstream git-only equivalent, see `commit-commands:commit-push-pr`. Pick this skill when the branch was driven by Entire-tracked agent work; pick the upstream one when there is no Entire history to draw on.

**Best on branches with prior committed agent sessions.** When the only Entire context available is the just-made commit, `entire explain --commit` often returns only the user's prompt as `Intent` and `Outcome: (not generated)` — the skill detects this and degrades cleanly to the git-only fallback for the title and Changes section. The Entire-mined value compounds across multiple committed agent turns; on a single-commit branch, expect git-only output.

## Response Format

The skill's "first successful response" is the **final summary turn** that reports the PR URL, not the per-step progress messages interleaved with tool calls. Begin that final summary with the line:

`Entire Commit:`

followed by a blank line, then the content (PR URL plus a short recap of what was committed and pushed).

- Apply the header to the **final summary turn only.** Do not re-print it on follow-up turns within the same invocation.
- Do **not** include the header on error or early-exit responses (e.g. `gh` not installed, not in a git repo, push refused, no upstream branch). The header signals that the skill ran end-to-end and produced real output.
- Per-step progress messages during execution should be terse and headerless — they communicate intent before tool calls but are not the skill's reportable output.

## Tooling rules

1. Use the installed `entire` from `PATH`, not a `./entire` checked into the repo.
2. `entire search` hits a server-side index that does **not** contain unpushed local checkpoints. Do not use it. Permitted Entire commands:
   - `entire explain --commit <sha> --short --no-pager` — primary per-commit intent. Always look up checkpoints by commit SHA, not by checkpoint ID — the truncated IDs displayed in `entire explain --no-pager` listings are not accepted as input to the same command.
   - `entire explain --commit <sha> --no-pager` — fuller per-commit context if `--short` is too thin.
   - `entire explain --commit <sha> --raw-transcript --no-pager` — raw session transcript for a commit. Used by Step 5 to synthesize a client-side "why" line when entire's `Outcome` is `(not generated)`. Transcripts are stored in a uniform format regardless of which agent (Claude / Codex / Gemini / …) produced the commit, so the invoking agent can read another agent's transcript the same way it reads its own.
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
- After staging, list any **untracked** files left behind (`git status --porcelain | awk '$1=="??"{print $2}'`) in your progress message so the user can react before the push. Do not auto-stage them — they may be workflow artifacts (scratch plans, log files, generated files) that the user explicitly didn't include.
- Build the commit message seed from a `git diff --staged` summary (same approach as upstream `commit-commands:commit-push-pr`). Per-checkpoint context is mined later in Step 5 from each commit's SHA — that path is more reliable than discovering checkpoints by ID at this stage, because the IDs displayed by `entire explain --no-pager` are truncated and not accepted as input to the same command.
- Commit with the standard `Co-Authored-By` trailer. The trailer value should be the agent's published identity, not the literal placeholder. Examples:
  - `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`
  - `Co-Authored-By: Codex <noreply@openai.com>`
  - `Co-Authored-By: Gemini CLI <noreply@google.com>`

  Use a HEREDOC for the message:

```bash
git commit -m "$(cat <<'EOF'
<seed-derived subject>

<optional body>

Co-Authored-By: <agent's published identity> <agent-noreply-address>
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

- `checkpoint-backed` — checkpoint exists **and** has substantive synthesized text. Specifically: `Outcome` is populated (not the literal `(not generated)`) **and** `Intent` is more than 3 words and does not match a slash-command / agent-prompt pattern (`/foo`, `marvin work`, `codex run`, `gemini ask`). The `Outcome` line is the primary "why"; `Intent` is the secondary fallback only when `Outcome` is the same line.
- `checkpoint-prompt-only` — checkpoint exists but `Outcome` is `(not generated)` **or** `Intent` is the bare user prompt (≤3 words / matches the slash-command pattern above). The skill attempts a raw-transcript synthesis (see "Synthesize missing Outcomes" below); if synthesis succeeds, the commit is **promoted to `checkpoint-backed`**. If synthesis fails or the transcript is unavailable, treat exactly like `no-checkpoint` for title and "Why" purposes — use the commit subject verbatim. (This is the common state for commits made *during the same agent turn* as the skill invocation, since `entire explain --generate` has not run yet.)
- `no-checkpoint` — commit was authored outside an Entire session (manual commit, rebase). Detected by the literal output `No associated Entire checkpoint` (or its `--short` equivalent), or by a zero-exit run with no intent line. Use the commit subject verbatim.
- `lookup-failed` — non-zero exit. Log to stderr; treat as `no-checkpoint`.

**Synthesize missing Outcomes from raw transcripts.** For every commit classified `checkpoint-prompt-only` (and only those — don't re-run on commits that already have a substantive `Outcome`), run in parallel:

```bash
entire explain --commit <sha> --raw-transcript --no-pager
```

Trim each transcript before synthesizing — full transcripts can be tens of thousands of lines and will blow agent context. Mirror `session-handoff`'s Phase A approach: filter by `"type":"(message|function_call|user|assistant)"`, take the **first 20 lines** for the original task context plus the **last 100 lines** for final state, and truncate each line to ~2000 chars. From that excerpt, synthesize a single ≤120-char "why" line capturing what the agent was trying to do and what constraint or discovery shaped the resulting code. Transcripts are uniform across agents, so this works whether the commit was made by Claude reading its own transcript or by Codex / Gemini / another agent — the synthesizer is whichever agent is currently invoking the skill.

If the synthesis is substantive (more than 3 words and not just a re-statement of the prompt), **promote** the commit to `checkpoint-backed` for the rest of Step 5 — its synthesized "why" line plays the role of the missing `Outcome`. If the transcript is unavailable, the synthesis collapses to a re-statement of the prompt, or the lookup fails, the commit stays `checkpoint-prompt-only` and falls through to the commit-subject path.

Total raw-transcript reads are also bounded by `MAX_PER_COMMIT_LOOKUPS = 10`. If the push range exceeded the cap, the dispatch fallback already ran in place of per-commit lookups and this synthesis step is skipped.

**Title.** Synthesize a single ≤70-char title from the **full set** of `checkpoint-backed` Outcomes plus the `git diff --stat "$MERGE_BASE"..HEAD` summary — not just one commit's Outcome. A 5-commit branch ending in a small "fix typo" cleanup must not get titled "fix typo"; the title should name the dominant intent of the branch as a whole. Apply these rules in order:

- If one Outcome clearly dominates the branch (one large change plus small follow-ups), seed the title from that Outcome.
- If the Outcomes form a coherent progression (build → polish → test), name the feature, not the latest tweak.
- If the Outcomes are unrelated, name the *area* touched per the diff stat instead of any one commit (e.g. "Refactor auth and storage layers").

If no commit in the range is `checkpoint-backed`, synthesize the title from `git log "$MERGE_BASE"..HEAD --format=%s` plus the diff stat using the same rules. Always trim the final string to ≤70 chars without breaking words.

**If zero commits in the push range are `checkpoint-backed`, switch the entire PR-content path (title and body) to the git-only fallback below.** `checkpoint-prompt-only` and `no-checkpoint` both count as "not checkpoint-backed" for this gate. Don't synthesize Summary/Changes from empty Entire data.

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
- **Single-commit PRs.** Collapse the Summary into a one-sentence preamble and **omit** the Changes section entirely — Summary and Changes both describe the same commit, so listing both is redundant. The Test plan section is unchanged.
- The Test plan is derived from `git diff --stat "$MERGE_BASE"..HEAD` file types. Recipes:
  - Touched `*.ts` / `*.tsx` → "type-check + test the affected component"
  - Touched `*.go` → "go test + go vet"
  - Touched `*.py` → "run the relevant pytest module"
  - Touched `*.rs` → "cargo test + cargo clippy"
  - **Docs/config-only** (only `*.md`, `*.json`, `*.yaml`, `*.yml`, `*.toml`) → "validate JSON/YAML; render the markdown locally; smoke-test in a clean repo if the change is to a skill/plugin/config"
  - Mixed → combine the relevant recipes; one checklist item per language family.
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
- Title: synthesized from `git log "$MERGE_BASE"..HEAD --format=%s` + `git diff --stat` using the rules in Step 5's Title section (dominant change / coherent progression / area touched). Trim to ≤70 chars.
- Body: `## Summary` (1-3 bullets from `git log "$MERGE_BASE"..HEAD --format=%s`), `## Test plan` (derived from `git diff --stat`).
- Steps 1, 2, 4, 6, 7 unchanged.

The fallback emits no error — it just produces a git-only PR.

## Examples of when to trigger

- "commit and PR this work"
- "open a draft PR with entire context"
- "push this branch and write the PR for me"
- "ship this with an entire-powered description"
- "/commit-push-pr" or "/entire:commit-push-pr"
