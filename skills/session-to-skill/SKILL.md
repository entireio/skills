---
name: session-to-skill
description: Use when the user wants to turn one or more Entire-tracked sessions, checkpoints, or repeated agent workflows into a reusable agent skill.
---

# Session To Skill

Use this skill to help the user turn Entire session history into a focused skill draft.

The goal is not to convert a whole transcript mechanically. Treat sessions and checkpoints as source material, then extract the reusable workflow the user wants to repeat.

## Response Format

Begin the first response to this skill invocation with the line:

`Entire Session To Skill:`

followed by a blank line, then the content.

- Apply the header to the **first response of the invocation only.** Do not re-print it on follow-up turns within the same invocation.
- Do **not** include the header on error or early-exit responses, such as when Entire is not installed, the current directory is not a git repository, no relevant sessions are found, or the user has not identified what reusable behavior they want.

## Rules

1. First identify the reusable behavior the skill should capture. If the user has not said what the skill should help with, ask that question before reading transcripts.
2. Use Entire history as evidence. Prefer `entire search`, `entire session current`, session metadata files, and `entire explain` over asking the user to paste old transcripts.
3. A skill draft should be focused on future behavior, not a recap of the session. Preserve durable workflow, repo conventions, user corrections, commands, validation, and things to avoid.
4. When several sessions may be relevant, summarize the repeated workflow pattern, recommend a source set, and ask the user to confirm before expanding transcripts.
5. Do not write, install, or overwrite a skill file unless the user explicitly approves the destination. By default, present the `SKILL.md` draft in the response.
6. Do not include secrets, private credentials, raw logs, or unnecessary transcript detail in the generated skill.

## Workflow

### 1. Clarify The Skill Target

If the user gives a clear target, continue. Examples:

- "turn my blog publishing workflow into a skill"
- "make a skill from session 019..."
- "I keep doing release note drafting; make that reusable"

If the target is vague, ask:

```text
What should this skill help you do repeatedly?
```

If the user wants a specific skill name, use it. Otherwise infer a short hyphen-case name from the target, then confirm it before writing files.

### 2. Infer The Repeated Pattern

If the user gives a checkpoint ID, skip to checkpoint expansion.

If the user gives a session ID, read the matching session metadata from:

```text
.git/entire-sessions/<session-id>.json
```

If the user describes a repeated workflow but does not give a session or checkpoint, search Entire history with terms from the target:

```bash
entire search "<workflow terms>" --json
```

Use repo, branch, author, or date filters when the user provides them:

```bash
entire search "<workflow terms>" --json --repo owner/name --branch branch-name --author "Name" --date month
```

Interpret search results carefully:

- If `entire search` returns valid JSON with `"total": 0` or an empty `results` array, do **not** call it an authentication failure. Say no indexed matches were found, then fall back to local session metadata.
- Only say authentication is required if the command output explicitly says authentication, login, or credentials are required.
- If search fails for any other reason, report the short error and fall back to local session metadata when available.

When falling back locally, inspect `.git/entire-sessions/*.json` and match against `last_prompt`, `description`, `files_touched`, `started_at`, `last_interaction_time`, `agent_type`, and the user's workflow terms.

Review the top results and infer the repeated workflow pattern before showing raw session choices. Lead with the pattern, not the IDs.

Present:

- the repeated workflow you think the user wants to capture
- the strongest source set you recommend using
- what each source contributes in plain language, such as "core workflow", "image handling", "validation", or "copy-editing pattern"
- any sessions you plan to ignore because they look metadata-only, duplicate, or one-off

Keep session IDs and checkpoint IDs as supporting details, not the main decision surface. Ask the user to confirm the pattern and source set before expanding detailed transcripts.

Example:

```text
I found a repeated workflow: publishing blog posts in entire.io from drafts, using repo-specific front matter, slugged asset folders, user-provided images, and website checks.

I recommend using the strongest matching sessions as source material:
- core workflow: <session-id>
- image handling: <session-id>
- validation mechanics: <session-id>

I will ignore metadata-only or one-off edit sessions unless you want them included. Should I continue with this source set?
```

### 3. Read Source Material

For a checkpoint, run:

```bash
entire explain --checkpoint <checkpoint-id> --full --no-pager
```

If full output fails and the user wants more detail, fall back to:

```bash
entire explain --checkpoint <checkpoint-id> --raw-transcript --no-pager
```

For an active or current session, prefer:

```bash
entire session current
```

If the installed Entire CLI does not support the singular `session` group yet, use the session metadata fallback directly: inspect `.git/entire-sessions/*.json`, pick the relevant session by `last_interaction_time`, `started_at`, `agent_type`, or the user's requested agent, then extract `transcript_path`.

When reading a raw transcript, extract relevant conversation and tool-call lines without dumping them to the user:

```bash
grep -E '"type":"(message|function_call|user|assistant)"' <transcript_path> | cut -c1-2000
```

For large transcripts, inspect the first prompts and final state first:

```bash
grep -E '"type":"(message|function_call|user|assistant)"' <transcript_path> | head -40 | cut -c1-2000
grep -E '"type":"(message|function_call|user|assistant)"' <transcript_path> | tail -160 | cut -c1-2000
```

If the session metadata lists files touched, inspect only files needed to understand durable conventions. Avoid broad repo exploration unless the skill target requires it.

### 4. Extract Durable Lessons

Before drafting, privately identify:

- the repeated goal the future skill should accomplish
- triggers that should activate the skill
- required inputs the future agent should ask for
- repo-specific paths, file formats, front matter, naming, or asset placement
- commands and checks that proved the workflow worked
- user corrections and preferences from the session
- failed approaches or behaviors to avoid
- what was one-off and should not go into the skill

If multiple sessions were selected, combine only the repeated or clearly reusable lessons. Do not average contradictory instructions; ask the user to choose when sessions disagree.

### 5. Draft The Skill

Create a complete `SKILL.md` draft with required front matter:

```markdown
---
name: <hyphen-case-skill-name>
description: Use when <specific trigger and task>.
---
```

The body should include:

- a short purpose statement
- clear rules or guardrails
- a step-by-step workflow
- exact commands only when they are part of the reusable behavior
- expected outputs and validation steps
- failure handling or when to ask the user

Keep the skill concise. Do not include the session recap, full transcript excerpts, checkpoint IDs, or implementation notes unless they are essential to future use.

### 6. Deliver And Offer Installation

Present the `SKILL.md` draft first unless the user already gave an explicit write path.

After presenting the draft, ask whether the user wants it installed globally. Recommend the cross-agent path:

```text
~/.agents/skills/<skill-name>/SKILL.md
```

Use this install prompt shape:

```text
Do you want me to install this skill globally?

Recommended:
- Cross-agent: ~/.agents/skills/<skill-name>/SKILL.md

Other options:
- Codex only: ~/.codex/skills/<skill-name>/SKILL.md
- Write to a repo-local draft: skills/<skill-name>/SKILL.md
- Leave as draft only
```

Only write files after the user chooses a destination. If the destination already exists, ask before overwriting it.

Do not create symlinks unless the user explicitly asks for a development-linked install. If they ask for a symlink, explain the source and target paths before creating it.

After writing a skill file, summarize:

- where it was written
- which session(s) or checkpoint(s) informed it
- any assumptions or open questions
