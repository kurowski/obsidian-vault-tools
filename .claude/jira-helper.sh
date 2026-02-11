#!/bin/bash
# Jira API helper functions for Claude Code skills
# Requires: JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN environment variables

# Fetch a single ticket's details (JSON output)
# Usage: jira_get_ticket "UP-684"
jira_get_ticket() {
    local ticket_key="$1"
    curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
        -H "Accept: application/json" \
        "${JIRA_BASE_URL}/rest/api/3/issue/${ticket_key}?fields=summary,status,assignee,priority,description,updated,created,labels" \
        | jq '{
            key: .key,
            summary: .fields.summary,
            status: .fields.status.name,
            statusCategory: .fields.status.statusCategory.name,
            assignee: (.fields.assignee.displayName // "Unassigned"),
            priority: .fields.priority.name,
            updated: .fields.updated,
            created: .fields.created,
            labels: .fields.labels
        }'
}

# Get a concise one-line summary of a ticket
# Usage: jira_ticket_summary "UP-684"
jira_ticket_summary() {
    local ticket_key="$1"
    curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
        -H "Accept: application/json" \
        "${JIRA_BASE_URL}/rest/api/3/issue/${ticket_key}?fields=summary,status,assignee" \
        | jq -r 'if .key then "\(.key): \(.fields.summary) [\(.fields.status.name)] (assignee: \(.fields.assignee.displayName // "Unassigned"))" else "Error fetching \(input)" end'
}

# Fetch multiple tickets (pass space-separated list)
# Usage: jira_get_multiple_tickets "UP-684 RWSP2-708 WEBP4-123"
jira_get_multiple_tickets() {
    local tickets="$1"
    for ticket in $tickets; do
        jira_ticket_summary "$ticket"
    done
}

# Extract all Jira ticket codes from a file
# Usage: jira_extract_tickets_from_file "filename.md"
jira_extract_tickets() {
    local file="$1"
    grep -ohiE '(UP-[0-9]+|RWSP2-[0-9]+|WEBP4-[0-9]+|UCDCSISDEV-[0-9]+|UCDCWEB2-[0-9]+|RWR-[0-9]+)' "$file" | sort -u
}

# Extract and fetch status for all tickets in a file
# Usage: jira_tickets_in_file "dev meeting.md"
jira_tickets_in_file() {
    local file="$1"
    local tickets=$(jira_extract_tickets "$file")
    if [ -n "$tickets" ]; then
        echo "Found tickets: $tickets"
        echo ""
        jira_get_multiple_tickets "$tickets"
    else
        echo "No Jira tickets found in $file"
    fi
}

# Generic JQL search via POST to /rest/api/3/search
# Uses POST to avoid GET URL-encoding issues with complex JQL
# Usage: jira_search_jql "assignee = currentUser() AND status != Done" [maxResults]
jira_search_jql() {
    local jql="$1"
    local max_results="${2:-50}"
    local jql_escaped
    jql_escaped=$(echo "$jql" | jq -Rs .)

    local response http_code body
    response=$(curl -s -w "\n%{http_code}" \
        -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "{\"jql\": ${jql_escaped}, \"maxResults\": ${max_results}, \"fields\": [\"summary\",\"status\",\"assignee\",\"priority\",\"updated\",\"created\",\"project\"]}" \
        "${JIRA_BASE_URL}/rest/api/3/search/jql")

    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo "$body" | jq '[.issues[] | {
            key: .key,
            project: .fields.project.key,
            summary: .fields.summary,
            status: .fields.status.name,
            statusCategory: .fields.status.statusCategory.name,
            assignee: (.fields.assignee.displayName // "Unassigned"),
            priority: .fields.priority.name,
            updated: .fields.updated,
            created: .fields.created
        }]'
    else
        echo "Error: Jira API returned HTTP $http_code" >&2
        echo "$body" | jq -r '.errorMessages[]? // .message // "Unknown error"' >&2
        return 1
    fi
}

# Fetch all open tickets assigned to the current user
# Usage: jira_my_open_tickets
jira_my_open_tickets() {
    jira_search_jql "assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC"
}

# Fetch tickets newly assigned to the current user within N days
# Usage: jira_newly_assigned_to_me [days]
jira_newly_assigned_to_me() {
    local days="${1:-7}"
    jira_search_jql "assignee = currentUser() AND assignee CHANGED DURING (-${days}d, now()) ORDER BY updated DESC"
}

# Fetch tickets with status changes across tracked projects within N days
# Usage: jira_status_changes [days]
jira_status_changes() {
    local days="${1:-3}"
    jira_search_jql "project in (UP, RWSP2, WEBP4, UCDCSISDEV, UCDCWEB2, RWR) AND status CHANGED DURING (-${days}d, now()) ORDER BY updated DESC"
}
