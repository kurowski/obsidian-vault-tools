---
name: start-my-day
aliases: ["smd", "morning"]
description: Morning orientation briefing with tasks due today, overdue summary, Jira activity, GitHub notifications, and day-specific meeting prep. Read-only.
allowed-tools: Read, Grep, Glob, AskUserQuestion, Bash
---

# Start My Day Workflow

You're helping the user get oriented for their workday with a single briefing that covers tasks, Jira activity, and meeting prep. This is a **read-only** skill — do not create or modify any files.

## Context

Today's date is {{CURRENT_DATE}}. The vault is at /workspace.

The user manages 5 direct reports: Armando, Christina, Helio, Jakob, Shaun.
The user's boss is Thomas.
Peers: Maggie (Magdala, project manager), Que (business analyst).

**External Resources**:

- **ITSE Playbook**: `/workspace/playbook/` - Contains SOPs and best practices. SOPs at `/workspace/playbook/docs/standard-operating-procedures/`, best practices at `/workspace/playbook/docs/fundamentals/`
- **GitHub Wiki**: `/workspace/github-wiki/` - Contains developer meeting agendas named `Developer-Meeting-Agenda-YYYY-MM-DD.md`
- **Jira API**: Helper functions at `/workspace/.claude/jira-helper.sh`

### Search Scope

Search the entire vault but **skip** these directories:
- `.obsidian/`
- `Omnivore/`
- `Clippings/`
- `Learning from Dutch/`

## Step 1: Determine Day of Week

Parse {{CURRENT_DATE}} to determine the day of week.

- **Monday**: Use AskUserQuestion to ask the user whether they have a **planning meeting** or a **refinement meeting** today (these alternate biweekly and there's no calendar integration to detect which).
  - If **planning**: ask a follow-up — which planning meeting? Offer options: "Portal planning", "UCDC planning", "Unified planning", "Website/Reciprocity planning"
  - If **refinement**: auto-select `refinement meeting.md`
  - Also offer a "Neither / skip meeting prep" option
- **Tuesday or Thursday**: Auto-prep for dev meeting (no question needed)
- **Any other day** (Wednesday, Friday, weekend): Skip meeting prep entirely

Store the result as the **meeting type** for Step 4.

## Step 2: Tasks Due Today & Overdue Summary

Search for incomplete tasks with due dates across the vault.

### Finding Tasks

Grep for lines matching `^- \[ \]` that also contain `📅` across all `.md` files, excluding `.obsidian/`, `Omnivore/`, `Clippings/`, and `Learning from Dutch/`.

### Tasks Due Today

Filter to tasks where the `📅 YYYY-MM-DD` date matches today's date. Display each with:
- Full task text
- `filepath:line_number` reference

If none, say "No tasks due today."

### Overdue Summary

Filter to tasks where the `📅 YYYY-MM-DD` date is before today. Then:

1. **Count by age bucket**:
   - 1-7 days overdue
   - 8-30 days overdue
   - 31-90 days overdue
   - 90+ days overdue
2. **Show the 5 most recently overdue tasks** (closest to today's date) with full detail and `filepath:line_number` references

This keeps the briefing scannable even when there are many overdue tasks.

## Step 3: Jira Activity

Source the Jira helper and fetch activity. If Jira API calls fail (missing credentials, network issues), print a warning and continue with vault-only data — do not abort the briefing.

```bash
source /workspace/.claude/jira-helper.sh
```

### My Open Tickets

Call `jira_my_open_tickets`. Group results by project (UP, RWSP2, WEBP4, UCDCSISDEV, UCDCWEB2, RWR). For each ticket show: key, summary, status.

### Newly Assigned to Me

Call `jira_newly_assigned_to_me 7`. For each ticket returned, search the vault for its key (e.g., grep for `UP-1234`). Flag any tickets that have **no mentions** in the vault — these are new assignments the user hasn't started tracking yet.

### Recent Status Changes

Call `jira_status_changes 3`. **Exclude** tickets that moved to a Done/Closed status category — these never need follow-up. Only show tickets that changed to a non-Done status (e.g., moved into In Progress, Ready for TEST, Blocked, etc.) as those represent active work worth knowing about.

## Step 4: GitHub Notifications

Fetch unread GitHub notifications using the `gh` CLI. If the command fails (not authenticated, network issues), print a warning and continue — do not abort the briefing.

```bash
gh api notifications --jq '.[] | {reason: .reason, title: .subject.title, type: .subject.type, repo: .repository.full_name, updated: .updated_at}'
```

### Processing

Group notifications by **reason** for readability. Common reasons and their meanings:

- `review_requested` — Someone requested your review on a PR
- `assign` — You were assigned to an issue or PR
- `mention` — You were @mentioned
- `comment` — New comment on a thread you're subscribed to
- `ci_activity` — CI status change on a PR you're involved in
- `state_change` — Issue/PR was opened or closed
- `subscribed` — Activity on a repo or thread you're watching

For each notification show:
- **Title** of the issue/PR
- **Repository** name (short form, e.g., `org/repo`)
- **Type** (PullRequest or Issue)
- **When** it was updated (relative, e.g., "2 hours ago", "yesterday")

If there are no unread notifications, say "No unread GitHub notifications."

### Resilience

If `gh api notifications` fails, print: "GitHub API unavailable — skipping notifications" and continue.

## Step 5: Day-Specific Meeting Prep

Based on the meeting type determined in Step 1, run a condensed version of meeting prep. This step and the GitHub notifications step (Step 4) can run in parallel since they're independent. This is intentionally lighter than the full `/meeting-prep` skill — the user can run that separately for deeper prep.

### Monday — Planning Meeting

1. Resolve the planning file based on user's choice:
   - "Portal planning" → `portal planning.md`
   - "UCDC planning" → `ucdc planning meeting.md`
   - "Unified planning" → `unified planning.md`
   - "Website/Reciprocity planning" → `website reciprocity planning.md`
2. Read the file and find the most recent dated section (heading with a date). Summarize it in 3-5 bullets.
3. Find open tasks (`- [ ]` lines) in the file.
4. Extract Jira tickets from the file using `jira_extract_tickets`, then fetch status with `jira_get_multiple_tickets`.
5. Search the vault for mentions of the relevant project prefix since the last meeting date.
6. Synthesize 3-5 suggested discussion topics.

### Monday — Refinement Meeting

1. Read `refinement meeting.md`
2. Find the most recent dated section and summarize in 3-5 bullets.
3. Find open tasks in the file.
4. Extract and fetch Jira tickets from the file.
5. Cross-vault search for related mentions.
6. Synthesize 3-5 suggested topics.

### Tuesday/Thursday — Dev Meeting

1. Read `dev meeting.md` — extract the standup section at the top of the file and the most recent dated section. Summarize in 3-5 bullets.
2. Find open tasks in `dev meeting.md`.
3. **GitHub Wiki agenda**: Look for today's agenda at `/workspace/github-wiki/Developer-Meeting-Agenda-YYYY-MM-DD.md` (using today's date). If not found, find the most recent one by globbing `Developer-Meeting-Agenda-2026-*`. Surface any pre-populated topics.
4. **Team status**: For each direct report (Armando, Christina, Helio, Jakob, Shaun), read their `{Name} 1on1.md` file, find the most recent dated section, and extract 2-3 key bullets about current work, blockers, or updates.
5. Extract Jira tickets from `dev meeting.md` and fetch status with `jira_get_multiple_tickets`.
6. **Playbook SOP**: Read `/workspace/playbook/docs/standard-operating-procedures/conduct-a-developer-meeting.md` and include a brief reminder of the meeting flow.
7. Synthesize 3-5 suggested discussion topics.

### Other Days (or "skip" chosen on Monday)

Output: "No recurring meetings to prep for today."

## Step 6: Format and Display

Output the entire briefing as a single structured document:

```
## Good Morning — {YYYY-MM-DD} ({Day of Week})

### Tasks Due Today
{Tasks due today with filepath:line refs, or "No tasks due today."}

### Overdue Tasks Summary
{Age bucket counts + 5 most recently overdue tasks, or "No overdue tasks."}

### Jira Activity

**My Open Tickets**
{Tickets grouped by project}

**Newly Assigned (last 7 days)**
{New assignments, flagging those not yet in vault notes}

**Recent Status Changes (last 3 days)**
{Non-Done status changes only — tickets that moved into active statuses}

### GitHub Notifications
{Unread notifications grouped by reason, or "No unread GitHub notifications."}

### Meeting Prep: {meeting name}
{Condensed prep output from Step 4, or "No recurring meetings to prep for today."}
```

## Important Implementation Notes

### Read-Only

- Do NOT create, edit, or write any files
- All output is displayed directly to the user
- This is a morning orientation tool, not a note-taking tool

### File References

- Always include `filepath:line_number` references for tasks so the user can navigate to them
- Use relative paths from the vault root when displaying

### Date Handling

- Parse dates in YYYY-MM-DD format (most common in this vault)
- Today's date comes from {{CURRENT_DATE}}
- Calculate day of week from the date to determine meeting prep

### Jira Resilience

- If any Jira API call fails, print a warning like: "Jira API unavailable — showing vault-only data"
- Continue with the rest of the briefing (tasks, meeting prep from vault files)
- Do not abort or retry excessively

### Sentinel File

- After displaying the briefing, touch the sentinel file so the SessionStart hook knows the skill has been run today:
  ```bash
  touch /tmp/claude-start-my-day-$(date +%Y-%m-%d)
  ```

### User Experience

- Keep the briefing scannable — this is a quick morning orientation, not a deep report
- Highlight what needs attention: overdue items, new assignments, upcoming meetings
- If a section has nothing to show, say so briefly rather than padding
- The user can run `/meeting-prep` for deeper meeting preparation or `/triage-tasks` to work through overdue items

## Example Session Flows

### Monday with Planning Meeting

```
User: /start-my-day

1. Detect Monday → ask: planning or refinement?
2. User picks "Planning" → ask: which planning meeting?
3. User picks "Portal planning"
4. Gather tasks due today + overdue summary
5. Fetch Jira: open tickets, new assignments, status changes
6. Fetch GitHub unread notifications
7. Prep portal planning meeting (condensed)
8. Output full briefing
```

### Tuesday

```
User: /smd

1. Detect Tuesday → auto-prep dev meeting
2. Gather tasks due today + overdue summary
3. Fetch Jira activity
4. Fetch GitHub unread notifications
5. Prep dev meeting: standup, wiki agenda, team status, playbook SOP
6. Output full briefing
```

### Wednesday

```
User: /morning

1. Detect Wednesday → no meeting prep
2. Gather tasks due today + overdue summary
3. Fetch Jira activity
4. Fetch GitHub unread notifications
5. "No recurring meetings to prep for today."
6. Output full briefing
```

### Jira Unavailable

```
User: /start-my-day

1. Detect day, determine meeting
2. Gather tasks due today + overdue summary
3. Jira calls fail → "Jira API unavailable — showing vault-only data"
4. Fetch GitHub unread notifications (independent of Jira)
5. Meeting prep using vault files only (no live ticket fetches)
6. Output full briefing with warning
```
