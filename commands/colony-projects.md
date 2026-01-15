---
name: colony-projects
description: List all colony projects with summary status
version: 1.0.0
status: active

# Claude Code command registration
allowed-tools: Read, Bash, Glob
---

# Task Projects

List all colony projects with their status.

## Step 1: Find Projects

```bash
ls -d .working/colony/*/ 2>/dev/null
```

If no projects:
```
No colony projects found.

Use /colony-plan to create a project from a brief.
```

## Step 2: Load Each Project's State

For each project directory, read `state.json` and calculate:
- Total tasks
- Completed count
- Failed count
- Blocked count
- Last activity timestamp

## Step 3: Display Summary

```markdown
════════════════════════════════════════════════════════════════
## Colony Projects

| Project | Progress | Status | Tasks | Last Activity |
|---------|----------|--------|-------|---------------|
| integration-brief | ████████░░ 80% | 🔄 Running | 16/20 | 2 min ago |
| api-refactor | ████░░░░░░ 40% | ⏸ Paused | 8/20 | 3 days ago |
| test-cleanup | ██████████ 100% | ✅ Complete | 5/5 | 1 week ago |
| oauth-feature | ██░░░░░░░░ 20% | ❌ Has Failures | 2/10 | 1 hour ago |

### Quick Stats

**Active:** 2 projects
**Complete:** 1 project
**With Failures:** 1 project

### Project Details

**integration-brief** (active)
- Source: .working/INTEGRATION_BRIEF.md
- Created: 2 hours ago
- Concurrency: 5 agents
- ✅ 16 complete, ⏳ 4 pending

**api-refactor** (paused)
- Source: docs/API_REFACTOR_PLAN.md
- Created: 3 days ago
- Concurrency: 3 agents
- ✅ 8 complete, ⏳ 10 pending, ❌ 2 failed

**oauth-feature** (has failures)
- Source: .working/OAUTH_FEATURE.md
- Created: 2 hours ago
- Concurrency: 5 agents
- ✅ 2 complete, ⏳ 5 pending, ❌ 1 failed, 🚫 2 blocked
- **Blocking issue:** T003 failed - missing API credentials

════════════════════════════════════════════════════════════════

### Commands

| Command | Action |
|---------|--------|
| `/colony-status {project}` | Detailed status for a project |
| `/colony-run {project}` | Start/resume execution |
| `/colony-plan` | Create a new project |
| "delete {project}" | Remove a project |
| "archive {project}" | Move to .working/colony/archive/ |
```

## Step 4: Interactive Options

After listing, user can:

| Command | Action |
|---------|--------|
| "show {project}" | Same as /colony-status {project} |
| "run {project}" | Same as /colony-run {project} |
| "delete {project}" | Remove project directory |
| "archive {project}" | Move to archive folder |
| "clean completed" | Archive all 100% complete projects |
