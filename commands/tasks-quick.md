---
name: tasks-quick
description: Quick task execution from a simple prompt - auto-generates brief and tasks
version: 1.0.0
status: experimental

# Claude Code command registration
allowed-tools: Read, Write, Bash, Task, Grep, Glob
---

# Quick Tasks

Execute a task directly from a simple prompt without manual brief/task creation.

**Use this for**: Well-defined, straightforward tasks where you trust the AI to decompose appropriately.

**Don't use this for**: Complex tasks requiring nuanced context, design decisions, or user input during planning.

## How It Works

```
/tasks-quick "Add dark mode toggle to settings page, persist preference to localStorage"
```

This will:
1. Auto-generate a minimal brief from your prompt
2. Decompose into 2-5 small tasks
3. Run in autonomous mode
4. Return when done or stuck

## Step 1: Parse Prompt

Extract from `$ARGUMENTS`:
- The core request
- Any explicit requirements mentioned
- Implied acceptance criteria

## Step 2: Validate Suitability

**Check if this task is suitable for quick execution:**

| Signal | Suitable | Not Suitable |
|--------|----------|--------------|
| Clear, specific request | Yes | Vague requirements |
| Mechanical/well-defined | Yes | Requires design decisions |
| Small scope (<5 tasks likely) | Yes | Large scope (>10 tasks) |
| Has testable outcome | Yes | Subjective success criteria |
| Standard patterns | Yes | Novel architecture |

**If NOT suitable:**
```
This task seems too complex for /tasks-quick:
• {reason 1}
• {reason 2}

Suggest using /tasks-plan instead for:
• More control over task decomposition
• Ability to add context and design intent
• Interactive planning

Continue anyway? [y/N]
```

If user says no or doesn't respond, exit.

## Step 3: Generate Brief

Create `.working/task-runner/{project-name}/resources/original-brief.md`:

```markdown
# Quick Task: {slugified-name}

Generated from: /tasks-quick
Prompt: "{original prompt}"

## Goal
{restate the goal clearly}

## Acceptance Criteria
- [ ] {derived criterion 1}
- [ ] {derived criterion 2}
- [ ] {derived criterion 3}

## Constraints
- Keep changes minimal and focused
- Follow existing codebase patterns
- All tests must pass after changes

## Verification
{how to verify success - tests, manual check, etc.}
```

## Step 4: Quick Decomposition

Create 2-5 tasks maximum. Each task should be:
- Small (5-15 minutes)
- Independently verifiable
- Sequential by default (safe parallelization is hard to infer)

### Task Format (Simplified)

```markdown
# Task T{N}: {name}

## Status
pending

## Description
{what to do}

## Files
- {likely files to modify}

## Acceptance Criteria
- [ ] {criterion}

## Completion Promise
When done, output: TASK_COMPLETE: T{N}

## Verification Command
```bash
{command}
```

## Dependencies
{T{N-1} or "None"}
```

**Skip these sections** (no rich context for quick tasks):
- Context & Why (implied from prompt)
- Design Intent (not provided)
- Considerations (keep it simple)

## Step 5: Create Project Structure

```bash
mkdir -p .working/task-runner/{project-name}/tasks
mkdir -p .working/task-runner/{project-name}/logs
mkdir -p .working/task-runner/{project-name}/resources
```

Create minimal `state.json`:

```json
{
  "project_name": "{project-name}",
  "created_at": "{timestamp}",
  "brief_source": "quick-task",
  "total_tasks": {count},
  "concurrency": 1,
  "autonomous_mode": true,
  "task_type": "implementation",
  "git": {
    "strategy": "not_applicable"
  },
  "tasks": {
    "T001": {"status": "pending", "attempts": 0}
  }
}
```

**Note**: Quick tasks default to:
- `concurrency: 1` (serial execution, safer)
- `autonomous_mode: true` (no checkpoints)
- `git.strategy: "not_applicable"` (no branch/commits)

## Step 6: Execute

Show brief summary:
```
⚡ Quick Task: {project-name}

Decomposed into {N} tasks:
1. T001: {name}
2. T002: {name}
...

Running in autonomous mode (serial)...
```

Then execute using the same loop as `/tasks-run` but with:
- Always autonomous mode
- Always serial execution (concurrency: 1)
- No Git operations
- Simplified progress output

## Step 7: Report Result

On completion:
```
✅ Quick Task Complete: {project-name}

Tasks: {completed}/{total}
{If any failed: "⚠️ {N} task(s) failed - see logs"}

Changes made:
- {file1} (modified)
- {file2} (created)

Verification:
{test output or verification result}

Full logs: .working/task-runner/{project-name}/logs/
```

On failure:
```
❌ Quick Task Failed: {project-name}

Completed: {N}/{total}
Failed at: T{X} - {task name}

Error:
{error summary}

Options:
• Fix the issue and run: /tasks-run {project-name}
• See details: /tasks-status {project-name}
• Abandon: rm -rf .working/task-runner/{project-name}
```

## Safety Rules

1. **Max 5 tasks** - If decomposition yields >5 tasks, suggest /tasks-plan
2. **Serial execution only** - No parallelization inference
3. **No Git operations** - Changes stay uncommitted
4. **30 minute timeout** - Abort if taking too long
5. **3 retries per task** - Then fail the whole quick task

## Examples

### Good Quick Tasks

```bash
# Clear, specific, testable
/tasks-quick "Add a loading spinner to the submit button"
/tasks-quick "Fix the typo 'recieve' -> 'receive' across all files"
/tasks-quick "Add validation for email field - must be valid email format"
/tasks-quick "Extract the header component into its own file"
```

### Bad Quick Tasks (Use /tasks-plan Instead)

```bash
# Too vague
/tasks-quick "Improve the UX"

# Too large
/tasks-quick "Add user authentication with OAuth, email verification, and password reset"

# Requires decisions
/tasks-quick "Refactor the data layer"

# Subjective outcome
/tasks-quick "Make the homepage look better"
```
