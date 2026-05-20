---
name: session-handoff
description: Use when the user wants to continue work from one agent in another agent, inspect recent sessions, or summarize a saved session or checkpoint for handoff
---

# Hand-Off Session

## Response Format

Begin the first response to this skill invocation with the line:

`Entire Session Handoff:`

followed by a blank line, then the content. Apply the header to the **first response of the invocation only** — not on follow-up turns and not on error / early-exit responses (no sessions found, transcript missing). Its presence signals the skill ran and produced real output. The "Unanswered Question" branch still gets the header.

## STOP — Read these rules before doing ANYTHING

1. **Do NOT ask clarifying questions.** Auto-detect the session and read the transcript.
2. **Do NOT run** `git log`, `git status`, `git branch`, `ps aux`, or any other exploratory commands. Use only the `entire` CLI commands listed below.
3. **Do NOT say** "Would you like me to continue?" or "Let me know if you want me to pick this up." Just read the transcript and start working. Exception: if the previous agent asked the user a question that was never answered, you MUST ask the user that question before proceeding.

Required CLI: entire 0.6.2+ (`session list --json`, `session info --transcript`, `session current --json|--transcript`, `checkpoint explain --json|--transcript|--raw-transcript --session-index N`). If a flag is rejected, tell the user to upgrade and stop.

## Flow: Active session handoff (default — also covers bare invocation and "current"/"active")

### Step 1: Resolve the canonical worktree path

```bash
entire session current --json
```

If the output is valid JSON, read its `worktree_path` field — that is **the** canonical worktree root for this invocation, set by Entire itself. Use it verbatim in the next step (no `cwd` heuristic needed; symlinks, `/private/var`/`/var` quirks, and subdirectory invocation are all handled).

If the output is not JSON (Entire prints `No active session found in this worktree.` when nothing is active), set the canonical worktree path to `null` and rely on the bidirectional prefix-match fallback in Step 2.

### Step 2: Pick the session

```bash
entire session list --json
```

Each entry has `session_id`, `agent`, `status`, `worktree_path`, `started_at`, `last_active`, `turns`, `last_prompt`, `files_touched`. Apply filters in this order:

1. **Worktree scope.** If you got a canonical worktree path in Step 1, keep entries where `worktree_path` equals it exactly. Otherwise, keep entries where `cwd` starts with `worktree_path` **or** `worktree_path` starts with `cwd`. If either filter yields zero entries, fall back to the unscoped list — better to summarize a slightly-off session than to refuse the handoff.
2. **User-named agent filter** (optional). If the user said "codex", "claude", "kiro", "gemini", etc., keep only entries whose `agent` matches case-insensitively as a substring (so `gemini` matches `Gemini CLI`).
3. **Drop self.** Drop entries where `agent` matches the agent currently running this skill (e.g. `Claude Code`, `Codex`, `Cursor`, `Gemini CLI`, `Copilot CLI`, `Factory AI Droid`, `OpenCode`). **If this empties the list**, undo this filter and keep self — the user is asking you to summarize *your own* current session for compaction. Note that fact in the announcement (Step 5).
4. **Pick most recent.** Sort by `last_active` (fall back to `started_at`) descending; take the first.

If filtering still leaves zero entries (truly nothing in the list, even self), print a one-line error (no header) and stop.

### Step 3: Stream the raw transcript

```bash
entire session info <session_id> --transcript > /tmp/handoff-<session_id>.jsonl
```

Snapshot is bounded to the file size at command start. Output is JSONL for most agents and a single JSON document for Gemini CLI.

### Step 4: Extract conversation content

**JSONL agents** (Claude Code / Codex / Cursor / Copilot CLI / Factory AI Droid / OpenCode):

```bash
grep -E '"type":"(message|function_call|user|assistant)"' /tmp/handoff-<session_id>.jsonl | cut -c1-2000 | head -20    # original task
grep -E '"type":"(message|function_call|user|assistant)"' /tmp/handoff-<session_id>.jsonl | cut -c1-2000 | tail -100   # final state
```

**Gemini CLI** (single JSON document — no JSONL grep):

```bash
jq 'keys' /tmp/handoff-<session_id>.jsonl
```

The top-level shape varies by Gemini CLI version, but messages live under one of `messages`, `contents`, `history`, or `turns`. Each entry has a `role` (`user`/`model`/`function`/`tool`) and a content payload under one of `parts[].text`, `content`, or `text`. Extract role + text in chronological order:

```bash
# Example — adapt the path based on what `jq 'keys'` showed.
jq -r '.messages[] | "\(.role): \([.parts[]? | .text // ""] | join(" "))"' /tmp/handoff-<session_id>.jsonl | head -20
jq -r '.messages[] | "\(.role): \([.parts[]? | .text // ""] | join(" "))"' /tmp/handoff-<session_id>.jsonl | tail -100
```

If neither shape works, fall back to the Read tool on the JSON file and locate the message array by inspection.

Do not show the raw extracted lines to the user. They are inputs for Step 5.

### Step 5: Announce, summarize, present

**Announcement.** First line of the body: `Handing off <agent> session — <turns> turns, last active <relative time>, ID <first-8-of-session-id>.` If the picked session is your own (Step 2 self-filter fallback), prepend a one-clause note: `Self-handoff (no other sessions in this worktree)`. This gives the user a chance to catch a wrong pick before reading the summary.

**Summary structure** (skip any section with no genuine content — do **not** hallucinate filler):

1. **Task Overview** — the user's core request, success criteria, stated constraints.
2. **Current State** — completed work: files created/modified, key decisions, artifacts produced.
3. **Important Discoveries** — technical constraints found, rationale behind decisions, errors hit and how they were resolved, failed approaches and why.
4. **Next Steps** — specific remaining actions, blockers, priority ordering.
5. **Context to Preserve** — user preferences, domain details, commitments made during the session.
6. **Unanswered Question** *(only if applicable)* — if the previous agent's last message asked the user a question or presented options that were never answered, capture it exactly as asked.

A one-bug-fix session might legitimately have only Task Overview + Current State + Next Steps. A pure-research session might have only Task Overview + Important Discoveries. Empty sections are a feature; pad them only if you have real content.

**Continue.** Show announcement + summary.

- If section 6 exists, ask the user that question and wait. Do NOT pick a default.
- Otherwise, **immediately pick up the work** — plan, code, or whatever the next step is. Do not ask permission.

## Flow: Checkpoint handoff (user gives a checkpoint ID)

### Step 1: Enumerate sessions

```bash
entire checkpoint explain <checkpoint-id> --json
```

The envelope's `sessions` array lists every session that contributed. Multi-session checkpoints are common (parallel agents, retries, multi-phase work) and earlier sessions often carry the rationale, failed approaches, and user constraints that the latest session takes for granted.

### Step 2: Pick which sessions to stream

- **1 session.** Stream the normalized compact transcript:

  ```bash
  entire checkpoint explain <checkpoint-id> --transcript > /tmp/handoff-ckpt-<checkpoint-id>.jsonl
  ```

- **2–8 sessions.** Iterate every index 0..N-1. Do **not** rely on the `--transcript` default (latest session only):

  ```bash
  # for N in 0 .. sessions.length-1
  entire checkpoint explain <checkpoint-id> --raw-transcript --session-index <N> > /tmp/handoff-ckpt-<checkpoint-id>-<N>.jsonl
  ```

- **More than 8 sessions.** Sort the `sessions` array by timestamp (`started_at` or whichever field the envelope provides) descending and take the 8 most recent. Note the cap in the announcement: `<M of N> sessions summarized; oldest <M-N> elided as too old to matter.` This keeps the skill bounded while still covering the recent rationale layer.

`--raw-transcript` keeps the per-agent raw bytes so the same JSONL grep extraction works. Index 0 is the first session chronologically.

### Step 3: Extract, announce, summarize, continue

Run the Step 4 extraction (head + tail per file) on each `/tmp/handoff-ckpt-*.jsonl`, then merge into a single five-section summary. Treat earlier sessions as the source of "Important Discoveries" and "Context to Preserve"; the latest session feeds "Current State" and "Next Steps". Empty-section rule from the active-session flow applies. Then announce + present per Step 5 of the active-session flow, with the announcement adapted to checkpoint context (`Handing off checkpoint <short-id> — <M> sessions, <total turns> turns total.`).
