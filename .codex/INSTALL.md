# Installing Agent Plugins for Codex

Enable Entire agent plugins in Codex via native skill discovery.

## Prerequisites

- Git

## Installation

1. Clone and symlink:

```bash
git clone https://github.com/entireio/agent-plugins.git ~/.codex/agent-plugins
ln -s ~/.codex/agent-plugins/skills ~/.agents/skills/agent-plugins
```

2. Restart Codex to discover the skills.

Verify by asking: "Use the `session-handoff` skill."
