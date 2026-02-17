#!/bin/bash
# GitHub activity helper functions for Claude Code skills
# Requires: gh CLI authenticated (gh auth status)
# Optional: GITHUB_ORG env var (defaults to "UCEAP")

GITHUB_ORG="${GITHUB_ORG:-UCEAP}"

# Map of repo slugs to human-friendly names
declare -A GH_REPO_NAMES=(
    ["myeap2"]="Portal"
    ["uceap-reciprocity"]="Reciprocity"
    ["uceap-website"]="Website"
    ["uceap-alumni"]="Alumni"
    ["research"]="Research"
    ["ucdcweb2"]="UCDC Website"
    ["ucdcsis2"]="UCDC SIS"
    ["itse-playbook"]="Playbook"
    [".github-private"]="GitHub Private"
)

# Check that gh CLI is authenticated
# Usage: gh_check_auth
gh_check_auth() {
    if ! command -v gh &>/dev/null; then
        echo "Error: gh CLI not found" >&2
        return 1
    fi
    if ! gh auth status &>/dev/null; then
        echo "Error: gh CLI not authenticated. Run 'gh auth login' first." >&2
        return 1
    fi
    return 0
}

# Map a repo slug to its friendly name
# Usage: gh_repo_friendly_name "myeap2"
# Returns: "Portal" (or the slug itself if no mapping exists)
gh_repo_friendly_name() {
    local slug="$1"
    echo "${GH_REPO_NAMES[$slug]:-$slug}"
}

# Search for merged PRs in a date range (org-wide)
# Usage: gh_search_prs_merged "2026-01-01" "2026-01-31"
gh_search_prs_merged() {
    local start="$1"
    local end="$2"
    gh api --paginate "search/issues?q=org:${GITHUB_ORG}+is:pr+is:merged+merged:${start}..${end}&per_page=100" \
        --jq '.items[] | {
            repo: (.repository_url | split("/") | last),
            number: .number,
            title: .title,
            author: .user.login,
            merged_at: .pull_request.merged_at,
            url: .html_url
        }' 2>/dev/null
}

# Search for opened PRs in a date range (org-wide)
# Usage: gh_search_prs_opened "2026-01-01" "2026-01-31"
gh_search_prs_opened() {
    local start="$1"
    local end="$2"
    gh api --paginate "search/issues?q=org:${GITHUB_ORG}+is:pr+created:${start}..${end}&per_page=100" \
        --jq '.items[] | {
            repo: (.repository_url | split("/") | last),
            number: .number,
            title: .title,
            author: .user.login,
            created_at: .created_at,
            state: .state,
            url: .html_url
        }' 2>/dev/null
}

# Search for closed issues in a date range (org-wide)
# Usage: gh_search_issues_closed "2026-01-01" "2026-01-31"
gh_search_issues_closed() {
    local start="$1"
    local end="$2"
    gh api --paginate "search/issues?q=org:${GITHUB_ORG}+is:issue+is:closed+closed:${start}..${end}&per_page=100" \
        --jq '.items[] | {
            repo: (.repository_url | split("/") | last),
            number: .number,
            title: .title,
            author: .user.login,
            closed_at: .closed_at,
            url: .html_url
        }' 2>/dev/null
}

# List all repos in the org
# Usage: gh_org_repos
gh_org_repos() {
    gh api --paginate "orgs/${GITHUB_ORG}/repos?per_page=100" \
        --jq '.[] | {
            name: .name,
            friendly_name: .name,
            full_name: .full_name,
            private: .private,
            updated_at: .updated_at
        }' 2>/dev/null
}
