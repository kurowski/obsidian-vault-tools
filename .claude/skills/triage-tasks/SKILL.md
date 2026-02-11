---
name: triage-tasks
aliases: ["triage"]
description: Systematically work through overdue tasks in your Obsidian vault. Groups incomplete tasks by age (ancient, very overdue, recently overdue) and interactively helps you complete, cancel, reschedule, or gather context on each task.
allowed-tools: Bash, Read, Edit, Glob, Grep, AskUserQuestion
---

# Task Triage Workflow

You're helping the user process overdue tasks in their Obsidian vault. Your goal is to systematically work through incomplete tasks and make progress.

## Context

Today's date is {{CURRENT_DATE}}. The vault is at /workspace.

## Step 1: Gather all overdue tasks

Find all incomplete tasks with due dates using Obsidian task syntax:
- Incomplete: `- [ ]` (not `- [x]` or `- [-]`)
- With due dates: matching `📅 YYYY-MM-DD`

Use Grep to search for the pattern: `^- \[ \].*📅`

## Step 2: Categorize by age

Group tasks into categories based on how overdue they are:

- **Ancient** (>= 180 days overdue) - 6+ months old, likely stale
- **Very Overdue** (90-179 days overdue) - 3-6 months old
- **Overdue** (30-89 days overdue) - 1-3 months old
- **Recently Overdue** (1-29 days overdue) - Fresh, likely still relevant
- **Due Soon/Future** (0 or negative days) - Not overdue yet

## Step 3: Interactive triage session

Start with the oldest category that has tasks. For each task, present it clearly:

```
📌 {CATEGORY}: {task description}
   File: {filepath}:{line_number}
   Overdue by: {N} days
   Original due date: {date}
```

Then ask the user what to do using short, efficient questions. Common actions:
- **Mark complete (done)**: Change `- [ ]` to `- [x]` and add completion timestamp ` ✅ YYYY-MM-DD`
- **Cancel**: Change `- [ ]` to `- [-]` (cancelled marker)
- **Reschedule**: Update the `📅 YYYY-MM-DD` to a new date
- **Show context**: Read and display surrounding lines from the file
- **Skip**: Move to next task

Use AskUserQuestion when the action isn't clear from their response.

## Step 4: Batch operations

When appropriate, ask if the user wants to perform batch operations:
- "Mark all remaining ancient tasks as cancelled?"
- "Show me context for all of these first?"

## Step 5: Progress tracking

Keep track during the session:
- Tasks completed: N
- Tasks cancelled: N
- Tasks rescheduled: N
- Tasks remaining: N

Show progress periodically and at the end.

## Important Implementation Notes

### Task Syntax
- Complete: `- [x] Task text 📅 YYYY-MM-DD ✅ YYYY-MM-DD`
- Cancelled: `- [-] Task text 📅 YYYY-MM-DD`
- Incomplete: `- [ ] Task text 📅 YYYY-MM-DD`

### File Editing
- Always Read a file before editing it
- Preserve exact spacing and formatting
- Only modify the specific task line

### Date Calculation
- Parse dates in format YYYY-MM-DD
- Calculate days overdue from today's date
- Handle invalid dates gracefully

### User Experience
- Be efficient and conversational
- Don't overwhelm with too many tasks at once
- Offer to take breaks between categories
- This is about reducing cognitive load, not judgment

## Example Session Flow

1. Find and categorize all overdue tasks
2. Report: "Found 45 overdue tasks: 12 ancient, 20 very overdue, 10 overdue, 3 recently overdue"
3. Start with ancient: "Let's start with the 12 ancient tasks (6+ months old). These are most likely stale."
4. Process each task interactively
5. After category: "Ancient tasks done! 5 completed, 4 cancelled, 3 rescheduled. Move to very overdue tasks?"
6. Continue through categories
7. Final summary

## Tips

- Group similar tasks (e.g., all from same file) to provide context
- Suggest bulk actions when patterns emerge
- Read file context only when requested to keep flow efficient
- Celebrate progress - this is productive work!
