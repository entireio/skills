---
name: using-entire
description: >
  Use for any codebase exploration or understanding task — reads historical
  intent from Entire checkpoints instead of guessing. Orchestrates other Entire
  skills to give the agent provenance-backed answers about code.
---

# Using Entire

Your default when exploring or understanding code should be: **read the
recorded intent, don't guess.**

Entire checkpoints capture the prompts, transcripts, and decisions behind every
agent-driven change. When you need to understand why code exists or how a module
evolved, look up the checkpoint history first. Only fall back to inference from
code structure when no history is available — and label that explicitly.

## When This Skill Activates

Use this skill whenever the task involves:

- Exploring or understanding an unfamiliar module or file
- Preparing to refactor, extend, or debug code you didn't write
- Answering "why is this like this?" or "what was the intent?"
- Doing pre-work research before making changes
- Any codebase exploration where historical context would help

Do **not** use this skill for simple, well-understood edits where you already
have full context (e.g. "add a comment to line 5").

## First Step: Check Repository Status

Before diving into specific lookups, check whether Entire is available and
the repository has checkpoint history:

```bash
entire status
```

This tells you whether Entire is enabled, which git hooks are installed, whether
the metadata branch is initialized, and any active sessions on the current
branch.

## Scenario Routing

When this skill activates, determine which sub-skill best fits the user's need:

| Scenario | Typical user expressions | Delegate to |
|----------|------------------------|-------------|
| Code block provenance | "why is this like this" / "wtf is going on" / "what happened at src/auth.ts:42" / "tell me why this changed" / "这块代码为什么这么写" | `what-happened` |
| Find prior work | "has anyone done X before" / "search past work for rate limiting" / "find the previous implementation" / "之前有人做过 X 吗" | `search` |
| Understand original intent | "explain this function" / "explain parseConfig" / "what was the intent behind src/auth.ts" / "解释一下这个文件" | `explain` |
| Generate a dispatch / summary | "summarize recent work" / "generate a dispatch" / "what was accomplished this week" / "写个周报" / "最近都做了什么" | `dispatch` |
| Code review with intent context | "review these changes" / "review this branch" / "audit before merging" / "帮我 review 一下" / "检查一下这个分支的代码" | `review` |
| Hand off to another agent | "hand off this session" / "continue in another agent" / "pick up the codex session" / "接手之前的工作" | `session-handoff` |
| Convert session to skill | "turn this into a skill" / "make a skill from this session" / "把这个流程封装成 skill" | `session-to-skill` |
| Link session to other repos | "link session to other repos" / "attach session to the foo repo" / "这个 session 关联到另一个仓库" | `session-crosslink` |
| General exploration | "understand this module" / "explore how auth works" / "help me understand the codebase" / "了解一下这个模块" | _(self — see below)_ |

If the scenario clearly maps to a sub-skill, delegate entirely to that skill's
workflow. Do not duplicate their steps here.

## General Exploration Flow

When no specific sub-skill fits — e.g. the user asks to "understand this
module" or "explore how auth works" — use this flow:

1. **Identify key files** in the target area (entry points, main types, core
   functions).

2. **Check for checkpoint coverage** on each key file:

```bash
git log --format='%H %s' -5 -- <file>
```

Look for `Entire-Checkpoint:` trailers in the commit bodies:

```bash
git log --format='%H %b' -5 -- <file> | grep -B1 'Entire-Checkpoint:'
```

3. **Read intent for covered commits** — extract the checkpoint ID from the
   trailer, then use JSON output for non-interactive consumption:

```bash
entire explain --checkpoint <checkpoint-id> --json --no-pager
```

If you only have a commit hash (not a checkpoint ID), use:

```bash
entire explain --commit <sha> --no-pager
```

4. **Synthesize**: combine the recorded intent (from checkpoints) with the
   current code structure to build a comprehensive understanding.

5. **Report** your findings, clearly distinguishing:
   - Facts backed by checkpoint transcripts (label as "recorded intent")
   - Observations inferred from code alone (label as "inferred from code")

## AI Agent Usage Notes

When running Entire commands from an agent subprocess:

- **Always pass `--json`** for commands that support it and might prompt
  interactively. `--json` implies non-interactive output.
- **Always pass `--no-pager`** to prevent pager activation in subprocess
  contexts.
- **Always specify `--checkpoint <id>` or `--commit <sha>`** for
  `entire explain` — without a locator, the command falls back to an
  interactive picker.

## When No Checkpoints Exist

If the target code predates Entire or has no checkpoint coverage:

1. Say explicitly: "No Entire checkpoint history is available for this code."
2. Proceed with standard code understanding (read source, check git log, trace
   call sites).
3. Label all explanations as "inferred from code — not backed by recorded
   intent."
4. If the user wants deeper history, suggest `search` with related keywords —
   there may be checkpoints on related work even if the specific file isn't
   directly covered.

## Transparency Principle

Always make it clear whether your answer comes from:

- **Checkpoint-backed history** — you read the actual session transcript and
  know the developer's stated intent
- **Code inference** — you analyzed the code structure and are reasoning about
  probable intent

Never present inferred intent as if it were recorded fact. The core value of
this workflow is that distinction.
