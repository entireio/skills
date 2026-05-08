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

### Step 1: Pick the session

Run:

```bash
entire session list --json
```

Each entry has `session_id`, `agent`, `status`, `worktree_path`, `started_at`, `last_active`, `turns`, `last_prompt`, `files_touched`. From that array:

1. Scope to this worktree. `worktree_path` is the worktree root; your `cwd` may be a subdirectory of it. Keep an entry if `cwd` starts with `worktree_path` **or** `worktree_path` starts with `cwd` (treats both as paths). If that filter yields zero entries, fall back to the unscoped list rather than failing — better to summarize a slightly-off session than to refuse the handoff.
2. Drop entries where `agent` matches the agent currently running this skill (e.g. `Claude Code`, `Codex`, `Cursor`, `Gemini CLI`, `Copilot CLI`, `Factory AI Droid`, `OpenCode`).
3. If the user named an agent ("codex", "claude", "kiro", "gemini", …), keep only entries whose `agent` matches case-insensitively as a substring (so `gemini` matches `Gemini CLI`).
4. Sort by `last_active` (fall back to `started_at`) descending; take the first.

If even the unscoped list is empty after self/agent-name filtering, print a one-line error (no header) and stop.

### Step 2: Stream the raw transcript

```bash
entire session info <session_id> --transcript > /tmp/handoff-<session_id>.jsonl
```

Snapshot is bounded to the file size at command start. Output is JSONL for most agents and a single JSON document for Gemini CLI.

### Step 3: Extract conversation content

For Gemini CLI (whole-document JSON), read `/tmp/handoff-<session_id>.jsonl` with the Read tool and locate the messages / contents array. For everyone else:

```bash
grep -E '"type":"(message|function_call|user|assistant)"' /tmp/handoff-<session_id>.jsonl | cut -c1-2000 | head -20    # original task
grep -E '"type":"(message|function_call|user|assistant)"' /tmp/handoff-<session_id>.jsonl | cut -c1-2000 | tail -100   # final state
```

Do not show the raw lines to the user. They are inputs for Step 4.

### Step 4: Produce a compaction summary

Write a structured summary with these sections:

1. **Task Overview** — the user's core request, success criteria, stated constraints.
2. **Current State** — completed work: files created/modified, key decisions, artifacts produced.
3. **Important Discoveries** — technical constraints found, rationale behind decisions, errors hit and how they were resolved, failed approaches and why.
4. **Next Steps** — specific remaining actions, blockers, priority ordering.
5. **Context to Preserve** — user preferences, domain details, commitments made during the session.
6. **Unanswered Question** *(only if applicable)* — if the previous agent's last message asked the user a question or presented options that were never answered, capture it exactly as asked.

Be concise but complete — err on the side of including info that prevents duplicate work or repeated mistakes.

### Step 5: Present and continue

Show the compaction summary.

**Critical rule — unanswered questions go to the user, not you.** If section 6 exists, ask the user that question and wait for their answer. Do NOT pick a default.

Otherwise, **immediately pick up the work** — start planning, coding, or whatever the next step is. Do not ask permission.

## Flow: Checkpoint handoff (user gives a checkpoint ID)

### Step 1: Enumerate sessions

```bash
entire checkpoint explain <checkpoint-id> --json
```

The envelope's `sessions` array tells you how many sessions contributed to this checkpoint. Multi-session checkpoints are common (parallel agents, retries, multi-phase work) and earlier sessions often carry the rationale, failed approaches, and user constraints that the latest session takes for granted. **Do not skip them.**

### Step 2: Stream every session's transcript

If the checkpoint has exactly one session, stream the normalized compact transcript:

```bash
entire checkpoint explain <checkpoint-id> --transcript > /tmp/handoff-ckpt-<checkpoint-id>.jsonl
```

If it has more than one (`sessions.length > 1`), iterate over every index — do **not** rely on the `--transcript` default (latest session only):

```bash
# for N in 0 .. sessions.length-1
entire checkpoint explain <checkpoint-id> --raw-transcript --session-index <N> > /tmp/handoff-ckpt-<checkpoint-id>-<N>.jsonl
```

`--raw-transcript` keeps the per-agent raw bytes so the same JSONL grep extraction works. Index 0 is the first session.

### Step 3: Extract, summarize, continue

Run the Step 3 grep extraction (head + tail) from the active-session flow on each `/tmp/handoff-ckpt-*.jsonl` file, then merge the results into a single five-section summary. Treat earlier sessions as the source of "Important Discoveries" and "Context to Preserve"; the latest session is the source of "Current State" and "Next Steps". Then continue per Step 5 of the active-session flow.
