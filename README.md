# obsidian-vault-tools

Tooling overlay for an Obsidian vault, designed to run [Claude Code](https://claude.ai/code) as an AI assistant against your notes.

Vault content (markdown notes) is synced by **Obsidian Sync**. This repo tracks only the tooling that Obsidian Sync doesn't handle: the Docker setup, Claude Code skills, helper scripts, and config files.

## What's included

| Path | Purpose |
|---|---|
| `.docker/Dockerfile` | Container image for running Claude Code |
| `.claude/skills/` | Claude Code skills (morning briefing, meeting prep, task triage, etc.) |
| `.claude/jira-helper.sh` | Helper for Jira API queries |
| `.claude/settings.json` | Shared Claude Code settings |
| `.claudeignore` | Tells Claude Code which vault paths to ignore |
| `CLAUDE.md` | Project instructions that Claude Code reads automatically |

## Setup

### Prerequisites

- An Obsidian vault synced via Obsidian Sync
- Docker
- A Claude Code API key (Anthropic or Foundry)

### 1. Clone into your vault

After Obsidian Sync has synced the vault to a new machine:

```bash
cd ~/Documents/Notes   # or wherever your vault lives
git init
git remote add origin https://github.com/kurowski/obsidian-vault-tools.git
git pull origin main
```

The `.gitignore` is set to ignore everything by default, so vault content stays out of git.

### 2. Build and run the container

```bash
docker build -t claude-obsidian -f Documents/Notes/.docker/Dockerfile Documents/Notes/

docker run -d \
  --name obsidian-claude \
  -v "$HOME/Documents/Notes":/workspace \
  -v "$HOME/.obsidian-claude":/home/claude/.claude \
  -e ANTHROPIC_API_KEY \
  -e JIRA_API_TOKEN \
  -e JIRA_BASE_URL \
  -e JIRA_EMAIL \
  -e GH_TOKEN \
  claude-obsidian
```

If you're using Anthropic Foundry instead of a direct API key, replace the `ANTHROPIC_API_KEY` line with Foundry variables:

```bash
docker run -d \
  --name obsidian-claude \
  -v "$HOME/Documents/Notes":/workspace \
  -v "$HOME/.obsidian-claude":/home/claude/.claude \
  -e CLAUDE_CODE_USE_FOUNDRY=1 \
  -e ANTHROPIC_FOUNDRY_RESOURCE=your-foundry-resource \
  -e ANTHROPIC_FOUNDRY_API_KEY \
  -e JIRA_API_TOKEN \
  -e JIRA_BASE_URL \
  -e JIRA_EMAIL \
  -e GH_TOKEN \
  claude-obsidian
```

Create the persistent config directory first if it doesn't exist:

```bash
mkdir -p $HOME/.obsidian-claude
```

### 3. Add a shell alias

Add to your `.zshrc` or `.bashrc`:

```bash
oc() {
  docker start obsidian-claude 2>/dev/null
  docker exec -it obsidian-claude claude "$@"
}
alias ocr='oc --resume'
```

Then start a session with `oc`. You can resume a previous session with `ocr`.

## Environment variables

| Variable | Required | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | Yes* | Claude API access |
| `CLAUDE_CODE_USE_FOUNDRY` | No | Set to `1` to use Foundry instead of direct API |
| `ANTHROPIC_FOUNDRY_RESOURCE` | No* | Foundry resource name |
| `ANTHROPIC_FOUNDRY_API_KEY` | No* | Foundry API key |
| `JIRA_API_TOKEN` | No | Jira integration for skills |
| `JIRA_BASE_URL` | No | Jira instance URL |
| `JIRA_EMAIL` | No | Jira account email |
| `GH_TOKEN` | No | GitHub API access for notifications |

\* Provide either `ANTHROPIC_API_KEY` or the three `FOUNDRY` variables.

## Syncing tooling changes

When you modify skills, the Dockerfile, or other tracked files, commit and push so changes reach your other machines:

```bash
git add -A && git commit -m "description of change" && git push
```

On session start, Claude Code automatically runs `git pull` to pick up changes from the other direction.
