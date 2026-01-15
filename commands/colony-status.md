---
name: colony-status
description: Show detailed status of a colony project
version: 1.0.0
status: active

# Claude Code command registration
allowed-tools: Read, Bash, Glob
---

# Task Status

Show detailed status for a colony project.

## Step 1: Find Project

If $ARGUMENTS specifies a project, use that.

Otherwise, check for projects:
```bash
ls -d .working/colony/*/ 2>/dev/null
```

- One project → show that project's status
- Multiple projects → ask which one (or suggest `/colony-projects` for overview)
- No projects → "No projects found. Use /colony-plan to create one."

## Step 2: Load State

```
Read: .working/colony/{project}/state.json
```

## Step 3: Display Status

```markdown
════════════════════════════════════════════════════════════════
## {project-name}

**Progress:** ████████████░░░░░░░░ 60% ({completed}/{total})
**Status:** {Running | Paused | Complete | Has Failures}
**Mode:** {Interactive | Autonomous}
**Concurrency:** {n} agents
**Last Activity:** {relative time}

### Task Overview

| ID | Name | Status | Attempts | Time |
|----|------|--------|----------|------|
| T001 | Setup database | ✅ Complete | 1 | 2m |
| T002 | Add user model | ✅ Complete | 1 | 5m |
| T003 | Add auth | 🔄 Running | 1 | - |
| T004 | Add sessions | ⏳ Pending | 0 | - |
| T005 | Add OAuth | ❌ Failed | 2 | - |
| T006 | OAuth tests | 🚫 Blocked | 0 | - |

### By Status

**✅ Completed ({n}):** T001, T002
**🔄 Running ({n}):** T003
**⏳ Pending ({n}):** T004, T007, T008
**❌ Failed ({n}):** T005
**🚫 Blocked ({n}):** T006

### Parallelization Groups

| Group | Strategy | Tasks | Status |
|-------|----------|-------|--------|
| setup | Serial | T001 | ✅ Done |
| features | Parallel (5) | T002-T005 | 🔄 In Progress |
| browser-tests | Serial | T006-T008 | ⏳ Waiting |

### Failed Task Details

**T005: Add OAuth**
- Error: Missing OAUTH_CLIENT_ID environment variable
- Attempts: 2
- Last attempt: 5 minutes ago
- Suggestion: Add OAuth credentials to .env

### Recent Activity

{Last 5 entries from execution_log}

```
10:30:15 T001 started
10:32:45 T001 verified PASS
10:32:46 T002, T003, T004 started (parallel)
10:35:12 T002 verified PASS
10:38:00 T003 verified PASS
10:38:01 T004 verified FAIL - retrying
```

### Next Steps

{If running: "Execution in progress..."}
{If paused: "Run /colony-run to continue"}
{If complete: "All tasks complete!"}
{If failures: "Fix T005 and run /colony-run to retry"}
════════════════════════════════════════════════════════════════
```

## Step 4: Interactive Commands

After showing status, user can:

| Command | Action |
|---------|--------|
| "show T005" | Show full task details and error |
| "retry T005" | Reset to pending for retry |
| "skip T005" | Mark as skipped, unblock dependents |
| "details" | Show all task files |
| "log" | Show full execution log |
