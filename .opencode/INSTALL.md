# Installing Entire Agent Skills for OpenCode

Enable Entire agent skills in OpenCode via native skill discovery.

## Prerequisites

- Git
- A local clone of this repository

## Installation

1. Create the skills symlink:

```bash
mkdir -p ~/.agents/skills
ln -s /path/to/entire-agent-skills/skills ~/.agents/skills/entire-agent-skills
```

Replace `/path/to/entire-agent-skills` with the path to your local clone of this repository.

2. Restart OpenCode. That's it.

Verify by asking: "Use the `hand-off-session` skill."
