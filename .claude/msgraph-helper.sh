#!/bin/bash
# Microsoft Graph API helper functions for Claude Code skills
# Uses device code OAuth2 flow (public client, no secret needed)
#
# Required env vars:
#   MSGRAPH_CLIENT_ID   - Azure AD app registration client ID
#   MSGRAPH_TENANT_ID   - Azure AD tenant ID
#
# Azure AD Setup (one-time, performed by the user):
#   1. Azure Portal > App registrations > New registration
#   2. Name: "Claude Code Obsidian", single-tenant, public client
#   3. Redirect URI: https://login.microsoftonline.com/common/oauth2/nativeclient
#   4. Enable "Allow public client flows" under Authentication
#   5. API permissions (delegated): Calendars.Read, Files.Read.All, User.Read, offline_access
#   6. Grant admin consent
#   7. Set MSGRAPH_CLIENT_ID and MSGRAPH_TENANT_ID as container env vars
#
# Token storage: ~/.msgraph-tokens.json

MSGRAPH_TOKEN_FILE="${HOME}/.msgraph-tokens.json"
MSGRAPH_SCOPES="Calendars.Read Files.Read.All User.Read offline_access"

# Check required env vars are set
# Usage: msgraph_check_env
msgraph_check_env() {
    if [ -z "$MSGRAPH_CLIENT_ID" ]; then
        echo "Error: MSGRAPH_CLIENT_ID not set" >&2
        return 1
    fi
    if [ -z "$MSGRAPH_TENANT_ID" ]; then
        echo "Error: MSGRAPH_TENANT_ID not set" >&2
        return 1
    fi
    return 0
}

# Interactive first-time auth via device code flow
# User visits a URL and enters a code on any device
# Usage: msgraph_device_code_auth
msgraph_device_code_auth() {
    msgraph_check_env || return 1

    local scope_encoded
    scope_encoded=$(echo "$MSGRAPH_SCOPES" | sed 's/ /%20/g')

    # Request device code
    local device_response
    device_response=$(curl -s -X POST \
        "https://login.microsoftonline.com/${MSGRAPH_TENANT_ID}/oauth2/v2.0/devicecode" \
        -d "client_id=${MSGRAPH_CLIENT_ID}" \
        -d "scope=${scope_encoded}")

    local user_code device_code interval message
    user_code=$(echo "$device_response" | jq -r '.user_code')
    device_code=$(echo "$device_response" | jq -r '.device_code')
    interval=$(echo "$device_response" | jq -r '.interval // 5')
    message=$(echo "$device_response" | jq -r '.message')

    if [ "$user_code" = "null" ] || [ -z "$user_code" ]; then
        echo "Error: Failed to get device code" >&2
        echo "$device_response" | jq -r '.error_description // .error // "Unknown error"' >&2
        return 1
    fi

    echo ""
    echo "=== Microsoft Graph Authentication ==="
    echo "$message"
    echo "======================================="
    echo ""

    # Poll for token
    local token_response
    while true; do
        sleep "$interval"
        token_response=$(curl -s -X POST \
            "https://login.microsoftonline.com/${MSGRAPH_TENANT_ID}/oauth2/v2.0/token" \
            -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
            -d "client_id=${MSGRAPH_CLIENT_ID}" \
            -d "device_code=${device_code}")

        local error
        error=$(echo "$token_response" | jq -r '.error // empty')

        if [ -z "$error" ]; then
            # Success — save tokens
            local access_token refresh_token expires_in
            access_token=$(echo "$token_response" | jq -r '.access_token')
            refresh_token=$(echo "$token_response" | jq -r '.refresh_token')
            expires_in=$(echo "$token_response" | jq -r '.expires_in')
            local expires_at
            expires_at=$(( $(date +%s) + expires_in ))

            jq -n \
                --arg at "$access_token" \
                --arg rt "$refresh_token" \
                --argjson ea "$expires_at" \
                '{access_token: $at, refresh_token: $rt, expires_at: $ea}' \
                > "$MSGRAPH_TOKEN_FILE"
            chmod 600 "$MSGRAPH_TOKEN_FILE"

            echo "Authentication successful. Tokens saved to $MSGRAPH_TOKEN_FILE"
            return 0
        elif [ "$error" = "authorization_pending" ]; then
            continue
        elif [ "$error" = "slow_down" ]; then
            interval=$(( interval + 5 ))
            continue
        else
            echo "Error: $error" >&2
            echo "$token_response" | jq -r '.error_description // "Unknown error"' >&2
            return 1
        fi
    done
}

# Refresh an expired access token using the stored refresh token
# Usage: msgraph_refresh_token
msgraph_refresh_token() {
    msgraph_check_env || return 1

    if [ ! -f "$MSGRAPH_TOKEN_FILE" ]; then
        echo "Error: No token file found. Run msgraph_device_code_auth first." >&2
        return 1
    fi

    local refresh_token
    refresh_token=$(jq -r '.refresh_token' "$MSGRAPH_TOKEN_FILE")

    if [ "$refresh_token" = "null" ] || [ -z "$refresh_token" ]; then
        echo "Error: No refresh token available. Run msgraph_device_code_auth." >&2
        return 1
    fi

    local scope_encoded
    scope_encoded=$(echo "$MSGRAPH_SCOPES" | sed 's/ /%20/g')

    local token_response
    token_response=$(curl -s -X POST \
        "https://login.microsoftonline.com/${MSGRAPH_TENANT_ID}/oauth2/v2.0/token" \
        -d "grant_type=refresh_token" \
        -d "client_id=${MSGRAPH_CLIENT_ID}" \
        -d "refresh_token=${refresh_token}" \
        -d "scope=${scope_encoded}")

    local error
    error=$(echo "$token_response" | jq -r '.error // empty')

    if [ -z "$error" ]; then
        local access_token new_refresh_token expires_in expires_at
        access_token=$(echo "$token_response" | jq -r '.access_token')
        new_refresh_token=$(echo "$token_response" | jq -r '.refresh_token // empty')
        expires_in=$(echo "$token_response" | jq -r '.expires_in')
        expires_at=$(( $(date +%s) + expires_in ))

        # Use new refresh token if provided, otherwise keep the old one
        if [ -z "$new_refresh_token" ]; then
            new_refresh_token="$refresh_token"
        fi

        jq -n \
            --arg at "$access_token" \
            --arg rt "$new_refresh_token" \
            --argjson ea "$expires_at" \
            '{access_token: $at, refresh_token: $rt, expires_at: $ea}' \
            > "$MSGRAPH_TOKEN_FILE"
        chmod 600 "$MSGRAPH_TOKEN_FILE"

        return 0
    else
        echo "Error refreshing token: $error" >&2
        echo "$token_response" | jq -r '.error_description // "Unknown error"' >&2
        return 1
    fi
}

# Ensure we have a valid access token (auto-refresh or re-auth)
# Prints the access token to stdout on success
# Usage: token=$(msgraph_ensure_auth)
msgraph_ensure_auth() {
    msgraph_check_env || return 1

    if [ ! -f "$MSGRAPH_TOKEN_FILE" ]; then
        echo "No tokens found. Starting device code authentication..." >&2
        msgraph_device_code_auth || return 1
    fi

    local expires_at now
    expires_at=$(jq -r '.expires_at' "$MSGRAPH_TOKEN_FILE")
    now=$(date +%s)

    # Refresh if token expires within 5 minutes
    if [ "$now" -ge $(( expires_at - 300 )) ]; then
        echo "Token expired or expiring soon, refreshing..." >&2
        if ! msgraph_refresh_token; then
            echo "Refresh failed. Starting device code authentication..." >&2
            msgraph_device_code_auth || return 1
        fi
    fi

    jq -r '.access_token' "$MSGRAPH_TOKEN_FILE"
}

# Generic authenticated GET request to Microsoft Graph API
# Handles 401 with one retry after token refresh
# Usage: msgraph_api_get "https://graph.microsoft.com/v1.0/me"
msgraph_api_get() {
    local url="$1"
    local token
    token=$(msgraph_ensure_auth) || return 1

    local response http_code body
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer ${token}" \
        -H "Accept: application/json" \
        "$url")

    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -eq 401 ]; then
        # Token may have been revoked; try refresh and retry once
        echo "Got 401, attempting token refresh..." >&2
        if msgraph_refresh_token; then
            token=$(jq -r '.access_token' "$MSGRAPH_TOKEN_FILE")
            response=$(curl -s -w "\n%{http_code}" \
                -H "Authorization: Bearer ${token}" \
                -H "Accept: application/json" \
                "$url")
            http_code=$(echo "$response" | tail -1)
            body=$(echo "$response" | sed '$d')
        fi
    fi

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo "$body"
    else
        echo "Error: Microsoft Graph API returned HTTP $http_code" >&2
        echo "$body" | jq -r '.error.message // "Unknown error"' >&2
        return 1
    fi
}

# Fetch calendar events for a date range, handles pagination
# Usage: msgraph_calendar_view "2026-01-01" "2026-01-31"
# Output: JSON array of calendar events
msgraph_calendar_view() {
    local start="$1"
    local end="$2"
    local all_events="[]"
    local url="https://graph.microsoft.com/v1.0/me/calendarView?startDateTime=${start}T00:00:00Z&endDateTime=${end}T23:59:59Z&\$top=100&\$select=subject,start,end,organizer,isAllDay,isCancelled,onlineMeeting,webLink,body&\$orderby=start/dateTime"

    while [ -n "$url" ]; do
        local response
        response=$(msgraph_api_get "$url") || return 1

        # Extract events and merge into accumulated array
        local page_events
        page_events=$(echo "$response" | jq '[.value[] | {
            subject: .subject,
            start: .start.dateTime,
            end: .end.dateTime,
            organizer: .organizer.emailAddress.name,
            isAllDay: .isAllDay,
            isCancelled: .isCancelled,
            webLink: .webLink
        }]')

        all_events=$(echo "$all_events" "$page_events" | jq -s 'add')

        # Check for next page
        url=$(echo "$response" | jq -r '.["@odata.nextLink"] // empty')
    done

    echo "$all_events"
}

# Download a file from OneDrive/SharePoint
# Usage: msgraph_download_file "https://graph.microsoft.com/v1.0/me/drive/items/{id}/content" "/tmp/file.docx"
msgraph_download_file() {
    local url="$1"
    local output_path="$2"
    local token
    token=$(msgraph_ensure_auth) || return 1

    local http_code
    http_code=$(curl -s -w "%{http_code}" -o "$output_path" \
        -H "Authorization: Bearer ${token}" \
        -L "$url")

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        return 0
    else
        echo "Error: Download failed with HTTP $http_code" >&2
        return 1
    fi
}

# Convert a .docx file to plain text using pandoc
# Usage: msgraph_docx_to_text "/tmp/file.docx"
# Output: plain text to stdout
msgraph_docx_to_text() {
    local docx_path="$1"

    if [ ! -f "$docx_path" ]; then
        echo "Error: File not found: $docx_path" >&2
        return 1
    fi

    if ! command -v pandoc &>/dev/null; then
        echo "Error: pandoc not installed. Rebuild container with pandoc." >&2
        return 1
    fi

    pandoc -f docx -t plain --wrap=none "$docx_path"
}
