# Contributing to skills

Thanks for helping improve skills. This repo is intentionally small: each
skill lives in `skills/<skill-name>/SKILL.md`, with a few plugin and extension
metadata files that make the same skills installable across different agents.

If this is your first time contributing here, see
[FIRST-TIME-CONTRIBUTORS.md](FIRST-TIME-CONTRIBUTORS.md) for a slower
walkthrough of how to pick a change, set up the repo, and open a PR.

## Before you start

Fork the repo:

1. Click [**Fork**](https://github.com/entireio/skills/fork).
2. Clone your fork:

```bash
git clone https://github.com/YOUR-USERNAME/skills.git
cd skills
```

Create a descriptive branch from `main`. Use a name that explains the skill or
change you are working on:

```bash
git checkout main
git pull origin main
git checkout -b add-session-review-skill
```

## Adding or changing a skill

Each skill must live at:

```text
skills/<skill-name>/SKILL.md
```

Every `SKILL.md` needs YAML front matter with at least:

```yaml
---
name: skill-name
description: A short description of when an agent should use this skill.
---
```

The `name` and `description` fields are required for skill discovery. Missing
metadata can cause installers to skip the skill.

Before writing, read one existing skill that is similar to your change. For
example, if you are adding a provenance skill, read `skills/explain/SKILL.md` or
`skills/what-happened/SKILL.md` first so the new instructions match the repo's
style and level of detail.

Good skill instructions should:

- say when to use the skill and when not to use it
- give the agent a concrete workflow
- name required commands, files, and expected inputs
- describe failure modes and what the agent should tell the user
- avoid secrets, private transcripts, or user-specific local paths
- stay focused on one repeatable workflow instead of becoming a general manual

If you add, remove, rename, or materially change a skill, update
`skills/using-entire/SKILL.md` in the same change with a short route or
description so the orchestrator stays current. Also update `README.md` when the
public list or examples change.

## Using AI

It is fine to use coding agents while contributing to this repo, and you do not
need to disclose that you did. Use whatever agent and workflow you like.

You are still responsible for the final wording, examples, and metadata. Review
the diff yourself before opening a PR. Watch for vague "when to use"
descriptions, instructions that read like marketing instead of a concrete
workflow, and generic advice that does not match this repo's style. PRs that
look generated, unreviewed, or "vibe coded" may be closed.

See [FIRST-TIME-CONTRIBUTORS.md](FIRST-TIME-CONTRIBUTORS.md#use-ai-carefully)
for longer guidance.

## Validation

Before opening a PR, check that the skills installer can discover the repo
skills:

```bash
npx -y skills@latest add . --list --yes
```

If you changed JSON metadata, validate the JSON:

```bash
node -e 'for (const f of ["package.json","gemini-extension.json",".codex-plugin/plugin.json",".claude-plugin/plugin.json",".cursor-plugin/plugin.json",".agents/plugins/marketplace.json"]) JSON.parse(require("fs").readFileSync(f, "utf8"))'
```

If you changed the OpenCode plugin shim, check its syntax:

```bash
node --check .opencode/plugins/entire.js
```

For Markdown-only changes, read the rendered Markdown or preview it in GitHub
before submitting.

## Pull requests

Push your branch:

```bash
git push origin add-session-review-skill
```

Open a pull request:

1. Go to your fork on GitHub.
2. Click **Compare & pull request**.
3. Make sure the base repository is `entireio/skills` and the base branch is
   `main`.

In the PR description, include:

- what changed
- why it changed
- which skill changed, if any
- what validation you ran

If you changed skill behavior, include a short example prompt that demonstrates
the new or updated behavior.

## Support

For bugs, feature requests, or questions, open a
[GitHub issue](https://github.com/entireio/skills/issues). You can also join the
[Entire Community Discord Server](https://discord.gg/jZJs3Tue4S).

## Style

- Prefer concise, direct instructions over long explanations.
- Use exact commands when the workflow depends on a command.
- Keep examples generic unless a specific tool or repo is required.
- Do not paste raw session transcripts into skills.
- Do not commit local agent state, logs, temp files, or machine-specific config.
