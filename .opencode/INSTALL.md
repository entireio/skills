# Installing Agent Plugins for OpenCode

Enable Entire agent plugins in OpenCode via native skill discovery from `plugins/entire/skills`.

## Prerequisites

- Git

## Installation

The published `agent-plugins` package installs the `entire` plugin from `plugins/entire`, which exposes the skills in `plugins/entire/skills`.

Add to your OpenCode config:

```json
{
  "plugin": ["agent-plugins@git+https://github.com/entireio/agent-plugins.git"]
}
```

To pin a specific version:

```json
{
  "plugin": ["agent-plugins@git+https://github.com/entireio/agent-plugins.git#v0.1.0"]
}
```

Restart OpenCode. That's it.

Verify by asking: "Use the `session-handoff` skill."
