---
description: Use when the user wants to continue work from one agent in another agent, inspect recent sessions, or summarize a saved session or checkpoint for handoff
---

# Hand-Off Session

## Response Format

Begin the first response to this skill invocation with the line:

`Entire Session Handoff:`

followed by a blank line, then the content. The header applies to the full compaction-summary flow, including the "Unanswered Question" branch (which is still a successful run — the skill summarized the transcript and surfaced the question).

- Apply the header to the **first response of the invocation only.** Do not re-print it on follow-up turns within the same invocation (e.g. after the user answers the surfaced unanswered question).
- Do **not** include the header on error or early-exit responses (e.g. no `.git/entire-sessions/` directory, no sessions found after filtering, transcript file missing at the path the session JSON points to). The header's presence should signal that the skill ran and produced real output.

## STOP — Read these rules before doing ANYTHING

1. **Do NOT ask clarifying questions.** Auto-detect the session and read the transcript.
2. **Do NOT run** `entire sessions list`, `entire sessions info`, `entire explain --session`, `git log`, `git status`, `git branch`, `ps aux`, or any other exploratory commands. They waste time and don't give you the transcript.
3. **Do NOT say** "Would you like me to continue?" or "Let me know if you want me to pick this up." Just read the transcript and start working. (Exception: if the previous agent asked the user a question that was never answered, you MUST ask the user that question before proceeding.)
4. **Do NOT summarize the session as having "0 turns" or "no progress"** without first reading the actual transcript file. The `entire` CLI metadata often undercounts — the transcript is the source of truth.
5. **Skip your own session.** Your agent (e.g. Claude Code) also has a session in `.git/entire-sessions/`. Exclude any session whose `agent_type` matches your own agent type from the results.

## Flow: Active / current session handoff

When the user says "current", "active", or just "hand off this session":

### Step 1: Run `entire status`

```
entire status
```

This returns the active session ID. If the user mentioned an agent name (e.g. "codex"), look for that agent's session in the output.

### Step 2: Find the transcript path

Read the session file at `.git/entire-sessions/<session-id>.json` using the Read tool:

```
Read: .git/entire-sessions/<session-id>.json
```

The file looks like this:
```json
{
  "session_id": "019d730f-e099-7910-a946-b5b20e2cfafc",
  "agent_type": "Codex",
  "phase": "active",
  "started_at": "2026-04-09T09:25:21.725231-07:00",
  "last_interaction_time": "2026-04-09T09:25:21.725657-07:00",
  "transcript_path": "/Users/alisha/.codex/sessions/2026/04/09/rollout-....jsonl",
  "last_prompt": "create solitaire game"
}
```

Extract the `transcript_path` field. This is the path to the full conversation transcript.

**Fallback:** If `entire status` doesn't give you a session ID, or the session JSON doesn't exist, use the Glob tool to find all `.git/entire-sessions/*.json` files, read them, and pick the most recent one (by `last_interaction_time` or `started_at`). Filter by agent name if the user specified one. Always exclude sessions matching your own agent type.

### Step 3: Extract and summarize the transcript

**Phase A — Extract raw transcript** (do NOT show this to the user):

```bash
grep -E '"type":"(message|function_call|user|assistant)"' <transcript_path> | cut -c1-2000
```

If the output exceeds ~500 lines, read the **last 100 lines** (final state) and **first 20 lines** (original task):

```bash
grep -E '"type":"(message|function_call|user|assistant)"' <transcript_path> | tail -100 | cut -c1-2000
grep -E '"type":"(message|function_call|user|assistant)"' <transcript_path> | head -20 | cut -c1-2000
```

**Phase B — Produce a compaction summary.** Internally process the extracted transcript and produce a structured summary with these sections:

1. **Task Overview** — The user's core request, success criteria, and any stated constraints or clarifications.
2. **Current State** — Completed work: files created/modified, key decisions made, artifacts produced.
3. **Important Discoveries** — Technical constraints uncovered, rationale behind decisions, errors hit and their resolutions, failed approaches and why they failed.
4. **Next Steps** — Specific remaining actions, blockers, and priority ordering.
5. **Context to Preserve** — User preferences, domain-specific details, and commitments made during the session.
6. **Unanswered Question** (only if applicable) — If the previous agent's last message asked the user a question or presented options that were never answered, capture it here exactly as asked.

Be concise but complete — err on the side of including information that would prevent duplicate work or repeated mistakes.

### Step 4: Present summary, then continue

Show the compaction summary from Phase B to the user.

**Critical rule — unanswered questions go to the user, not you.** If section 6 (Unanswered Question) exists, present that question to the user and wait for their answer. Do NOT answer it yourself or pick a default. The user is the decision-maker.

If there is no unanswered question, **immediately pick up the work** — start planning, coding, or doing whatever the next step is. Do not ask permission.

## Flow: Checkpoint handoff (user gives a checkpoint ID)

1. Run `entire explain --checkpoint <checkpoint-id> --full --no-pager`
2. If `--full` fails, fall back to `entire explain --checkpoint <checkpoint-id> --raw-transcript --no-pager`
3. Extract conversation content from ALL session transcripts (do NOT show raw output to the user):

```bash
grep -rE '"type":"(message|function_call|user|assistant)"' <transcript_dir_or_files> | cut -c1-2000
```

For large checkpoints with many sessions, focus on the last 100 lines per transcript to understand final state, and the first 20 lines for the original task.

4. Produce and present a compaction summary using the same 5-section format from Step 3 Phase B above, then continue.

Resolve checkpoint repos in order: explicit override → local `entire/checkpoints/v1` branch → `.entire/settings.json` `checkpoint_remote` → nearby local clone.

## Flow: No specific request (bare invocation)

Use the Glob tool to find `.git/entire-sessions/*.json`. Read each file, exclude your own agent type, pick the most recent by `last_interaction_time`. Read the transcript at `transcript_path`. Summarize and continue.

## Agent name filtering

Words like "codex", "claude", "kiro", "gemini" in the user's request are **filters** for session selection. Match them case-insensitively against the `agent_type` field (fall back to `agent` field). Never invoke another agent's CLI.
