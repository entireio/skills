# Installing Skills for OpenCode

Enable Entire skills in OpenCode via native skill discovery from `skills/`.

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed

## Installation

The published `skills` package installs the `entire` plugin, which exposes the skills in `./skills/`.

Add to your OpenCode config:

```json
{
  "plugin": ["skills@git+https://github.com/entireio/skills.git"]
}
```

To pin a specific version:

```json
{
  "plugin": ["skills@git+https://github.com/entireio/skills.git#v0.2.0"]
}
```

Restart OpenCode. The plugin in `.opencode/plugins/entire.js` automatically registers the skills directory — no additional configuration needed.

Verify by asking: "Use the `session-handoff` skill."
