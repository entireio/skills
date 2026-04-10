# Installing Agent Plugins for Cursor

Enable Entire agent plugins in Cursor via native skill discovery.

## Prerequisites

- Git

## Installation

1. Clone and symlink:

```bash
git clone https://github.com/entireio/agent-plugins.git ~/.cursor/agent-plugins
ln -s ~/.cursor/agent-plugins/skills ~/.agents/skills/agent-plugins
```

2. Restart Cursor to discover the skills.

Verify by asking: "Use the `session-handoff` skill."
