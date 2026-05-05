![Entire Skills cover](assets/gh-repo-cover.png)

# Skills

Bring your Entire context to your agents with cross-agent skills.

## Why This Exists

The [Entire CLI](https://github.com/entireio/cli) captures the context behind your
code changes: prompts, transcripts, Checkpoints, and the decisions that led to
each change, alongside your git history. This repository packages agent-invokable
workflows that teach coding agents how to use that context across development
environments.

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
> [Checkpoints](https://docs.entire.io/cli/checkpoints) and session history. The
> richer the history, the more context your agent has to work with; in a new or
> lightly captured repository, some workflows may have less to find or explain.

After installing, ask your agent for the workflow you want:

```text
search past work for rate limiting
```

```text
/explain src/auth.ts
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

For a guided walkthrough, see the
[Skills tutorial](https://docs.entire.io/skills/tutorial).

## What These Skills Help Agents Do

| Goal | Example prompt |
| --- | --- |
| Find prior work before making changes | `search past work for the migration` |
| Understand the intent behind a function, file, or line | `/explain parseConfig` |
| Investigate the latest change to a specific block | `what happened at src/auth.ts:42` |
| Pick up another agent's work | `hand off the codex session` |
| Convert repeated work into a reusable workflow | `make a skill from this session` |

## Included Skills

The current repository includes these skills. Each skill lives in
`skills/<skill-name>/SKILL.md`.

### `search`

Finds prior work in your Entire history by topic, repo, branch, author, or time
window, so your agent can bring past context into the current task before making
changes.

### `explain`

Looks up the session behind a function, file, or line so your agent can explain
the requirement, decision, or original problem that shaped it.

### `what-happened`

Starts from an exact file line, range, or pasted snippet and traces the latest
change with `git blame` and Checkpoint context. Useful when reviewing a concrete
block, debugging a regression, or asking why that block changed.

### `session-handoff`

Reads saved or active session context so another agent can pick up the task
state, important discoveries, blockers, and next steps without making you
reconstruct everything manually.

### `session-to-skill`

Turns repeated agent sessions into reusable `SKILL.md` drafts. It extracts the
process from real work instead of asking you to write idealized instructions
from scratch.

## Requirements

These skills are designed for repositories where Entire has captured useful
history. Some workflows need:

- the [Entire CLI](https://github.com/entireio/cli) installed
- a git repository with Entire sessions, Checkpoints, or Checkpoint-backed commits
- [`entire login`](https://docs.entire.io/cli/commands#login) for workflows that
  search indexed history
- a GitHub `origin` and pushed, indexed Checkpoints for remote search results

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
