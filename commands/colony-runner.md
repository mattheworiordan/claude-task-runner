---
name: colony-runner
description: RELF-style execution with fresh context per milestone
version: 1.4.0
status: active

# Claude Code command registration
allowed-tools: Bash, Read, AskUserQuestion
---

# Colony Runner

Execute a Colony project with fresh context per milestone using the RELF-style bash runner.

**When to use this instead of `/colony-deploy`:**
- Long-running projects (many milestones)
- When you notice the orchestrator "forgetting" rules
- When strict adherence to task verification is critical
- For fully autonomous execution without context drift

## How It Works

1. Bash outer loop handles milestone transitions (deterministic, can't drift)
2. Each milestone executed via `claude -p` (fresh context)
3. `claude -p` can spawn sub-agents (Task tool works)
4. Progress streamed back to this session

## Step 1: Find Project

```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state list
```

If `$ARGUMENTS` specifies a project, use that. Otherwise ask user to select.

## Step 2: Confirm Options

Use AskUserQuestion to confirm execution mode:

```
Running Colony project: {project}

Options:
1. Autonomous (no pauses between milestones)
2. Interactive (pause for approval at each milestone)
3. Verbose (show detailed progress)
```

Default: Interactive + Verbose

## Step 3: Execute Runner

Based on user's choices, run the appropriate command:

**Interactive + Verbose (recommended):**
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony-runner {project} --verbose 2>&1
```

**Autonomous + Verbose:**
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony-runner {project} --autonomous --verbose 2>&1
```

**Interactive (minimal output):**
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony-runner {project} 2>&1
```

**Autonomous (minimal output):**
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony-runner {project} --autonomous 2>&1
```

## Step 4: Monitor and Report

The runner script will:
- Execute each milestone with fresh context
- Pause between milestones (if interactive)
- Output progress and completion status

When the runner completes, summarize:
- Milestones completed
- Any failures or stuck tasks
- Final project state

## Comparison with /colony-deploy

| Aspect | /colony-deploy | /colony-runner |
|--------|----------------|----------------|
| Context | Accumulates in session | Fresh per milestone |
| Orchestrator | AI in your session | AI via claude -p |
| Interactivity | Full (AskUserQuestion) | Between milestones only |
| Drift risk | Can forget rules over time | Bash loop is deterministic |
| Best for | Quick tasks, interactive work | Long runs, strict adherence |

## Troubleshooting

**"Project not found"**: Run `/colony-mobilize` first to create a project.

**Milestone stuck**: Check `.working/colony/{project}/logs/` for task logs.

**No progress**: Ensure `claude` CLI is in PATH and working.
