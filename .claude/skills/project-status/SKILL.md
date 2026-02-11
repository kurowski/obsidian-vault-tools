---
name: project-status
aliases: ["ps"]
description: Get consolidated status of a project or Jira ticket by searching across all vault notes. Shows timeline, open tasks, related tickets, and blockers. Includes live Jira ticket status. Read-only — no files are created or modified.
allowed-tools: Read, Grep, Glob, AskUserQuestion, Bash
---

# Project Status Workflow

You're helping the user get a consolidated status view for a specific Jira ticket or an entire project by searching across their Obsidian vault. This is a **read-only** skill — do not create or modify any files.

## Context

Today's date is {{CURRENT_DATE}}. The vault is at /workspace.

### Project Prefix Table

| Input (case-insensitive) | Prefix | Project Name |
|--------------------------|--------|--------------|
| `portal`, `myeap`, `m2` | `UP-` | Portal (UCEAP SIS) |
| `reciprocity`, `recip`, `rwsp2` | `RWSP2-` | Reciprocity Portal |
| `website`, `web`, `webp4` | `WEBP4-` | UCEAP Website |
| `ucdc`, `ucdcsis`, `ucdcsisdev` | `UCDCSISDEV-` | UCDC SIS |
| `ucdcweb`, `ucdcweb2` | `UCDCWEB2-` | UCDC Website |
| `research`, `rwr` | `RWR-` | Research Website |

### Search Scope

Search the entire vault but **skip** these directories:
- `.obsidian/`
- `Omnivore/`
- `Clippings/`
- `Learning from Dutch/`

### Jira Integration

**Jira helper functions** are available at `/workspace/.claude/jira-helper.sh`. Source this file to access:

```bash
source /workspace/.claude/jira-helper.sh

# Fetch a single ticket's details (JSON)
jira_get_ticket "UP-684"

# Get one-line summary
jira_ticket_summary "UP-684"

# Fetch multiple tickets (space-separated)
jira_get_multiple_tickets "UP-684 RWSP2-828 RWR-72"

# Extract ticket codes from a file
jira_extract_tickets "dev meeting.md"

# Extract and fetch status for all tickets in a file
jira_tickets_in_file "portal planning.md"
```

**When to use Jira**:
- In **Ticket Mode**: Always fetch live Jira status for the specific ticket using jira_get_ticket
- In **Project Mode**: Extract related tickets from vault files and fetch their status
- Include Jira data in a dedicated section of the output to show real-time status
- Cross-reference vault mentions with Jira status to identify stale references

## Step 1: Parse Input

Determine whether the user is asking about a **specific ticket** or a **whole project**.

**Ticket mode**: The input contains a hyphen followed by digits (e.g., `UP-684`, `RWSP2-708`). Extract the ticket code. Also determine the project prefix from the ticket code (e.g., `UP-684` → prefix `UP-`, project "Portal").

**Project mode**: The input is a project name or alias. Map it to a prefix using the table above (case-insensitive matching).

**Ambiguous**: If the input doesn't clearly match either mode, use AskUserQuestion to clarify. Present the project prefix table as options.

## Step 2: Find Dedicated Files

Search for files specifically about this ticket or project:

**Ticket mode**:
- Glob for `*{TICKET-CODE}*` (case-insensitive, e.g., `*UP-684*`, `*up-684*`)
- These are dedicated ticket files like `UP-684 queue.md`, `RWSP2-708.md`

**Project mode**:
- Glob for files containing the project name or prefix (e.g., `*portal*`, `*reciprocity*`)
- Include planning files: `*{project} planning*`
- These are key project files to read for high-level context

List all dedicated files found — these will be read in later steps for deeper context.

## Step 3: Search Vault for References

Use case-insensitive Grep across all `.md` files to find mentions:

**Ticket mode**: Search for the exact ticket code (e.g., `UP-684`). Use `-i` flag for case-insensitive matching.

**Project mode**: Search for the project prefix pattern (e.g., `UP-\d+` to find all UP- tickets). Collect all unique ticket codes found.

For each file with matches, note:
- The file path
- Line numbers of matches
- The matched content (use context lines to capture surrounding text)

**Key files to pay special attention to** (highest density of ticket references):
- `dev meeting.md`
- `refinement meeting.md`
- `portal planning.md`, `ucdc planning meeting.md`
- `Thomas 1on1.md`
- 1-on-1 files (Armando, Christina, Helio, Jakob, Shaun)
- Dedicated ticket files found in Step 2

## Step 4: Extract Timeline

For each file containing references, identify the **dated section** that contains each mention. Look for heading patterns like:
- `## YYYY-MM-DD`
- `## Month DD, YYYY`
- `## M/D/YYYY` or `## MM/DD/YYYY`
- `### YYYY-MM-DD`
- Any heading containing a recognizable date

Build a chronological list of mentions:
- Date of the section
- Source file and line number
- Brief excerpt or summary of what was said about the ticket/project in that section

Sort by date, most recent first.

## Step 5: Find Related Tasks

Search for task lines that reference the ticket code or project prefix:

- Incomplete tasks: Grep for `- \[ \]` lines containing the ticket code or prefix
- Completed tasks: Grep for `- \[x\]` lines containing the ticket code or prefix
- Cancelled tasks: Grep for `- \[-\]` lines containing the ticket code or prefix

For each task found:
- Include the full task text
- Include `filepath:line_number` reference
- Check for due dates (`📅 YYYY-MM-DD`) and flag overdue items
- Check for completion dates (`✅ YYYY-MM-DD`)

## Step 6: Identify Relationships

In the contexts where the ticket/prefix appears, look for:

- **Other ticket codes nearby** (within the same section or within 5 lines): These are potentially related tickets
- **Dependency language**: "depends on", "blocks", "blocked by", "related to", "see also", "close", "prerequisite", "after"
- **Status language**: "on hold", "blocked", "waiting", "deferred", "in progress", "done", "complete", "deployed", "released"
- **Risk language**: "risk", "concern", "issue", "problem", "escalat", "urgent", "critical"

Build a list of related tickets and note the nature of the relationship where identifiable.

## Step 7: Synthesize and Format Output

### Ticket Mode Output

```
## Project Status: {TICKET-CODE}
**Project**: {project name}
**Dedicated file**: {path if exists, or "None"}

### Live Jira Status
{Current status from Jira API: summary, status, assignee, priority, last updated}
{Use jira_get_ticket to fetch this}

### Vault Mentions Timeline
{Chronological list of mentions across vault files, most recent first}
{Each entry: date — filepath:line — brief excerpt}

### Related Tasks
**Open**:
{Incomplete tasks mentioning this ticket, with filepath:line refs and due dates}

**Completed**:
{Completed tasks, with completion dates}

### Related Tickets
{Other ticket codes mentioned in the same contexts, with relationship notes}
{Include Jira status for each related ticket using jira_ticket_summary}

### Summary
{Brief synthesis: what this ticket is about based on vault content, current apparent state, any blockers or open questions}
{Compare vault mentions with Jira status to identify any discrepancies}
```

### Project Mode Output

```
## Project Status: {Project Name} ({PREFIX})
**Ticket prefix**: {PREFIX}
**Key files**: {list of dedicated project files found}

### Active Tickets (from Vault)
{Tickets referenced in recent vault entries (last ~60 days), grouped by source file}
{Include filepath:line references}

**Live Jira Status** (for tickets above):
{Use jira_get_multiple_tickets with the list of found tickets}
{Cross-reference to identify vault mentions that are now Done/Closed in Jira}

### Open Tasks
{Incomplete tasks across vault that reference this project prefix}
{Include filepath:line references, flag overdue items}

### Recent Activity
{Summary of most recent dated entries from planning, refinement, and dev meeting files}
{Focus on last ~30 days of entries}

### Blockers & Risks
{Items flagged as blocked, on hold, overdue, or containing risk-related language}

### Project Timeline
{Key decisions and milestones extracted from dated entries, most recent first}
{Include filepath:line references for each entry}
```

## Important Implementation Notes

### Read-Only
- Do NOT create, edit, or write any files
- All output is displayed directly to the user
- This is a context-gathering and synthesis tool

### File References
- Always include `filepath:line_number` references so the user can navigate to sources
- Use relative paths from the vault root when displaying (e.g., `dev meeting.md:142` not `/workspace/dev meeting.md:142`)

### Case-Insensitive Matching
- Ticket codes should be matched case-insensitively (UP-684, up-684, Up-684 all match)
- Project name aliases are case-insensitive

### Date Handling
- Parse dates in YYYY-MM-DD format (most common in this vault)
- "Recent" means within the last ~60 days for active tickets, ~30 days for activity summaries
- If no date can be determined for a section, include it but note "undated"

### Efficiency
- Read dedicated ticket/project files in full — they contain the richest context
- For large files like `dev meeting.md`, use Grep to find relevant sections first, then Read specific line ranges rather than the entire file
- In project mode, don't attempt to read every file that mentions the prefix — focus on the most relevant: dedicated files, planning files, meeting files with recent entries

### User Experience
- Be concise but thorough — the goal is a consolidated view that saves the user from manual searching
- If no mentions are found, say so clearly rather than padding
- If the ticket/project has very little vault presence, note that and suggest the user may want to check Jira directly
- Highlight what's actionable: open tasks, blockers, overdue items

## Example Session Flows

### Specific Ticket
```
User: /project-status UP-684

1. Parse: ticket mode, code = "UP-684", prefix = "UP-", project = "Portal"
2. Glob: find "UP-684 queue.md" as dedicated file
3. Read dedicated file for full context
4. Grep vault for "UP-684" (case-insensitive)
5. Find mentions in dev meeting.md, refinement meeting.md, portal planning.md
6. Extract dated sections containing mentions
7. Find tasks referencing UP-684
8. Look for related tickets in same sections
9. Output: timeline of decisions, open tasks, related tickets, synthesis
```

### Whole Project
```
User: /ps portal

1. Parse: project mode, input "portal" → prefix "UP-", project "Portal"
2. Glob: find portal planning.md, portal-related files
3. Grep vault for "UP-\d+" pattern to find all Portal tickets
4. Collect unique ticket codes, note which files reference them
5. Find all open tasks with UP- prefix
6. Read recent sections of planning and dev meeting files
7. Identify blockers and risks
8. Output: active tickets, open tasks, recent activity, blockers, timeline
```

### Ambiguous Input
```
User: /project-status mobile

1. Parse: "mobile" doesn't match any prefix or ticket pattern
2. AskUserQuestion: "I couldn't match 'mobile' to a known project. Which project are you asking about?"
   Options: Portal, Reciprocity, UCEAP Website, UCDC SIS, UCDC Website, Research Website
3. User selects or provides clarification
4. Continue with resolved project
```
