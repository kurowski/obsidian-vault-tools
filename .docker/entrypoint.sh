#!/bin/bash
# Entrypoint for the Claude Code Obsidian container.
# Clones playbook and wiki repos on first run if they don't already exist.

clone_if_missing() {
  local target="$1"
  local repo="$2"

  if [ -d "$target/.git" ]; then
    return
  fi

  # Directory exists but isn't a git repo (e.g., synced by Obsidian) — remove so we can clone
  if [ -d "$target" ] && [ ! -d "$target/.git" ]; then
    echo "Removing non-git directory $target to clone fresh..."
    rm -rf "$target"
  fi

  if [ -z "$GH_TOKEN" ]; then
    echo "WARNING: $target missing and GH_TOKEN not set — skipping clone of $repo"
    return
  fi

  echo "Cloning $repo into $target ..."
  if gh repo clone "$repo" "$target" 2>&1; then
    echo "Cloned $repo successfully."
  else
    echo "WARNING: Failed to clone $repo — continuing anyway."
  fi
}

clone_if_missing /workspace/playbook UCEAP/itse-playbook
clone_if_missing /workspace/github-wiki UCEAP/.github-private.wiki

# Ensure the vault tooling repo's main branch tracks origin/main
if [ -d /workspace/.git ]; then
  git -C /workspace branch --set-upstream-to=origin/main main 2>/dev/null
fi

exec sleep infinity
