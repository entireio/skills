# Installing Agent Plugins for Codex

Enable Entire in Codex as a plugin.

## Prerequisites

- Git

## Installation

1. Clone the repository:

```bash
git clone https://github.com/entireio/agent-plugins.git ~/.codex/agent-plugins
```

2. Register the repo-local marketplace in Codex:

```text
/plugin marketplace add ~/.codex/agent-plugins/.agents/plugins/marketplace.json
```

3. Install the `entire` plugin from that marketplace:

```text
/plugin install entire@agent-plugins
```

Verify by asking: "Use the `session-handoff` skill."
