---
name: monthly-report
aliases: ["mr", "monthly"]
description: Generate a monthly executive summary covering Jira, GitHub, calendar, dev meetings, and vault activity. Writes a report file to the vault.
allowed-tools: Read, Grep, Glob, Bash, Write, AskUserQuestion
---

# Monthly Executive Summary Workflow

You're helping the user generate a monthly executive summary for their skip-level boss. The report should demonstrate the breadth and volume of work the team handles across all projects, infrastructure, meetings, compliance, and process.

## Context

Today's date is {{CURRENT_DATE}}. The vault is at /workspace.

The user manages 5 direct reports: Armando, Christina, Helio, Jakob, Shaun.
The user's boss is Thomas.
Peers: Maggie (Magdala, project manager), Que (business analyst).

**Projects tracked** (6 Drupal-based web projects):

| Jira Prefix | Repo Slug | Friendly Name |
|-------------|-----------|---------------|
| UP- | myeap2 | Portal |
| RWSP2- | uceap-reciprocity | Reciprocity |
| WEBP4- | uceap-website | Website |
| UCDCSISDEV- | ucdcsis2 | UCDC SIS |
| UCDCWEB2- | ucdcweb2 | UCDC Website |
| RWR- | research | Research |

**External Resources**:

- **Jira API**: `/workspace/.claude/jira-helper.sh`
- **GitHub API**: `/workspace/.claude/github-helper.sh`
- **Microsoft Graph API**: `/workspace/.claude/msgraph-helper.sh`
- **GitHub Wiki**: `/workspace/github-wiki/` — Developer meeting agendas
- **ITSE Playbook**: `/workspace/playbook/`

### Search Scope

Search the entire vault but **skip** these directories:
- `.obsidian/`
- `Omnivore/`
- `Clippings/`
- `Learning from Dutch/`

## Step 0: Determine Report Period

- Default: previous calendar month relative to {{CURRENT_DATE}}
  - e.g., if today is 2026-02-17, report covers January 2026 (2026-01-01 to 2026-01-31)
- The user may pass an optional `YYYY-MM` argument to override (e.g., `/monthly-report 2025-12`)
- Calculate and store:
  - `START_DATE` (first day of month, YYYY-MM-DD)
  - `END_DATE` (last day of month, YYYY-MM-DD)
  - `MONTH_LABEL` (e.g., "January 2026")

```bash
# Example for default (previous month):
REPORT_MONTH=$(date -d "{{CURRENT_DATE}} -1 month" +%Y-%m)
START_DATE="${REPORT_MONTH}-01"
END_DATE=$(date -d "${START_DATE} +1 month -1 day" +%Y-%m-%d)
MONTH_LABEL=$(date -d "${START_DATE}" +"%B %Y")
```

## Step 1: Pull Latest External Repos

Pull the latest changes for the cloned repos so the report uses up-to-date content. Run both pulls in parallel. If either pull fails, print a warning and continue.

```bash
git -C /workspace/github-wiki pull
git -C /workspace/playbook pull
```

## Step 2: Gather Jira Data

Source the Jira helper and query for activity in the report period.

```bash
source /workspace/.claude/jira-helper.sh
```

### Queries

Run three JQL queries covering all 6 projects:

1. **Tickets resolved** in the period:
   ```
   project in (UP, RWSP2, WEBP4, UCDCSISDEV, UCDCWEB2, RWR)
   AND statusCategory = Done
   AND status CHANGED TO Done DURING ("START_DATE", "END_DATE")
   ORDER BY project, updated DESC
   ```

2. **Tickets created** in the period:
   ```
   project in (UP, RWSP2, WEBP4, UCDCSISDEV, UCDCWEB2, RWR)
   AND created >= "START_DATE" AND created <= "END_DATE"
   ORDER BY project, created DESC
   ```

3. **Tickets updated** (active work) in the period:
   ```
   project in (UP, RWSP2, WEBP4, UCDCSISDEV, UCDCWEB2, RWR)
   AND updated >= "START_DATE" AND updated <= "END_DATE"
   ORDER BY project, updated DESC
   ```

Use `jira_search_jql` for each query with `maxResults=100`.

### Processing

- Group results by project (using the Jira prefix)
- Compute counts: resolved, created, updated per project
- Identify key tickets (high priority, significant work, notable completions)
- Store all ticket detail for Appendix A

### Resilience

If Jira API calls fail (missing credentials, network issues), print a warning and continue. Note the unavailability in the final report.

## Step 3: Gather GitHub Data

Source the GitHub helper.

```bash
source /workspace/.claude/github-helper.sh
gh_check_auth || echo "GitHub unavailable — skipping"
```

### Queries

Run three org-wide searches:

1. `gh_search_prs_merged "$START_DATE" "$END_DATE"` — merged PRs
2. `gh_search_prs_opened "$START_DATE" "$END_DATE"` — opened PRs
3. `gh_search_issues_closed "$START_DATE" "$END_DATE"` — closed issues

### Processing

- Group results by repository, using `gh_repo_friendly_name` for display
- Compute counts: PRs merged, PRs opened, issues closed per repo
- Store all detail for Appendix B

### Resilience

If `gh` CLI is not authenticated or calls fail, print a warning and continue.

## Step 4: Gather Calendar Data

Source the Microsoft Graph helper and attempt to fetch calendar events.

```bash
source /workspace/.claude/msgraph-helper.sh
```

### Check Availability

```bash
if msgraph_check_env; then
    # Proceed with calendar data
else
    echo "Microsoft Graph not configured — skipping calendar data"
fi
```

### Queries

If available:

1. `msgraph_calendar_view "$START_DATE" "$END_DATE"` — all events in the month

### Processing

- Filter out cancelled events (`isCancelled: true`)
- Categorize events:
  - **1-on-1s**: Subject contains a direct report name + "1on1" or "1:1"
  - **Dev meetings**: Subject contains "dev meeting" or "developer meeting"
  - **Planning**: Subject contains "planning"
  - **Refinement**: Subject contains "refinement"
  - **IT monthly**: Subject contains "IT monthly" or "IT departmental"
  - **Other recurring**: Events that appear multiple times in the month
  - **One-off**: Events that appear only once
- Compute total meeting count and total hours (from start/end times)
- For events with OneDrive/SharePoint links in the body, attempt to download and convert `.docx` attachments:
  ```bash
  msgraph_download_file "$file_url" "/tmp/meeting-doc.docx"
  msgraph_docx_to_text "/tmp/meeting-doc.docx"
  ```
- Store all detail for Appendix C

### Resilience

If Microsoft Graph is not configured or calls fail, skip this section entirely. The report will note that calendar data was unavailable.

## Step 5: Gather GitHub Wiki Data

Search for developer meeting agendas in the report period.

```bash
# Glob for agendas in the date range
# Files are named Developer-Meeting-Agenda-YYYY-MM-DD.md
```

Use Glob to find files matching `Developer-Meeting-Agenda-YYYY-MM-*.md` in `/workspace/github-wiki/`, then filter to those whose dates fall within `START_DATE` to `END_DATE`.

### Processing

- Read each matching agenda file
- Extract key discussion topics, decisions, and action items from each
- Store summaries for the Developer Meetings section and full content for Appendix D

## Step 6: Gather Vault Data

Search the vault for activity in the report period.

### Completed Tasks

Grep for lines containing `✅` with dates in the report period across all `.md` files (excluding skip directories).

```
Pattern: ✅ YYYY-MM-DD (where the date falls within START_DATE to END_DATE)
```

- Count total completed tasks
- Group by source file (which indicates project/context)

### Meeting Notes

Search for dated sections in key meeting files that fall within the report period:

- `dev meeting.md` — extract section headings and key points
- `refinement meeting.md`
- `portal planning.md`, `ucdc planning meeting.md`, `unified planning.md`, `website reciprocity planning.md`
- `it monthly meeting.md`
- 1-on-1 files for each direct report

Look for `## YYYY-MM-DD` headings where the date is within the report period.

### Accomplishments

Check `accomplishments.md` for entries in the report period. These are pre-written accomplishment notes the user has captured throughout the month.

### Grouping

Group vault findings by theme:
- **Project Delivery**: Ticket work, releases, deployments
- **Infrastructure & Operations**: Server work, CI/CD, monitoring, hosting
- **Team Management**: 1-on-1 themes, hiring, onboarding/offboarding, reviews
- **Process Improvement**: Playbook updates, workflow changes, documentation
- **Compliance & Security**: GDPR/CCPA/FERPA requests, security advisories, audits
- **Testing & QA**: Automated testing, manual testing, regression, accessibility

## Step 7: Synthesize and Write Report

Combine all gathered data into a single report file.

**Output file**: `/workspace/monthly report YYYY-MM.md` (e.g., `monthly report 2026-01.md`)

### Report Structure

Write the following markdown structure:

```markdown
# Monthly Report: {MONTH_LABEL}

**Period**: {START_DATE} to {END_DATE}
**Prepared**: {{CURRENT_DATE}}

## Executive Summary

{2-3 paragraphs written for a skip-level audience. Focus on:
- Key deliverables shipped and outcomes achieved
- Team highlights and notable contributions
- Strategic work (infrastructure, compliance, process improvements)
- Challenges overcome or risks mitigated

Tone: professional, concise, demonstrating impact. Avoid jargon.
Use specific numbers where available (X tickets resolved, Y PRs merged, etc.)}

## Key Accomplishments

{8-15 bullets grouped by theme. Each bullet should be concrete and outcome-oriented.}

### Project Delivery
- {Specific deliverables, features shipped, bugs fixed by project}

### Infrastructure & Operations
- {Server work, CI/CD improvements, hosting changes, monitoring}

### Team Management
- {1-on-1 themes, skill development, onboarding, reviews}

### Process Improvement
- {Documentation, workflow changes, playbook updates}

### Compliance & Security
- {Data requests handled, security advisories addressed, audits}

### Testing & QA
- {Test coverage, QA cycles, accessibility work}

## Activity by Project

{For each of the 6 projects that had activity, show a subsection:}

### {Project Friendly Name} ({Jira Prefix})

| Metric | Count |
|--------|-------|
| Tickets resolved | X |
| Tickets created | X |
| PRs merged | X |
| PRs opened | X |

**Key items**: {2-5 notable tickets or PRs}

## Meetings & Collaboration

**Total meetings**: {count} ({total hours} hours)

| Category | Count |
|----------|-------|
| 1-on-1s | X |
| Dev meetings | X |
| Planning meetings | X |
| Refinement meetings | X |
| IT monthly | X |
| Other recurring | X |
| One-off meetings | X |

**Notable one-off meetings**: {List any non-recurring meetings with brief context}

## Developer Meetings

{Summary of bi-weekly developer meeting topics and decisions from wiki agendas}

{For each dev meeting in the period:}
### {date}
- {Key topics discussed}
- {Decisions made}
- {Action items assigned}

## Tasks Completed

**Total tasks completed**: {count}

{Grouped summary by source/context — e.g., "12 portal tasks, 5 infrastructure tasks, 3 process tasks"}

---

## Appendix A: Jira Detail

{Full ticket lists grouped by project}

### {Project Name}

#### Resolved
| Key | Summary | Assignee |
|-----|---------|----------|
| {key} | {summary} | {assignee} |

#### Created
| Key | Summary | Status | Assignee |
|-----|---------|--------|----------|
| {key} | {summary} | {status} | {assignee} |

## Appendix B: GitHub Detail

{Full PR and issue lists grouped by repo}

### {Repo Friendly Name}

#### Merged PRs
| # | Title | Author | Merged |
|---|-------|--------|--------|
| {number} | {title} | {author} | {date} |

#### Closed Issues
| # | Title | Closed |
|---|-------|--------|
| {number} | {title} | {date} |

## Appendix C: Calendar Detail

{Full meeting list categorized by type — only if calendar data was available}

### Recurring Meetings
| Meeting | Occurrences | Total Hours |
|---------|-------------|-------------|
| {subject} | {count} | {hours} |

### One-Off Meetings
| Date | Meeting | Duration |
|------|---------|----------|
| {date} | {subject} | {duration} |

## Appendix D: Developer Meeting Summaries

{Per-meeting summaries from wiki agendas}

### {date} — Developer Meeting
{Full summary of agenda topics, discussions, and outcomes}
```

### Writing Guidelines

- **Executive Summary**: Write this last, after all data is gathered. Synthesize the most impactful items. A skip-level reader should understand team value from this section alone.
- **Key Accomplishments**: Be specific. "Resolved 15 Portal tickets including critical SSO bug" is better than "Worked on Portal tickets."
- **Activity by Project**: Only include projects that had activity. Skip projects with zero activity.
- **Meetings**: If calendar data unavailable, note this and skip the detailed counts. Still include dev meeting summaries from wiki data.
- **Appendices**: Include all raw data so the user can reference specifics. These are for the user's benefit, not necessarily shared with the skip-level.

## Step 8: Confirm

After writing the report file:

1. Display the file path
2. Show high-level stats:
   - Total tickets resolved / created
   - Total PRs merged
   - Total meetings (if available)
   - Total tasks completed
   - Dev meetings summarized
3. Note any data sources that were unavailable:
   - "Jira data: available / unavailable"
   - "GitHub data: available / unavailable"
   - "Calendar data: available / unavailable (Microsoft Graph not configured)"

Suggest the user review the Executive Summary and Key Accomplishments sections, as those are the most impactful for the skip-level audience and may benefit from personal edits.

## Important Implementation Notes

### Data Source Priority

The skill should produce a useful report even if some data sources are unavailable. Priority order:
1. **Vault data** (always available) — tasks, meeting notes, accomplishments
2. **GitHub Wiki** (always available) — dev meeting agendas
3. **Jira API** (usually available) — ticket activity
4. **GitHub API** (usually available) — PR and issue activity
5. **Microsoft Graph** (optional) — calendar data

### Parallelism

Steps 2, 3, 4, 5, and 6 are independent and can run in parallel where tooling allows.

### Date Handling

- All dates in YYYY-MM-DD format
- Use bash `date` command for date arithmetic
- The report period is always a full calendar month (1st to last day)

### File Output

- Write to `/workspace/monthly report YYYY-MM.md`
- If the file already exists, use AskUserQuestion to confirm overwrite
- The file is a vault note — it will appear in Obsidian

### Deduplication

- Tickets may appear in both "resolved" and "updated" Jira queries — deduplicate
- PRs may appear in both "merged" and "opened" GitHub queries — deduplicate
- Tasks completed may overlap with Jira tickets — note the connection but don't double-count

### Tone

The report is for a skip-level audience (Thomas's boss). Write professionally:
- Lead with outcomes and impact, not process
- Use specific numbers
- Avoid internal jargon without context
- Highlight team contributions, not just the manager's work

## Example Session Flow

```
User: /monthly-report

1. Determine report period: January 2026 (2026-01-01 to 2026-01-31)
2. Pull latest wiki and playbook repos
3. Query Jira: resolved/created/updated tickets across 6 projects
4. Query GitHub: merged PRs, opened PRs, closed issues
5. Query Microsoft Graph: calendar events (or skip if not configured)
6. Read GitHub wiki: dev meeting agendas for January
7. Search vault: completed tasks, meeting notes, accomplishments
8. Synthesize all data into report
9. Write to "monthly report 2026-01.md"
10. Display summary stats and confirm
```

```
User: /mr 2025-12

1. Determine report period: December 2025 (2025-12-01 to 2025-12-31)
2-10. Same as above but for December
```

### Partial Data Example

```
User: /monthly

1. Determine report period: January 2026
2. Pull repos (success)
3. Jira: success — 47 resolved, 23 created
4. GitHub: success — 31 PRs merged, 12 issues closed
5. Microsoft Graph: SKIP — env vars not set
6. Wiki: 2 dev meeting agendas found
7. Vault: 28 tasks completed, 6 meeting note sections
8. Write report (calendar sections note "data unavailable")
9. Confirm: "Report written. Note: Calendar data unavailable (Microsoft Graph not configured)."
```
