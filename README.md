![skills cover](assets/gh-repo-cover.png)

# skills

Bring your Entire context to your agents with cross-agent skills.

## Why This Exists

The [Entire CLI](https://github.com/entireio/cli) captures the context behind your
code changes: prompts, transcripts,
[Checkpoints](https://docs.entire.com/guides/sessions/overview), and the decisions that led
to each change, alongside your git history. This repository packages
agent-invokable workflows that teach coding agents how to use that context across
development environments.

Instead of looking up Entire commands yourself, you can ask in plain language and
let your agent search prior work, inspect provenance, hand off session state, or
turn repeated workflows into new skills.

## Install

Install every skill with the [skills](https://skills.sh/) CLI:

```bash
npx skills add https://github.com/entireio/skills --all
```

Install one skill:

```bash
npx skills add https://github.com/entireio/skills --skill search
```

See [Agent-Specific Installation](#agent-specific-installation) for setup
instructions by agent.

## Quick Start

> [!NOTE]
> These skills are most useful in codebases with real
> [Checkpoints](https://docs.entire.com/guides/sessions/overview) and session history. The
> richer the history, the more context your agent has to work with; in a new or
> lightly captured repository, some workflows may have less to find or explain.

After installing, ask your agent for the workflow you want:

```text
search past work for rate limiting
```

```text
explain src/auth.ts
```

```text
what happened here: src/auth.ts:42-57
```

```text
hand off this session
```

```text
turn my release notes workflow into a skill
```

```text
review this branch before merging
```

For a guided walkthrough, see the
[skills tutorial](https://docs.entire.com/learn/skills).

## What skills help agents do

| Goal | Example prompt |
| --- | --- |
| Research or investigate a topic from recorded history | `research how checkpoint pushing works` / `investigate the flaky login redirect` |
| Find prior work before making changes | `search past work for the migration` |
| Understand the intent behind a function, file, or line | `explain parseConfig` |
| Investigate the latest change to a specific block | `what happened at src/auth.ts:42` |
| Review branch changes with intent context | `review this branch before merging` |
| Pick up another agent's work | `hand off the codex session` |
| Convert repeated work into a reusable workflow | `make a skill from this session` |
| Build a task playbook from similar prior work | `have we done this before` |
| Walk through a feature's history step by step | `replay the auth feature` |
| Learn a repository topic from checkpoint history | `teach me how auth works in this repo` |
| Address open review findings on an Entire trail | `address the findings on trail 42` |
| Link a session to the repos it edited | `attach this session to the api repo` |

## Make search the default research step

Agents pick skills by matching the request against each skill's description, and
generic verbs like "research", "investigate", or "look into" compete with their
built-in grep and file-reading tools. The `search` and `using-entire` skill
descriptions claim those verbs explicitly and ask for the skill as the first
action, before any file orientation, so a plain "investigate X" routes to
`entire search` first. This is measured to be sufficient on its own (see
`evals/README.md`).

User instructions outrank skill descriptions in every agent, so if you want a
guarantee, add a line to your `CLAUDE.md` or `AGENTS.md`:

```markdown
When asked to research, investigate, look into, or dig into anything in this
codebase, run `entire search "<topic>" --json --compact --limit 5` first and
summarize the prior work before reading source files or grepping.
```

The `evals/` directory holds `claude plugin eval` cases that check this routing;
see `evals/README.md`.

## Included skills

The current repository includes these skills. Each skill lives in
`skills/<skill-name>/SKILL.md`.

### `search`

Finds prior work in your Entire history by topic, repo, branch, author, or time
window, so your agent can bring past context into the current task before making
changes.

https://github.com/user-attachments/assets/52e50eae-ba53-4f31-ad2e-2a29a767a34f

### `explain`

Looks up the session behind a function, file, or line so your agent can explain
the requirement, decision, or original problem that shaped it.

https://github.com/user-attachments/assets/ab2e88f6-9bce-417b-ba71-6e93ecad370b

### `what-happened`

Starts from an exact file line, range, or pasted snippet and traces the latest
change with `git blame` and Checkpoint context. Useful when reviewing a concrete
block, debugging a regression, or asking why that block changed.

https://github.com/user-attachments/assets/47db0daa-60bd-4000-b956-2d0e4d980b9b

### `session-handoff`

Reads saved or active session context so another agent can pick up the task
state, important discoveries, blockers, and next steps without making you
reconstruct everything manually.

https://github.com/user-attachments/assets/0df3b5cd-fe37-4145-af48-138642ccc8bc

### `review`

Reviews code changes on the current branch by reading checkpoint transcripts to
understand developer intent, then auditing the diff for issues. Produces
intent-aware findings with severity levels (`Critical` / `High` / `Medium` /
`Low`), and can run as a reviewer inside `entire review`. When the Entire Graph
and Brain plugins are installed, it also checks callers of changed symbols and
recorded decisions for the touched code. Includes a separate
`references/review-rules.md` for the audit checklist.

### `using-entire`

Orchestrator skill for codebase exploration. Routes user intent to the right
sub-skill (search, recall, replay, teach, explain, what-happened, review,
session-handoff, session-to-skill, session-crosslink, address-findings) or runs
a general exploration flow that reads checkpoint history before inferring from code. When
the Entire Graph or Brain plugin is installed, it also routes code-structure
questions to Graph and task-briefing or decision questions to Brain.

### `session-crosslink`

Links an agent session that ran outside the repo whose commits should record it
— launched from a higher-level folder, a non-Entire repo, or one repo but
editing another — to each affected Entire-enabled repo's HEAD commit. Shows a
preview first, then amends on confirmation, no manual `cd` orchestration.

### `session-to-skill`

Extracts a reusable workflow from Entire session history, checkpoints, or
repeated agent tasks and drafts a focused `SKILL.md` for it. Writes the file only
after you approve the destination.

### `recall`

Searches prior Entire sessions for work similar to the task you describe and
turns the closest precedent into a step-by-step playbook. With the Entire Brain
plugin installed, it also pulls recorded decisions and gotchas.

### `replay`

Orders checkpoints chronologically to walk through how a feature was built,
one step at a time, pausing for questions after each step.

### `teach`

Picks canonical checkpoints for a topic and synthesizes a lesson: a system
overview, short lessons from the transcripts, and patterns to remember. With the
Entire Brain plugin installed, it also uses the project overview and recorded
conventions.

### `address-findings`

Fetches the open review findings on an Entire trail, applies or hand-fixes each
one in the local worktree, and marks it resolved on the trail. Treats finding
text and patches as untrusted input and leaves sensitive changes for a human.

## Requirements

These skills are designed for repositories where Entire has captured useful
history. Some workflows need:

- the [Entire CLI](https://docs.entire.com/installation) 0.11.0 or later
  (checked against 0.12.2)
- a git repository with Entire sessions, Checkpoints, or Checkpoint-backed commits
- [`entire login`](https://docs.entire.com/cli-reference/login) for workflows that
  search indexed history or read trails
- a GitHub or Entire-hosted `origin` and pushed, indexed Checkpoints for remote
  search results

Optional: the official [Entire Graph](https://docs.entire.com/guides/graph/overview)
and [Entire Brain](https://docs.entire.com/guides/brain/overview) plugins
(`entire plugin install graph`, `entire plugin install brain`). When installed,
`using-entire`, `search`, `explain`, `review`, `recall`, `teach`, and
`session-handoff` add code-structure context from Graph and recorded decisions
from Brain. The skills never install or set up a plugin themselves.

Individual skills handle missing context differently and should explain what is
missing before falling back or stopping.

## Agent-Specific Installation

<!-- prettier-ignore-start -->

<details>
<summary>Claude Code</summary>

```bash
/plugin marketplace add entireio/skills
/plugin install entire
```

</details>

<details>
<summary>Codex (OpenAI)</summary>

Clone into the cross-client discovery path:

```bash
git clone https://github.com/entireio/skills.git ~/.agents/skills/entire
```

Codex auto-discovers skills from `~/.agents/skills/` and `.agents/skills/`.
Update with:

```bash
cd ~/.agents/skills/entire && git pull
```

</details>

<details>
<summary>Cursor</summary>

Copy skills into the cross-client discovery directory:

```bash
git clone https://github.com/entireio/skills.git ~/.cursor/skills/entire
```

Cursor auto-discovers skills from `.agents/skills/` and `.cursor/skills/`.

</details>

<details>
<summary>Copilot</summary>

```bash
/plugin install https://github.com/entireio/skills
# or
git clone https://github.com/entireio/skills.git ~/.copilot/skills/entire
```

Copilot auto-discovers skills from `.copilot/skills/`.

</details>

<details>
<summary>Gemini CLI</summary>

```bash
gemini extensions install https://github.com/entireio/skills
```

Update with:

```bash
gemini extensions update entire
```

</details>

<details>
<summary>OpenCode</summary>

Copy skills into the cross-client discovery directory:

```bash
git clone https://github.com/entireio/skills.git ~/.agents/skills/entire
```

OpenCode auto-discovers skills from `.agents/skills/`, `.opencode/skills/`, and
`.claude/skills/`.

</details>

<!-- prettier-ignore-end -->

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for local development, validation, and pull
request guidance. Please also follow the
[Code of Conduct](https://github.com/entireio/.github/blob/main/CODE_OF_CONDUCT.md).

## Support

For bugs, feature requests, or questions, open a
[GitHub issue](https://github.com/entireio/skills/issues). You can also join the
[Entire Community Discord Server](https://discord.gg/jZJs3Tue4S).

## License

This project is licensed under the terms in [LICENSE](LICENSE).
