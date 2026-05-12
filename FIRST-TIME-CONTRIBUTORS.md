# First-Time Contributors

Welcome. This guide is for people who are new to Entire, new to open source, or
just want a careful path through their first contribution to this repository.

The main contribution rules live in [CONTRIBUTING.md](CONTRIBUTING.md). Treat
that file as the source of truth. This page slows the process down and explains
where to start, what to say, what to run, and what to expect after you open a
pull request.

## Who This Is For

Start here if any of these are true:

- You have never opened a pull request before.
- You have contributed to other projects, but not to Entire.
- You want help finding a contribution that is small enough to finish.
- You are unsure how to ask maintainers for the right amount of context.

If you are already comfortable with this repo, use the shorter workflow in
[CONTRIBUTING.md](CONTRIBUTING.md).

## What This Repo Contains

This repo is intentionally small. Each skill lives in
`skills/<skill-name>/SKILL.md`, with a few plugin and extension metadata files
that make the same skills installable across different agents (Claude Code,
Codex, Cursor, Copilot, Gemini, OpenCode).

A skill is a short Markdown file with YAML front matter that tells a coding
agent when to run a specific workflow and how to run it. Most contributions are
edits to a `SKILL.md` file, a small new skill, or a wording fix to the README or
contributor docs.

## Choose a First Contribution

Start by browsing [GitHub Issues](https://github.com/entireio/skills/issues) for
issues that describe behavior you can reproduce, mention a skill or prompt you
can try locally, or feel concrete enough that you can explain the problem back
in your own words. You can also ask in the
[Entire Community Discord](https://discord.gg/jZJs3Tue4S). You do not need to
understand the whole project before asking about an issue.

Good first contributions are small, clear, and easy to review. For this repo,
that usually means one of these:

- Clarifying wording in an existing `SKILL.md` after you hit real friction.
- Adding a missing failure mode or "when not to use" note to a skill.
- Improving the README or contributor instructions after you got stuck.
- Fixing a broken link, typo, or stale example command.
- Adding a small, focused new skill for a workflow you already use.

When looking at an issue, favor ones where you can explain the problem back in
your own words. It is okay if you do not know the fix yet. If an issue is broad,
comment with the part you think you can tackle and ask whether that slice would
be useful.

As a first PR, avoid sweeping rewrites of multiple skills, renaming existing
skills, or changing plugin or marketplace metadata across all the agent
integrations at once. Those changes are worth doing, but they are easier as
follow-ups once a maintainer has helped define the scope.

## Comment Before You Start

Before starting non-trivial work, leave a short comment on the issue or open a
new one. This avoids duplicated effort and gives maintainers a chance to
redirect you before you spend time on the wrong approach.

A good first comment is specific:

```text
Hi, I am new to Entire and would like to work on this.

I tried the `search` skill in my own repo and the agent could not tell whether
`entire login` was required. My plan is to update skills/search/SKILL.md so the
agent explains the missing prerequisite before falling back. Does that sound
like the right direction?
```

If you are not starting from an existing issue, open one with the smallest
concrete problem you can describe:

```text
I hit confusing behavior while asking my agent to `explain` a function.

Expected: the agent would tell me when no Entire session was found.
Actual: the agent guessed an explanation from the code only.

Would a small PR that tightens the "when not to use" section of
skills/explain/SKILL.md be useful?
```

You do not need a perfect plan. Showing what you have tried and where you are
headed is usually enough.

## Set Up the Repository

Fork the repository on GitHub, then clone your fork:

```bash
git clone git@github.com:YOUR-USERNAME/skills.git
cd skills
```

Add the upstream repository so you can pull in maintainer changes later:

```bash
git remote add upstream git@github.com:entireio/skills.git
git fetch upstream
```

There is no build step. The skills are plain Markdown files plus a small amount
of JSON metadata, so you do not need a toolchain beyond `git` and `node` (used
only for validation below).

## Create a Branch

Create a branch from the latest `main`:

```bash
git switch main
git pull upstream main
git switch -c docs/clarify-search-prereqs
```

Use a branch name that describes the change. Examples:

- `docs/clarify-search-prereqs`
- `fix/explain-when-not-to-use`
- `skill/add-release-notes`

## Make a Small Change

Keep your first pull request narrow. A focused PR is easier to review and
easier to finish.

Good first PR shapes:

- One wording fix in an existing `SKILL.md`.
- One added "when not to use" or failure-mode note.
- One small new skill for a single, repeatable workflow.
- One README or contributor doc clarification based on a real problem you hit.

If you are adding or editing a skill, read one existing skill that is similar
to your change first. For example, `skills/explain/SKILL.md` and
`skills/what-happened/SKILL.md` are good references for tone and level of
detail.

Every `SKILL.md` needs YAML front matter with at least:

```yaml
---
name: skill-name
description: A short description of when an agent should use this skill.
---
```

Avoid bundling unrelated cleanup with your first PR. If you notice extra things
while working, leave yourself a note and open a follow-up issue or PR later.

## Use AI Carefully

It is completely normal to use coding agents while contributing to this repo.
We hope you like Goose, of course. There is no need to tell us that you used AI
in your work.

Use whatever agent and workflow you like. The important rule is that you are
responsible for the final wording, examples, and metadata. Before submitting a
PR, review the diff yourself. PRs that look generated, unreviewed, or "vibe
coded" without a human pass may be closed.

Quick responsible AI tips:

- **Think first.** Agents tend to jump straight to edits. Ask the agent to read
  one or two existing skills and explain the repo's style before it writes a
  new one.
- **Push back on shortcuts.** Watch for vague descriptions, hand-wavy "when to
  use" sections, and instructions that read like marketing instead of a
  concrete workflow.
- **Notice uncertainty.** If the agent keeps rewriting the same paragraph
  without converging, stop and reframe the task in fewer words.
- **Cut the bloat.** Skills should stay focused on one repeatable workflow.
  Remove general-purpose advice, unnecessary preamble, and examples that do not
  match the workflow.

## Run the Right Checks

For wording-only Markdown changes, a quick sanity check is enough:

```bash
git diff --check
```

For changes to a `SKILL.md` or new skills, confirm the installer can still
discover the skills in this repo:

```bash
npx -y skills@latest add . --list --yes
```

If you changed any JSON metadata, validate that the JSON still parses:

```bash
node -e 'for (const f of ["package.json","gemini-extension.json",".codex-plugin/plugin.json",".claude-plugin/plugin.json",".cursor-plugin/plugin.json",".agents/plugins/marketplace.json"]) JSON.parse(require("fs").readFileSync(f, "utf8"))'
```

If you changed the OpenCode plugin shim, check its syntax:

```bash
node --check .opencode/plugins/entire.js
```

For Markdown-only changes, read the rendered Markdown or preview it in GitHub
before submitting.

## Commit Your Work

Commit with a short, descriptive message:

```bash
git add <files you changed>
git commit -m "Clarify search skill prerequisites"
```

If you have the Entire CLI installed and enabled in this repository, the git
hook may add an `Entire-Checkpoint` trailer to your commit message
automatically. That is expected.

## Open a Pull Request

Push your branch to your fork:

```bash
git push -u origin docs/clarify-search-prereqs
```

Then open a pull request against `entireio/skills` on GitHub.

In the PR description, include:

- The issue it addresses, if there is one.
- A short summary of what changed and why.
- Which skill changed, if any.
- The validation you ran (for example,
  `npx -y skills@latest add . --list --yes`).
- If you changed skill behavior, a short example prompt that shows the new or
  updated behavior.

If your PR is not ready for final review yet, open it as a draft. Draft PRs are
useful when you want early feedback on direction.

## Respond to Review

Review is part of the contribution, not a sign that you did something wrong.

For each review comment:

- If it is right, push a follow-up commit that addresses it.
- If you are unsure, ask a question on the PR.
- If you disagree, explain your reasoning briefly and respectfully.

After pushing updates, leave a short comment saying what changed. GitHub does
not always make it obvious which comments were addressed by a new commit.

## If You Get Stuck

Ask early, and include context. Good help requests include:

- What you are trying to do.
- The skill and prompt you used.
- The exact error or unexpected output.
- What you already checked.

Useful places to ask:

- The GitHub issue you are working on.
- The pull request, if one is already open.
- [Discord](https://discord.gg/jZJs3Tue4S) for general questions.

## Quick Checklist

Before opening your first PR:

- You picked a small, focused change.
- You asked for maintainer scope before non-trivial work.
- You created a branch from current `main`.
- You ran the checks that match your change.
- Your PR description explains what changed and how you tested it.

Thank you for taking the time to contribute. Small, careful improvements make
the project easier for the next person too.
