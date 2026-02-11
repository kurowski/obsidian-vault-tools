---
name: weekly-review
aliases: ["wr"]
description: Generate a weekly summary of task changes and accomplishments. Shows completed, cancelled, newly overdue, and upcoming tasks, plus a narrative accomplishments section for self-reporting. Read-only — no files are created or modified.
allowed-tools: Read, Grep, Glob, AskUserQuestion
---

# Weekly Review Workflow

You're helping the user generate a weekly summary of their task activity and accomplishments from their Obsidian vault. This is a **read-only** skill — do not create or modify any files.

## Context

Today's date is {{CURRENT_DATE}}. The vault is at /workspace.

The user manages 5 direct reports: Armando, Christina, Helio, Jakob, Shaun.
The user's boss is Thomas.
Peers: Maggie (Magdala, project manager), Que (business analyst).

### Search Scope

Search the entire vault but **skip** these directories:
- `.obsidian/`
- `Omnivore/`
- `Clippings/`
- `Learning from Dutch/`

## Step 1: Determine Review Period

The user may provide an optional date argument:

- **No argument**: Review period is the past 7 days (today minus 6 days through today)
- **Date argument** (e.g., `2026-02-03`): Review period is 7 days starting from that date
- **`last week`**: Previous Monday through Sunday

Calculate the start date and end date. Also calculate the "coming due" window: the 7 days immediately after the end date.

## Step 2: Find Completed Tasks

Search for tasks completed during the review period:

- Grep for the `✅` pattern across all `.md` files
- Filter to completion dates that fall within the review period (✅ YYYY-MM-DD where date is in range)
- Group results by source file
- Include `filepath:line_number` references

Note: Some tasks may have been completed in bulk (e.g., during a triage session). This is fine — include them all, but note the grouping in the output if many share the same completion date.

## Step 3: Find Cancelled Tasks

Search for tasks cancelled during the review period:

- Grep for `- [-]` lines that also contain `❌ YYYY-MM-DD` where the date falls in the review period
- Include `filepath:line_number` references

Note: Not all cancelled tasks have ❌ dates. Only include those with dates in the review period. Tasks cancelled without dates cannot be attributed to a specific period.

## Step 4: Find Newly Overdue Tasks

Find incomplete tasks that became overdue during the review period:

- Grep for incomplete tasks: `- [ ]` lines containing `📅 YYYY-MM-DD`
- Filter to tasks where the due date falls within the review period (meaning they became overdue during this period)
- These are tasks that should have been done this week but weren't
- Include `filepath:line_number` references and flag how many days overdue

## Step 5: Find Coming Due Tasks

Find incomplete tasks due in the next 7 days after the review period:

- Grep for incomplete tasks: `- [ ]` lines containing `📅 YYYY-MM-DD`
- Filter to tasks where the due date falls in the 7 days after the review period end date
- Include `filepath:line_number` references

## Step 6: Compute Stats

Count totals for the summary:

- **Completed**: Number of tasks completed in review period
- **Cancelled**: Number of tasks cancelled in review period
- **Newly overdue**: Number of tasks that became overdue in review period
- **Coming due**: Number of tasks due in next 7 days
- **Total open with due dates**: All incomplete tasks with 📅 dates (vault-wide)
- **Total open without due dates**: All incomplete tasks without 📅 dates (vault-wide)

## Step 7: Gather Accomplishments Context

Go beyond task checkboxes to find what was actually worked on during the review period:

### Dev Meeting Standup
- Read `dev meeting.md` — look for the standup section at the top of the file (the "did before" items)
- These represent recent work that may not be captured as formal tasks

### Meeting Notes
- Search for dated section headings (`## YYYY-MM-DD` or similar patterns) across key files that fall within the review period:
  - `dev meeting.md`
  - `refinement meeting.md`
  - `portal planning.md`
  - `ucdc planning meeting.md`
  - All `*1on1.md` files
  - Any other meeting files with entries in the period
- Extract key discussion points, decisions, and outcomes from those sections

### Cross-Reference with accomplishments.md
- Read `accomplishments.md` to understand what has already been reported
- Avoid suggesting items that are already listed there

## Step 8: Synthesize Accomplishments

Transform the raw data into a narrative accomplishments section:

- **Rewrite completed tasks as accomplishments**: Don't just list raw task text. Reword into past-tense achievement statements.
  - Raw: `- [x] submit UP-1767 to core` → Accomplishment: "Submitted UP-1767 patch to Drupal core"
  - Raw: `- [x] reciprocity refactor deployment plan` → Accomplishment: "Completed deployment plan for Reciprocity refactor"
- **Group by project/theme** where possible:
  - Portal (UP-) work
  - Reciprocity (RWSP2-) work
  - Website (WEBP4-) work
  - Infrastructure / DevOps
  - Team management / Process improvements
  - Other
- **Include meeting outcomes**: Decisions made, plans finalized, issues resolved
- **Skip meta-tasks**: Vault management, personal tooling setup (unless significant enough to report)
- **Keep it concise**: 5-15 bullet points, each 1-2 sentences

## Step 9: Format and Display

Output the review in this structure:

```
## Weekly Review: {start date} to {end date}

### Task Summary

**Completed ({N})**:
{Tasks grouped by file, with filepath:line references}

**Cancelled ({N})**:
{Cancelled tasks with filepath:line references, or "None" if empty}

**Newly Overdue ({N})**:
{Overdue tasks with days overdue and filepath:line references, or "None"}

**Coming Due Next Week ({N})**:
{Tasks due in next 7 days with filepath:line references, or "None"}

### Stats
- Completed: N | Cancelled: N | Newly overdue: N | Coming due: N
- Total open (with dates): N | Total open (no dates): N

### Accomplishments
{Narrative bullet points grouped by project/theme}
{Ready to paste into accomplishments.md or self-report}
```

## Important Implementation Notes

### Read-Only
- Do NOT create, edit, or write any files
- All output is displayed directly to the user
- If the user wants to add items to `accomplishments.md`, they can do that separately

### File References
- Always include `filepath:line_number` references in the Task Summary section
- Use relative paths from the vault root
- The Accomplishments section should be clean narrative (no file refs) since it's meant for self-reporting

### Date Handling
- Parse dates in YYYY-MM-DD format (most common in this vault)
- Handle both `✅ YYYY-MM-DD` (completion) and `❌ YYYY-MM-DD` (cancellation) date formats
- Handle `📅 YYYY-MM-DD` (due date) format
- If a date can't be parsed, skip that task and note it

### Edge Cases
- **No completed tasks**: Say "No tasks were completed this week" — don't pad
- **Bulk completions**: If many tasks were completed on the same date (e.g., during a triage session), note this pattern
- **Empty review period**: If nothing happened, say so briefly and suggest checking a different date range

### User Experience
- The Task Summary section is for the user's own tracking
- The Accomplishments section should be polished enough to share with a manager or paste into a self-evaluation
- Tone for accomplishments: professional, concise, action-oriented
- Don't include tasks that are clearly personal or vault-management unless the user's role involves tooling

## Example Session Flows

### Default Review
```
User: /weekly-review

1. Period: 2026-02-03 to 2026-02-09
2. Find completed tasks in that range
3. Find cancelled tasks in that range
4. Find tasks that became overdue in that range
5. Find tasks due 2026-02-10 to 2026-02-16
6. Read dev meeting standup, meeting notes in range
7. Synthesize accomplishments
8. Output formatted review
```

### Specific Week
```
User: /wr 2026-01-27

1. Period: 2026-01-27 to 2026-02-02
2. Same workflow as above, scoped to that week
```

### Review for Self-Report
```
User: /weekly-review
(User then copies the Accomplishments section into their self-report or accomplishments.md)
```
