---
description: Summarize playbook changes and commit/push them to Git
---
# Git Sync Workflow

This workflow automates the process of identifying changes in your playbooks, generating a summary, and committing them to your repository.

## Steps

### 1. Identify Changes
// turbo
```bash
git status
```

### 2. Update README.md Documentation & Git Guide
The agent will:
- Review any new or modified playbooks.
- Ensure `README.md` has a detailed explanation, technical highlights, and a copy-pasteable usage example for EVERY playbook in the "Active Playbooks" section.
- Verify that a "Git Operations" section exists in the `README.md` explaining how to use `/commit` and `/scan`.

### 3. Stage & Detailed Commit
Stage all changes. The commit message MUST be detailed, following the format:
`docs: update README and playbooks [Brief list of specific added/modified features]`

// turbo
```bash
git add playbooks/*.yml ansible.cfg inventory/hosts.ini README.md .agent/workflows/*.md
```

### 4. Push and Final Report
// turbo
```bash
git commit -m "Summarized updates: [Detailed description]" && git push origin main
```
**Final Action**: After the push, the agent MUST provide a "Detailed Change Report" in the chat, listing:
- Which files were changed.
- A technical summary of NEW logic added.
- Confirmation that GitHub is in sync.

## How to trigger
Type `/commit` or ask the agent to "summarize and commit my changes".
