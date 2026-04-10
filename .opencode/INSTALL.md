# Installing Agent Plugins for OpenCode

Enable Entire agent plugins in OpenCode via native skill discovery.

## Prerequisites

- Git

## Installation

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
