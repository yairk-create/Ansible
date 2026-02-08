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

### 2. Update README.md Documentation
The agent will review any new or modified playbooks and ensure the `README.md` contains a clear explanation and usage example for each one in the "Active Playbooks" section.

### 3. Stage Playbook Changes
Stage all modified and new playbooks, including the updated `README.md`.
// turbo
```bash
git add playbooks/*.yml ansible.cfg inventory/hosts.ini README.md .agent/workflows/*.md
```

### 4. Commit and Push
The agent will summarize the specific changes made (e.g., "Added a new scanning playbook for Proxmox") and push them to the main branch.
// turbo
```bash
# The agent will generate a dynamic message, for example:
# git commit -m "Summarized updates: [Description of changes]" && git push origin main
```

## How to trigger
Type `/commit` or ask the agent to "summarize and commit my changes".
