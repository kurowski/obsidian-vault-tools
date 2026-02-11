---
name: meeting-prep
aliases: ["prep"]
description: Prepare for any meeting by gathering context from your Obsidian vault. Resolves meeting name to a file, detects meeting type, summarizes previous notes, finds open action items, and suggests discussion topics. Includes live Jira ticket status for referenced tickets. Can scaffold a new dated section in the meeting file using Obsidian templates.
allowed-tools: Read, Grep, Glob, AskUserQuestion, Bash, Edit
---

# Meeting Prep Workflow

You're helping the user prepare for an upcoming meeting by gathering relevant context from their Obsidian vault.

## Context

Today's date is {{CURRENT_DATE}}. The vault is at /workspace.

The user manages 5 direct reports: Armando, Christina, Helio, Jakob, Shaun.
The user's boss is Thomas.
Peers: Maggie (Magdala, project manager), Que (business analyst).

**External Resources**:

- **ITSE Playbook**: `/workspace/playbook/` - Contains SOPs and best practices. SOPs at `/workspace/playbook/docs/standard-operating-procedures/`, best practices at `/workspace/playbook/docs/fundamentals/`
- **GitHub Wiki**: `/workspace/github-wiki/` - Contains developer meeting agendas and notes named `Developer-Meeting-Agenda-YYYY-MM-DD.md`
- **Jira API**: Jira helper functions available at `/workspace/.claude/jira-helper.sh` for fetching live ticket status

### Jira Integration

Source the Jira helper to fetch live ticket status:

```bash
source /workspace/.claude/jira-helper.sh

# Extract all ticket codes from the meeting file
tickets=$(jira_extract_tickets "dev meeting.md")

# Fetch status for each ticket
jira_get_multiple_tickets "$tickets"
```

**When to use Jira**:
- When Jira tickets (UP-, RWSP2-, WEBP4-, UCDCSISDEV-, UCDCWEB2-, RWR-) are mentioned in meeting notes or action items
- Use jira_extract_tickets to find all ticket codes in the meeting file
- Use jira_get_multiple_tickets to fetch their current status
- Include Jira status in a dedicated "Referenced Tickets" section
- Especially useful for planning, refinement, and dev meetings where tickets are frequently discussed

## Step 1: Resolve Meeting File

The user provides freeform input (e.g., "Christina", "dev meeting", "portal planning"). Resolve it to a meeting file using this priority order:

1. **Exact match**: `{input}.md`
2. **1-on-1 pattern**: `{input} 1on1.md`
3. **Meeting pattern**: `{input} meeting.md`
4. **Planning patterns**: `{input} planning.md`, `{input} planning meeting.md`
5. **Glob fallback**: `*{input}*` (case-insensitive)
6. **Ambiguous**: If multiple matches found, use AskUserQuestion to let the user choose

Use Glob to check each pattern. Stop at the first pattern that finds exactly one match.

**Special case**: If the input is a person's name (e.g., "Christina"), prefer the 1-on-1 file (`Christina 1on1.md`) over other matches.

## Step 2: Detect Meeting Type

Once the file is found, classify it by matching the filename against these patterns:

| Pattern                                                                   | Type            | Identifier                           |
| ------------------------------------------------------------------------- | --------------- | ------------------------------------ |
| `{Name} 1on1.md` where Name is Armando, Christina, Helio, Jakob, or Shaun | `direct-report` | The person's name                    |
| `Thomas 1on1.md`                                                          | `boss`          | Thomas                               |
| `Maggie 1on1.md` or `que 1on1.md`                                         | `peer`          | The person's name                    |
| `dev meeting.md`                                                          | `dev-meeting`   | —                                    |
| `it monthly meeting.md`                                                   | `it-monthly`    | —                                    |
| Filename contains `planning`                                              | `planning`      | Project name extracted from filename |
| `refinement meeting.md`                                                   | `refinement`    | —                                    |
| Everything else                                                           | `general`       | —                                    |

## Step 3: Extract Previous Meeting Content

**Queued notes**: Any content at the top of the file *before* the first `## ` dated heading is considered "queued discussion items" — notes the user jotted down between meetings for the upcoming session. Capture this content separately; it will be surfaced in Step 7 and incorporated by Step 8.

Read the meeting file and find the most recent dated section. Look for heading patterns like:

- `## YYYY-MM-DD`
- `## Month DD, YYYY`
- `## M/D/YYYY` or `## MM/DD/YYYY`
- `## YYYY-MM` (monthly)
- Any heading containing a recognizable date

Extract the content under the most recent dated heading as the "previous meeting summary." Summarize it briefly (3-5 bullet points covering key decisions, action items, and discussion topics).

Also note the date of that section — this becomes the "last meeting date" used in Step 5.

## Step 4: Find Open Tasks

Search the meeting file for incomplete tasks:

- Pattern: `- [ ]` (lines starting with `- [ ]`)
- Exclude completed (`- [x]`) and cancelled (`- [-]`)

Format each task with its file path and line number reference.

Also check for tasks with due dates (`📅 YYYY-MM-DD`) and flag any that are overdue relative to today.

## Step 5: Gather Cross-Vault Context

Search for mentions of the person or project in **other** vault files since the last meeting date.

**For 1-on-1 meetings** (direct-report, boss, peer):

- Grep for the person's name across the vault (excluding the meeting file itself)
- Focus on mentions in: `dev meeting.md`, other 1-on-1 files, project files, and planning files
- Filter to entries dated after the last meeting date when possible

**For dev meetings**:

- Check each direct report's 1-on-1 file for recent entries (since last dev meeting)
- Look for blockers, completed work, and upcoming items
- **GitHub Wiki agenda**: Look for today's agenda at `/workspace/github-wiki/Developer-Meeting-Agenda-YYYY-MM-DD.md`. If not found, find the most recent one by globbing `Developer-Meeting-Agenda-2026-*` and sorting. Surface any pre-populated topics or carryover items from the wiki agenda.
- **Playbook SOP**: Read `/workspace/playbook/docs/standard-operating-procedures/conduct-a-developer-meeting.md` and remind the user of the standard flow

**For planning meetings**:

- Search for the project prefix (UP-, RWSP2-, WEBP4-, UCDCSISDEV-, UCDCWEB2-, RWR-) across the vault
- Find recent decisions, blockers, and status updates
- **Playbook**: Search `/workspace/playbook/docs/` for SOPs relevant to the project or discussion topics (e.g., deploy, release, security)

**For general/other meetings**:

- Search for keywords from the meeting filename across the vault
- Find recent mentions and related tasks
- **Playbook**: Search `/workspace/playbook/docs/` for SOPs matching the meeting topic keywords

## Step 6: Build Suggested Discussion Topics

Synthesize suggestions from what you've gathered:

- **Open tasks** that need follow-up or are overdue
- **Recent mentions** of the person/project in other contexts
- **Unresolved items** from the previous meeting
- **Cross-cutting concerns** (items appearing in multiple files)
- **Overdue items** that need escalation or rescheduling

Limit to 3-7 concrete, actionable topics.

## Step 7: Format and Display Output

**Before formatting output**: Extract any Jira ticket codes (UP-, RWSP2-, WEBP4-, UCDCSISDEV-, UCDCWEB2-, RWR-) mentioned in the meeting file and fetch their current status using the Jira helper.

Output the prep summary in this structure:

```
## Meeting Prep: {meeting name}
**Type**: {detected type}
**File**: {filepath}
**Last entry**: {date of most recent section}

### Queued Discussion Items (if any)
{Content found before the first dated heading — notes the user added between meetings for this session. Display verbatim or lightly formatted.}

### Previous Meeting Summary
{Brief summary of last dated section — 3-5 bullet points}

### Open Action Items
{Incomplete tasks from the meeting file, with file:line references}

### Referenced Tickets (if any Jira tickets found)
{Live status of Jira tickets mentioned in the meeting notes}
{Use jira_ticket_summary for each ticket}

### Context from Other Notes
{Mentions of this person/project in other vault files since last meeting}

### Suggested Discussion Topics
{3-7 derived topics from open tasks, recent mentions, overdue items}
```

### Type-Specific Additions

**For direct report 1-on-1s** (`direct-report` type), add this section after Suggested Discussion Topics:

```
### People / Product / Process Prompts
- **People**: How are things going with the team? Any collaboration challenges?
- **Product**: What's the most important thing you worked on since we last met? Any blockers?
- **Process**: Is there anything slowing you down or that we could improve?
```

**For boss 1-on-1** (`boss` type), add:

```
### Questions to Bring
{Derived from open items, decisions needed, and things requiring Thomas's input}
```

**For dev meetings** (`dev-meeting` type), add:

```
### GitHub Wiki Agenda
{Topics and action items from the wiki agenda for today's meeting, or the most recent agenda if none exists for today. Include the wiki filename for reference.}

### Team Status (from recent 1-on-1s)
{For each direct report, show 2-3 bullet points from their most recent 1-on-1 entry}

### Meeting Flow (from Playbook)
{Key steps from the playbook SOP for conducting a developer meeting}
```

**For planning meetings** (`planning` type), add:

```
### Referenced Tickets
{Extract tickets from the meeting file using jira_extract_tickets}
{Fetch live status using jira_get_multiple_tickets}
{Show ticket code, summary, status, assignee for each}

### Vault References
{Tasks and mentions matching the project prefix from other vault files}

### Risk Items
{Overdue tasks, blocked items, items mentioned as risks}
```

**For IT monthly** (`it-monthly` type), add:

```
### Team Summary for Report
{Recent accomplishments from dev meeting notes and 1-on-1s that could be shared}
```

## Step 8: Offer to Scaffold Meeting Section

After displaying the prep summary, offer to create a new dated section in the meeting file for today's meeting.

### Check for Existing Section

First, check whether the meeting file already has a section for today's date (`## {{CURRENT_DATE}}`). If it does, **skip this step entirely** — do not offer to scaffold.

### Ask the User

Use `AskUserQuestion` to ask:

> Want me to add a new section for today's meeting?

Options: **Yes** / **No**

If the user declines, end the workflow.

### Determine Template

If the user accepts, insert a new section based on the meeting type detected in Step 2:

**1-on-1 types** (`direct-report`, `boss`, `peer`) — use the structure from `templates/1on1.md`:

```markdown
## {{CURRENT_DATE}} — {Person's Name}

### People
-

### Product
-

### Process
-

### Action Items
- [ ]
```

**Dev meeting** (`dev-meeting`) — use the structure from `templates/dev-meeting.md`:

```markdown
## {{CURRENT_DATE}}

### Standup
- did before
	-
- will do next
	-

### Show & Tell
-

### Discussion
-

### Action Items
- [ ]
```

**All other types** (`planning`, `refinement`, `it-monthly`, `general`) — insert a bare heading:

```markdown
## {{CURRENT_DATE}}

```

### Handle Queued Notes

The user may have added loose notes (discussion items, reminders, links) to the top of the file before the first `## ` dated heading, intended for the upcoming meeting. These queued notes must be **absorbed into the new section**, not left stranded above it.

- If there is content before the first `## ` heading, move it into the new section — place it right after the `## ` date heading line (before the template subsections like `### People`).
- This means the `old_string` for the Edit should start from the beginning of the queued content and extend through the first `## ` heading line.

### Insert Location

Insert the new section before the first existing `## ` dated heading. This matches the vault convention of newest-first ordering.

- Use the `Edit` tool. The `old_string` should be the first `## ` heading line in the file (or, if queued notes exist, start from the first line of queued content through that heading). The `new_string` should be the new dated section (with any queued notes folded in) followed by that same original `## ` heading line.
- If the file is empty or has no `## ` headings, append the section at the end of whatever content exists.

### Confirm

After inserting, confirm to the user what was added and where. If queued notes were absorbed, mention that too, e.g.:

> Added a new `## 2026-02-11 — Christina` section with People/Product/Process/Action Items to the top of `Christina 1on1.md`. Your 3 queued discussion items were moved into the new section.

## Important Implementation Notes

### Scaffolding

- The only file modification this skill performs is inserting a new dated section via the `Edit` tool in Step 8
- Only modify the meeting file identified in Step 1 — never create new files or edit other files
- Always ask the user before making any changes
- All other output (the prep summary) is displayed directly to the user

### File References

- Always include `filepath:line_number` references so the user can navigate to sources
- Use relative paths from the vault root when displaying

### Date Handling

- Parse dates in YYYY-MM-DD format (most common in this vault)
- "Since last meeting" means entries dated after the last meeting date found in Step 3
- If no date can be determined, include all recent content (last ~30 days)

### Search Scope

- Search the entire vault but skip `.obsidian/`, `Omnivore/`, `Clippings/`, and `Learning from Dutch/` directories
- Prioritize files that are likely related (same project, same person, meeting files)

### User Experience

- Be concise — this is a prep summary, not a full report
- Highlight what's actionable and what needs attention
- If there are no open tasks or recent mentions, say so briefly rather than padding
- If the meeting file is empty or very short, note that and focus on cross-vault context

## Example Session Flows

### Direct Report 1-on-1

```
User: /meeting-prep Christina

1. Resolve: finds "Christina 1on1.md"
2. Detect: direct-report type
3. Read file, find last dated section
4. Find open tasks in Christina's file
5. Search vault for "Christina" mentions since last meeting
6. Generate prep with People/Product/Process prompts
```

### Dev Meeting

```
User: /prep dev meeting

1. Resolve: finds "dev meeting.md"
2. Detect: dev-meeting type
3. Read file, find last dated section with action items
4. Find open tasks in dev meeting file
5. Check each direct report's 1-on-1 for recent updates
6. Read today's GitHub wiki agenda (Developer-Meeting-Agenda-YYYY-MM-DD.md)
7. Read playbook SOP (conduct-a-developer-meeting.md) for meeting flow
8. Generate prep with wiki agenda, team status, and meeting flow sections
```

### Planning Meeting

```
User: /prep portal planning

1. Resolve: finds "portal planning.md"
2. Detect: planning type, project = "portal" (UP- prefix)
3. Read file, find last dated section
4. Find open tasks in planning file
5. Search vault for UP- ticket references
6. Generate prep with open tickets and risk items sections
```

### Boss 1-on-1

```
User: /prep Thomas

1. Resolve: finds "Thomas 1on1.md"
2. Detect: boss type
3. Read file, find last entry
4. Find open tasks
5. Search for items needing Thomas's input
6. Generate prep with "Questions to Bring" section
```

## References

- <https://justoffbyone.com/posts/how-to-run-11s/>
