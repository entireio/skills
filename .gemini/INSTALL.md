# Installing Agent Plugins for Gemini

Enable Entire agent plugins in Gemini via native skill discovery.

## Prerequisites

- Git

## Installation

1. Clone and symlink:

```bash
git clone https://github.com/entireio/agent-plugins.git ~/.gemini/agent-plugins
ln -s ~/.gemini/agent-plugins/skills ~/.agents/skills/agent-plugins
```

2. Restart Gemini to discover the skills.

Verify by asking: "Use the `session-handoff` skill."
