# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is an Obsidian vault containing personal work notes for Brandt Kurowski, a software engineering manager at UCEAP (University of California Education Abroad Program). The vault primarily consists of markdown files documenting meetings, 1-on-1s, project notes, technical documentation, and task tracking.

## Vault Structure

### Key File Types and Naming Conventions

- **1-on-1 notes**: Named as `[Name] 1on1.md` (e.g., `Thomas 1on1.md`, `Christina 1on1.md`)
- **Meeting notes**: Descriptive names with dates or topics (e.g., `dev meeting.md`, `it monthly meeting.md`)
- **Project documentation**: Prefixed with project codes where applicable (e.g., `UP-684 queue.md`, `RWSP2-708.md`)
  - `UP-` prefix: Portal (UCEAP SIS) project tickets
  - `RWSP2-` prefix: Reciprocity Portal (Reciprocity Website) project tickets
  - `WEBP4-` prefix: UCEAP Website project tickets
  - `UCDCSISDEV-` prefix: UCDC SIS project tickets
  - `UCDCWEB2-` prefix: UCDC Website project tickets
  - `RWR-` prefix: Research website project tickets
- **Postmortems**: Named descriptively with "postmortem" (e.g., `reciprocity postmortem.md`, `Oslo Incident Postmortem.md`)
- **Annual reviews**: Follow pattern `YYYY-YYYY annual performance review - [Name].md`
- **Untitled notes**: Temporary files named `Untitled N.md` - these should be either deleted or renamed with proper titles

### Key Directories

- `playbook/`: Cloned ITSE Playbook repository (SOPs and best practices)
- `github-wiki/`: Cloned GitHub wiki (developer meeting agendas)
- `Learning from Dutch/`: A marp presentation
- `.obsidian/`: Obsidian configuration (workspace settings, plugins)
- `.docker/`: Contains Dockerfile for running Claude Code in containerized environment
- `.claude/`: Claude Code skills and helper scripts

### Obsidian Plugins in Use

- `obsidian-tasks-plugin`: Task management with checkboxes and date tracking
- `omnisearch`: Enhanced search functionality
- `emoji-shortcodes`: Emoji support
- `obsidian-style-settings`: Custom styling

## Working with This Vault

### Task Management

Tasks are tracked using the Tasks plugin with the following syntax:
- `- [ ]` for incomplete tasks
- `- [x]` for completed tasks with `✅ YYYY-MM-DD` completion timestamp
- `📅 YYYY-MM-DD` for due dates
- `TODO.md` uses a tasks query to provide an overview
### Key Projects and Systems

- **Portal (myeap2)**: Study abroad application and management system for outbound students
- **Reciprocity**: Reciprocal Exchange program management system
- **UCDC**: UC Washington DC program SIS and Website
- **Azure/AWS migration**: Infrastructure modernization efforts (P2A project)
- **Mobile app**: New app being developed to support students while abroad
### Common Technical Contexts

- **Infrastructure**: Pantheon hosting, Azure migration, AWS architecture
- **Development**: Drupal, PHP, devcontainer workflows, Docker
- **CI/CD**: GitHub workflows, automated testing (Cypress, Playwright)
- **Security**: GDPR compliance, SSO/MFA implementation, risk assessments

## Docker/Containerization Setup

A Dockerfile exists at `.docker/Dockerfile` for running Claude Code in a containerized environment with this vault. The container:
- Runs as user `claude`
- Installs Claude Code CLI
- Mounts `/workspace` as the working directory
- See `obsidian claude.md` for usage instructions

## Syncing Tooling Across Machines

A git overlay repo (`kurowski/obsidian-vault-tools`, private) tracks tooling files that Obsidian Sync does not handle: `.docker/`, `.claude/skills/`, `.claude/jira-helper.sh`, and `.claudeignore`. Vault notes are synced by Obsidian Sync; git handles only the tooling.

**On startup, automatically run `git pull` to pick up any tooling changes made on another machine.** Do this at the beginning of every new session without being asked.

**On session start, if a SessionStart hook indicates `/start-my-day` has not been run today, immediately suggest it to the user before responding to anything else.** This is the first thing the user should see.

When skills, the Dockerfile, jira-helper.sh, .claudeignore, or other tooling files are modified, commit and push so changes reach the other machine:
```bash
git add -A && git commit -m "description of change" && git push
```

## Notes on Content

- Many notes contain sensitive work information including personnel discussions, project planning, and technical architecture
- Date references in notes span from 2023 to 2026 (as of writing)
- The vault owner is a development team lead managing five engineers:
	- Armando
	- Christina
	- Helio
	- Jakob
	- Shaun
- The vault owner works closely with peers and their teams:
	- Magdala (Maggie): Project Manager
		- Fernando: QA tester, helpdesk
		- Que: Business analyst, product owner for UCEAP Portal
	- Jason: DBA
		- Hollie: DBA
- Regular meetings tracked: dev meetings, 1-on-1s, IT monthly meetings, various project check-ins
