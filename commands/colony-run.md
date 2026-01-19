---
name: colony-run
description: Execute tasks with smart parallelization and verification
version: 1.2.0
status: active

# Claude Code command registration
allowed-tools: Read, Write, Bash, Task, Grep, Glob, AskUserQuestion
---

# Run Tasks

Execute tasks from a colony project using sub-agents with verification.

## Core Principles

1. **COORDINATION ONLY** - You spawn workers, never implement inline
2. **Correctness over speed** - Get it right, parallelization is a bonus
3. **CLI for state** - Use `colony` CLI for state operations (saves tokens)
4. **Isolated execution** - Each task runs in fresh sub-agent context
5. **Independent verification** - Different agent verifies completion

<critical>
YOU ARE AN ORCHESTRATOR, NOT A WORKER.

When users provide feedback requiring implementation:
- NEVER read files to debug
- NEVER edit files directly
- NEVER run builds or tests
- NEVER make "quick fixes"

Your context is precious. Spawn workers for implementation. Always.
</critical>

## Step 0: Verify CLI

```bash
# Verify colony CLI is available (Claude Code's Bash doesn't inherit user PATH)
[[ -x "${CLAUDE_PLUGIN_ROOT}/bin/colony" ]] && echo "colony CLI ready" || echo "ERROR: colony CLI not found"
```

## Step 0.5: Check Orchestrator Delegation

```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony config init 2>/dev/null || true
orchestrator_model=$(${CLAUDE_PLUGIN_ROOT}/bin/colony get-model orchestrator)
worker_model=$(${CLAUDE_PLUGIN_ROOT}/bin/colony get-model worker)
inspector_model=$(${CLAUDE_PLUGIN_ROOT}/bin/colony get-model inspector)

# Get session model from Claude Code settings (for worker inheritance)
# Model is always in ~/.claude/settings.json (main Claude config, not CLAUDE_CONFIG_DIR)
session_model=$(jq -r '.model // "sonnet"' "$HOME/.claude/settings.json" 2>/dev/null || echo "sonnet")
```

**Resolve worker model:**
- If `worker_model` is "inherit" → use `session_model` (e.g., "opus")
- Otherwise use the explicit `worker_model`

**Delegation decision:**

| orchestrator | Action |
|--------------|--------|
| `inherit` | Run in session (no delegation) → Step 1 |
| `haiku`/`sonnet`/`opus` | Delegate to sub-orchestrator → spawn below |

**If delegating** (orchestrator is NOT "inherit"):

Spawn a sub-agent with the orchestrator model. Pass resolved worker model explicitly:

```
Task(
  subagent_type: "general-purpose",
  model: "{orchestrator_model}",  // e.g., "haiku"
  prompt: "Run Colony orchestration for project: {$ARGUMENTS}

  CRITICAL: Read and follow the FULL instructions in:
  {CLAUDE_PLUGIN_ROOT}/commands/colony-run.md

  Start from Step 1 (skip Step 0 and 0.5 - you are the delegated orchestrator).

  Configuration for this run:
  - Worker model: {resolved_worker_model} (e.g., opus)
  - Inspector model: {inspector_model} (e.g., haiku)
  - CLI path: {CLAUDE_PLUGIN_ROOT}/bin/colony

  Follow the milestone checkpoint format EXACTLY as specified in the prompt file.
  This includes: progress bars, 'How to verify' sections, proposed commits, etc."
)
```

Then STOP - the sub-agent handles everything. Return its result to the user.

**If NOT delegating** (orchestrator=inherit):

Continue to Step 1 and run orchestration directly in this session.

## Step 1: Initialize

```bash
# Ensure config exists (creates ~/.colony/config.json if missing)
${CLAUDE_PLUGIN_ROOT}/bin/colony config init 2>/dev/null || true

# Find projects
${CLAUDE_PLUGIN_ROOT}/bin/colony state list
```

If `$ARGUMENTS` specifies a project, use that. If one project exists, use it. If multiple, ask. If none: `"No projects. Use /colony-plan to create one."`

## Step 2: Load State

```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state get {project}
${CLAUDE_PLUGIN_ROOT}/bin/colony state get {project} tasks
```

Read `context.md` directly for project rules:
```
.working/colony/{project}/context.md
```

### 2.1: Resume Check

```bash
# Check for tasks stuck in "running"
${CLAUDE_PLUGIN_ROOT}/bin/colony state get {project} tasks | jq '[to_entries[] | select(.value.status == "running")]'
```

If tasks are "running":
- Running >30 min: `${CLAUDE_PLUGIN_ROOT}/bin/colony state task {project} {id} pending`
- Running <30 min: Spawn worker to continue

## Step 3: Git Pre-Flight (if applicable)

Skip if `state.json.git.strategy == "not_applicable"`.

```bash
git status --porcelain
git branch --show-current
```

If dirty: STOP and ask user to commit/stash. If wrong branch: ask to switch or continue.

## Step 4: Concurrency & Mode

Default concurrency: 5. Get from state: `${CLAUDE_PLUGIN_ROOT}/bin/colony state get {project} concurrency`

**Autonomous mode** - if user says "autonomous" or "auto":
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state set {project} autonomous_mode true
```

Autonomous behavior:
- Continue past failures (mark failed, move on)
- No pause for human checkpoints
- Max 3 retries per task, stop if >50% fail

## Step 5: Execution Loop

```
REPEAT until all tasks complete/failed/blocked:
```

### 5.1: Get Current State

```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state summary {project}
```

### 5.2: Identify Ready Tasks

A task is READY when:
- status = "pending"
- All tasks in depends_on are "complete"
- Not blocked by failed dependency

### 5.3: Check Completion

If no READY tasks:
- All complete → Print success, go to Step 6
- Some failed/blocked → Print summary, go to Step 6
- Pending but blocked → Explain, go to Step 6

### 5.4: Plan Parallel Execution

Select up to `{concurrency}` ready tasks.

**Parallelization rules:**
- Same serial group → one at a time
- Different/parallel groups → can run together
- Browser tests → usually serialize
- Same file modifications → serialize
- **When uncertain, ASK**

### 5.5: Execute Task Batch

For each task:

a) **Mark running and get model:**
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state task-start {project} {task-id}
worker_model=$(${CLAUDE_PLUGIN_ROOT}/bin/colony get-model worker)
${CLAUDE_PLUGIN_ROOT}/bin/colony state log {project} "task_started" '{"task": "{task-id}", "model": "'"$worker_model"'"}'
```

b) **Spawn worker sub-agent** with `subagent_type="colony:worker"` and model from config:

```
Execute this task following the project context.

═══════════════════════════════════════════════════════════
TASK BUNDLE
═══════════════════════════════════════════════════════════

## Logging
- Attempt: {attempt} of 3
- Log Path: .working/colony/{project}/logs/{task-id}_LOG.md

## Task
{Content of tasks/{task-id}.md}

## Project Context (condensed if >100 lines)
{Content of context.md}

═══════════════════════════════════════════════════════════

Read source files using Read tool. Complete and respond:

{"status": "DONE", "summary": "...", "files_changed": [...]}
or
{"status": "STUCK", "reason": "...", "attempted": [...], "need": "..."}
```

d) If parallel batch: spawn all workers together, wait for all.

### 5.6: Process Results

**If DONE:**

Get inspector model and log it:

```bash
inspector_model=$(${CLAUDE_PLUGIN_ROOT}/bin/colony get-model inspector)
${CLAUDE_PLUGIN_ROOT}/bin/colony state log {project} "inspection_started" '{"task": "{task-id}", "model": "'"$inspector_model"'"}'
```

Spawn inspector with `subagent_type="colony:inspector"` and model from config:

```
Verify this task was completed correctly.

═══════════════════════════════════════════════════════════
VERIFICATION REQUEST
═══════════════════════════════════════════════════════════

Task: {task-id}
Log: .working/colony/{project}/logs/{task-id}_LOG.md
Task file: .working/colony/{project}/tasks/{task-id}.md

Worker summary: {one-line from worker}
Files changed: {list}

Verify:
1. Run verification command from task file
2. Run linter on changed files (e.g., `npx xo {files}` or project lint command)
3. Check all acceptance criteria
4. Inspect file contents match requirements

IMPORTANT: Only verify files listed above. Ignore other files that may have been
created by parallel tasks - they will be verified separately.

═══════════════════════════════════════════════════════════

Respond:
{"result": "PASS", "summary": "..."}
or
{"result": "FAIL", "issues": [...], "suggestion": "..."}
```

**If PASS:** Validate artifacts exist, then:
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state task-complete {project} {task-id}
${CLAUDE_PLUGIN_ROOT}/bin/colony state log {project} "task_complete" '{"task": "{task-id}", "worker_model": "'"$worker_model"'", "inspector_model": "'"$inspector_model"'"}'
```

**If FAIL:**
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state task-fail {project} {task-id} "{error}"
```
- If attempts < 3: reset to pending
- If attempts >= 3: ask for human intervention

**If STUCK:**
- attempts < 3 → pending
- attempts >= 3 → blocked, ask user

### 5.6a: Artifact Validation

**Before marking complete, verify artifacts exist:**

```bash
ls -la .working/colony/{project}/logs/{task-id}_LOG.md
```

For VISUAL tasks:
```bash
ls .working/colony/{project}/screenshots/{prefix}_*.png | wc -l
```

If missing: DO NOT mark complete, retry task.

### 5.7: Update Blocked Dependencies

For tasks depending on failed/blocked task:
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state task {project} {dependent-id} blocked
```

### 5.8: Progress Report

After each batch, show progress with a proportional bar:

```
Progress: {project}
████████████░░░░░░░░ 60% (12/20)

This round:
✅ T003: Add auth - PASSED
❌ T005: Add OAuth - FAILED

Next: T006, T007 (ready)
```

**Progress bar calculation:** 20 characters total. Filled = (complete/total) × 20.
- 44% (11/25) → `█████████░░░░░░░░░░░` (9 filled, 11 empty)
- 60% (12/20) → `████████████░░░░░░░░` (12 filled, 8 empty)
- 100% → `████████████████████`

### 5.8a: Milestone Checkpoint

**Check if milestone complete:**

```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state get {project} milestones
```

If all tasks in current milestone are complete:

1. **Log the decision:**
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state log {project} "milestone_complete" '{"milestone": "M1", "tasks_completed": 3}'
```

2. **Mark milestone complete:**
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state set {project} 'milestones[0].status' '"complete"'
```

3. **Execute checkpoint based on type:**

**Principle:** Autonomous mode skips human approval, not verification. Inspector verification always happens. The difference is whether we pause for user confirmation.

| Checkpoint | Autonomous Mode | Non-Autonomous Mode |
|------------|-----------------|---------------------|
| `review` | Log and continue | **PAUSE** - Ask user to approve |
| `commit` | Auto-commit, continue | Auto-commit, continue |
| `branch` | Create branch, continue | Create branch, ask to continue |
| `pr` | Log for later, continue | Create PR, pause |

**Non-autonomous mode (default):**

First, gather context for the user to review:

```bash
# Get files changed
git status --porcelain

# Get diff summary
git diff --stat HEAD
```

Then present a complete checkpoint summary:

```
═══════════════════════════════════════════════════════════════
MILESTONE COMPLETE: M1 - Infrastructure Setup
═══════════════════════════════════════════════════════════════

Tasks completed:
  ✅ T001: {name} - {one-line summary from log}
  ✅ T002: {name} - {one-line summary from log}
  ✅ T003: {name} - {one-line summary from log}

Files changed:
  {git diff --stat output, e.g.:}
  src/kitty-protocol.ts   | 120 ++++++++++++
  src/parse-keypress.ts   |  45 +++--
  3 files changed, 165 insertions(+), 12 deletions(-)

How to verify (pick relevant ones):
  • Web app: Visit http://localhost:3000/{path} - you should see {expected}
  • API: Run `curl localhost:3000/api/{endpoint}` - expect {response}
  • CLI: Run `{command}` - should output {expected}
  • Tests: `npm test` shows {N} passing
  • Visual: Look for {specific UI element} in {location}

Out of scope (don't worry about):
  • {Thing that looks broken but isn't part of this milestone}
  • {Known issue being addressed in later milestone}

Proposed commit (if commit_strategy is phase):
  feat({scope}): {milestone description}

  - T001: {summary}
  - T002: {summary}
  - T003: {summary}

Next milestone: M2 - Core Implementation
  Ready tasks: T004, T005 (can run in parallel)

═══════════════════════════════════════════════════════════════
```

Use AskUserQuestion with options: "Approve & Continue", "Review files first", "Pause".

**Autonomous mode:** Log completion, proceed to next milestone automatically.

### 5.9: Git Commit (if applicable)

Skip if `git.strategy == "not_applicable"`.

Based on `commit_strategy`:
- **task**: Commit after each verified task
- **phase**: Commit at milestone boundaries (after 5.8a milestone checkpoint)
- **end**: No commits during execution
- **manual**: Prompt user after each phase

**For phase/task commits, execute:**
```bash
git add -A
git commit -m "feat({scope}): {description}

Tasks: {list of completed tasks}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

### 5.10: Checkpoint

**Classify user response:**

| Category | Examples | Action |
|----------|----------|--------|
| A: Info question | "What does X do?", "Show status" | Answer briefly, continue |
| B: Command | "pause", "set concurrency 3", "skip T005" | Execute command, continue |
| C: Implementation | "I get 404", "Fix X", "This shouldn't be committed", "Add Y to gitignore" | **STOP → Go to 5.11** |

<critical>
SELF-CHECK before responding:

Are you about to:
- Read a file to understand an issue?
- Run a command to debug something?
- Make a "quick" edit?
- Investigate an error?

If YES to any: YOU ARE IN CATEGORY C.
Stop immediately. Go to Step 5.11. Spawn a worker.
</critical>

### 5.11: Handle User Feedback

```
═══════════════════════════════════════════════════════════════
!! THIS IS THE STEP WHERE YOU ALWAYS VIOLATE THE RULES
!! READ EVERY WORD BEFORE RESPONDING
═══════════════════════════════════════════════════════════════
```

**WHY THIS MATTERS:**

Your context is precious. Right now it contains:
  + Project state and task dependencies
  + Execution history and parallelization decisions
  + Git strategy and commit tracking

If you implement inline, your context fills with:
  - File contents (hundreds of lines)
  - Error messages and stack traces
  - Multiple edit attempts

After 3-4 feedback cycles, you'll lose track of the project.
Workers have FRESH context. They're designed for implementation.
You're designed for coordination. Stay in your lane.

```
═══════════════════════════════════════════════════════════════
```

**The procedure:**

1. **Parse feedback into items:**
   ```
   Feedback items:
   • 404 on dev server
   • .next in git
   ```

2. **Ask if more:** "Any other feedback?"

3. **Create subtasks for EVERY item:**

   Each feedback item becomes a formal subtask with full verification:
   - ID: `T{last}.{sequence}` (e.g., T009.1, T009.2)
   - Full task structure (context, criteria, verification)
   - Worker + Inspector flow
   - Logged in state.json

   ```bash
   # Create subtask file
   # Write to .working/colony/{project}/tasks/T009.1.md

   # Add to state
   ${CLAUDE_PLUGIN_ROOT}/bin/colony state set {project} 'tasks.T009.1' '{"status":"pending","attempts":0,"is_subtask":true,"parent":"T009","created_from":"user_feedback"}'

   # Log the decision
   ${CLAUDE_PLUGIN_ROOT}/bin/colony state log {project} "feedback_subtask_created" '{"feedback": "add .next to gitignore", "subtask": "T009.1"}'
   ```

4. **Execute subtasks:** Run through normal worker + inspector flow.

5. **After completion:** Pause for user review.

**No exceptions. No shortcuts.**

Even in autonomous mode, feedback creates subtasks with full worker + inspector verification. Autonomous mode skips human approval pauses, not bot verification.

```
END REPEAT
```

## Step 6: Final Summary

```
════════════════════════════════════════════════════════════
Execution Complete: {project}

Total: {n} | ✅ {complete} | ❌ {failed} | 🚫 {blocked}

{If git active:}
Branch: {branch}
Commits: {count}

{List completed/failed tasks}
════════════════════════════════════════════════════════════
```

## Step 7: Generate Report (MANDATORY)

Write to `.working/colony/{project}/REPORT.md`:

```markdown
# Colony Report: {project}

Generated: {timestamp}
Outcome: {COMPLETE|PARTIAL|FAILED}
Tasks: {passed} passed, {failed} failed, {blocked} blocked
Milestones: {completed}/{total}

## Milestones
| Milestone | Status | Tasks |
|-----------|--------|-------|
| M1: {name} | complete | T001-T003 |
| M2: {name} | partial | T004-T007 |

## Results by Task
| Task | Status | Attempts |
|------|--------|----------|
...

## Decisions Made
{From execution_log, filtered for decision events}

| Time | Type | Decision | Details |
|------|------|----------|---------|
| 14:30 | parallelization | T001+T002 parallel | No file conflicts |
| 15:00 | feedback | Created T009.1 | User: "add .next to gitignore" |
| 15:30 | milestone | M1 approved | User confirmed |

## Feedback Addressed
| Feedback | Subtask | Status |
|----------|---------|--------|
| "add .next to gitignore" | T009.1 | complete |
| "404 on dev server" | T009.2 | complete |

## Findings
### Critical Issues
### Recurring Patterns

## Recommended Actions
...
```

**Always generate the report, even for partial/failed runs.**

## Recovery

If interrupted, re-run `/colony-run`. Tasks "running" >30 min reset to pending.

## User Commands

| Command | Effect |
|---------|--------|
| "pause" | Stop after current batch |
| "autonomous" | Switch to autonomous mode |
| "set concurrency to N" | Adjust parallel agents |
| "skip T005" | Mark skipped, continue |
| "retry T005" | Reset to pending |
| "commit now" | Force commit |
| {feedback} | Triggers 5.11 |

## Rules Summary

1. NEVER verify without inspector PASS
2. NEVER mark complete without artifacts
3. CLI for state: `${CLAUDE_PLUGIN_ROOT}/bin/colony state ...`
4. Re-read state before each iteration
5. Ask when parallelization uncertain
6. **NEVER implement inline** - spawn workers
7. **Feedback = subtask** - Every feedback item becomes a formal subtask, always verified
8. **Milestone checkpoints** - Pause and ask for approval at milestone boundaries (unless autonomous)
9. **Log decisions** - All parallelization, feedback, and checkpoint decisions logged to execution_log
