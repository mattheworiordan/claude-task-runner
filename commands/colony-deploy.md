---
name: colony-deploy
description: Deploy workers with smart parallelization and verification
version: 1.7.0
status: active

# Claude Code command registration
allowed-tools: Read, Write, Bash, Task, Grep, Glob, AskUserQuestion
---

# Deploy Colony

Execute tasks from a colony project using sub-agents with verification.

## Core Principles

1. **COORDINATION ONLY** - You spawn workers, never implement inline
2. **Correctness over speed** - Get it right, parallelization is a bonus
3. **CLI for state** - Use `colony` CLI for state operations (saves tokens)
4. **Isolated execution** - Each task runs in fresh sub-agent context
5. **Independent verification** - Different agent verifies completion
6. **Human is ADDITION, not replacement** - Milestone checkpoints add human review, but do NOT excuse automated testing. Every automatable check must be automated.

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

## Step 0.5: Get Model Configuration

```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony config init 2>/dev/null || true
worker_model=$(${CLAUDE_PLUGIN_ROOT}/bin/colony get-model worker)
inspector_model=$(${CLAUDE_PLUGIN_ROOT}/bin/colony get-model inspector)

# Get session model from Claude Code settings (for worker inheritance)
session_model=$(jq -r '.model // "sonnet"' "$HOME/.claude/settings.json" 2>/dev/null || echo "sonnet")
```

**Resolve worker model:**
- If `worker_model` is "inherit" → use `session_model` (e.g., "opus")
- Otherwise use the explicit `worker_model`

<critical>
ORCHESTRATOR ALWAYS RUNS IN-SESSION.

Do NOT delegate to a sub-orchestrator via Task(). Sub-agents cannot spawn
their own sub-agents, so a delegated orchestrator cannot spawn workers.

The "orchestrator" config setting is deprecated and ignored.
</critical>

Continue to Step 1.

## Step 1: Initialize

```bash
# Ensure config exists (creates ~/.colony/config.json if missing)
${CLAUDE_PLUGIN_ROOT}/bin/colony config init 2>/dev/null || true

# Find projects
${CLAUDE_PLUGIN_ROOT}/bin/colony state list
```

If `$ARGUMENTS` specifies a project, use that. If one project exists, use it. If multiple, ask. If none: `"No projects. Use /colony-mobilize to create one."`

## Step 2: Load State (TOKEN-OPTIMIZED)

<critical>
DO NOT use `colony state get {project}` - it returns 1000+ lines.
Use the optimized commands below instead.
</critical>

```bash
# Get minimal initialization overview (replaces full state dump)
${CLAUDE_PLUGIN_ROOT}/bin/colony init-overview {project}
```

This returns ~15 lines with: project name, task counts, milestone count, git strategy, context path.

**DO NOT read context.md** - workers will read it via task-bundle.

### 2.1: Resume Check

The `loop-state` command (Step 5.0) includes stuck tasks. If any are stuck >30 min:
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state task {project} {id} pending
```

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

## Step 5: Execution Loop (STATELESS)

<critical>
THIS LOOP IS STATELESS. Every iteration:
1. Read fresh state from CLI (don't trust memory)
2. Decide action based ONLY on state
3. Execute action
4. Loop

DO NOT rely on memory from previous iterations.
The CLI is your source of truth - re-read it every time.
</critical>

```
REPEAT until all tasks complete/failed/blocked:
```

### 5.0: Loop Start (EVERY ITERATION) - TOKEN-OPTIMIZED

<critical>
USE SINGLE COMMAND. Do not call multiple state queries.
</critical>

```bash
# SINGLE COMMAND replaces: state summary + state get tasks + next-batch
${CLAUDE_PLUGIN_ROOT}/bin/colony loop-state {project}
```

**Returns minimal JSON (~15 lines):**
```json
{
  "counts": {"pending": 5, "running": 0, "complete": 12, "failed": 0, "blocked": 1},
  "milestone": {"id": "M3", "name": "Content Routing", "tasks_done": 5, "tasks_total": 7},
  "ready": ["T019", "T020"],
  "stuck": [],
  "rule_echo": true
}
```

**Use these fields:**
- `counts` - For progress reporting
- `milestone` - Current milestone info
- `ready` - Task IDs to execute (replaces next-batch)
- `stuck` - Tasks to reset (running >30 min)
- `rule_echo` - If true, echo the core rules (every 3 tasks)

**If `stuck` is non-empty:** Reset those tasks to pending before continuing.

### 5.0a: Rule Echo (Every 3 Tasks)

**If `rule_echo` is true in loop-state output, echo the core rule:**

```
════════════════════════════════════════════════════════════════
RULE REFRESH (${counts.complete} tasks complete)

YOU ARE AN ORCHESTRATOR, NOT A WORKER.
• loop-state → Pick task → task-bundle → Spawn worker → Loop
• NEVER read files, NEVER implement inline, NEVER "quick fix"
• Your context is precious. Workers have fresh context.

TOKEN DISCIPLINE:
• Use loop-state (not state get/summary)
• Use task-bundle (not file reads)
• Use inspect-bundle (not manual diff)
════════════════════════════════════════════════════════════════
```

### 5.1: Get Ready Tasks (from loop-state)

**Already have this from Step 5.0:**

The `ready` array in loop-state output contains task IDs ready to execute.
**CLI handles parallelization logic** - it considers:
- Dependencies (only returns tasks with deps met)
- Serial groups (won't return conflicting tasks)
- File conflicts (encodes in task definitions)

**You just execute what it gives you.** Don't second-guess the CLI.

Do NOT call `next-batch` separately - it's included in `loop-state`.

### 5.2: Check Completion (from loop-state)

**Use the loop-state output, not a separate call:**

- **If `ready` is empty AND `counts.pending` is 0:** All complete → Step 6
- **If `ready` is empty AND `counts.failed` > 0:** Some failed → Step 6 with summary
- **If `ready` is empty AND `counts.pending` > 0:** Deps not met → Wait or Step 6
- **If `ready` has tasks:** Continue to 5.3

Do NOT call `is-complete` separately - derive from loop-state counts.

### 5.3: Execute Task Batch (TOKEN-OPTIMIZED)

For each task in `ready` array:

a) **Mark running and get bundle:**
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state task-start {project} {task-id}
worker_model=$(${CLAUDE_PLUGIN_ROOT}/bin/colony get-model worker)

# GET COMPLETE BUNDLE - DO NOT READ FILES MANUALLY
task_bundle=$(${CLAUDE_PLUGIN_ROOT}/bin/colony task-bundle {project} {task-id})
```

<critical>
DO NOT read task files, context.md, LEARNINGS.md, or git history manually.
The task-bundle command includes everything the worker needs.
Pass the bundle directly to the worker prompt.
</critical>

b) **Spawn worker sub-agent** with `subagent_type="colony:worker"` and model from config:

```
Execute this task following the project context.

{task_bundle}
```

That's it. The bundle includes:
- Task definition
- Project context (key sections)
- Git history
- Learnings
- Retry context (if applicable)
- Response format instructions

c) If parallel batch: spawn all workers together, wait for all.

d) **Log start:**
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state log {project} "task_started" '{"task": "{task-id}", "model": "'"$worker_model"'"}'
```

### 5.4: Process Results

**Parallel inspection:** If multiple workers completed in a parallel batch, spawn their inspectors in parallel too. This is safe because:
- Inspectors are read-only (verify, don't modify code)
- Each inspector has its own log file
- Tests should be isolated
- Respects same parallelization rules as workers (same-file tasks stay serial)

**If DONE:**

═══════════════════════════════════════════════════════════════════════════════
⚠️  CRITICAL: YOU MUST SPAWN AN INSPECTOR. DO NOT SKIP THIS STEP.
═══════════════════════════════════════════════════════════════════════════════

The CLI will REJECT task-complete if no inspection_started event exists.
You CANNOT mark a task complete without spawning an inspector first.

**Step A: Log inspection event (REQUIRED - CLI enforces this)**

```bash
inspector_model=$(${CLAUDE_PLUGIN_ROOT}/bin/colony get-model inspector)
${CLAUDE_PLUGIN_ROOT}/bin/colony state log {project} "inspection_started" '{"task": "{task-id}", "model": "'"$inspector_model"'"}'
```

**Step B: Get inspector bundle (TOKEN-OPTIMIZED)**

<critical>
DO NOT read requirements file or run git diff manually.
Use inspect-bundle to get everything in one call.
</critical>

```bash
# Get files from worker response
files_list=$(echo "{worker_response}" | jq -r '.files | join(",")')

# GET COMPLETE BUNDLE
inspect_bundle=$(${CLAUDE_PLUGIN_ROOT}/bin/colony inspect-bundle {project} {task-id} --files "$files_list")
```

**Step C: Spawn inspector (REQUIRED)**

Spawn inspector with `subagent_type="colony:inspector"` and model from config:

```
Verify this task was completed correctly.

{inspect_bundle}
```

The bundle includes:
- Task requirements
- Diff of changes
- Requirements checklist
- Verification instructions
- Response format

The inspector will respond with compact JSON:
```json
{"result": "PASS", "summary": "<80 chars"}
```
or
```json
{"result": "FAIL", "issues": ["issue1"], "fix": "<action>"}
```

**If PASS:** Validate artifacts exist, append learnings, then mark complete:

```bash
# Append learnings to LEARNINGS.md (compound engineering)
learnings_file=".working/colony/{project}/LEARNINGS.md"
if [[ ! -f "$learnings_file" ]]; then
  echo "# Project Learnings" > "$learnings_file"
  echo "" >> "$learnings_file"
  echo "Patterns, conventions, and gotchas discovered during execution." >> "$learnings_file"
  echo "" >> "$learnings_file"
fi

# Append learnings from worker and inspector (if any)
# Format: - {learning} (T001)
for learning in {worker_learnings} {inspector_learnings}; do
  echo "- $learning ({task-id})" >> "$learnings_file"
done

${CLAUDE_PLUGIN_ROOT}/bin/colony state task-complete {project} {task-id}
${CLAUDE_PLUGIN_ROOT}/bin/colony state log {project} "task_complete" '{"task": "{task-id}", "summary": "{summary}", "files_changed": {files_list}, "learnings": {learnings_list}, "worker_model": "'"$worker_model"'", "inspector_model": "'"$inspector_model"'"}'
```

**If FAIL:**
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state task-fail {project} {task-id} "{error}"
${CLAUDE_PLUGIN_ROOT}/bin/colony state log {project} "task_failed" '{"task": "{task-id}", "issues": {issues_list}, "suggestion": "{suggestion}"}'
```

### Retry and Give-Up Logic

<critical>
The worker+inspector loop has hard limits to prevent infinite retries.
After exhausting retries, STOP and report - do not continue silently.
</critical>

**Per-task retry limits:**

| Situation | Attempts < 3 | Attempts = 3 | Attempts > 3 |
|-----------|--------------|--------------|--------------|
| Worker STUCK | Reset to pending, retry | Mark blocked, report to user | N/A (blocked) |
| Inspector FAIL | Reset to pending, retry with feedback | Mark failed, report to user | N/A (failed) |

**When retrying, include failure context:**

The worker on retry attempt N should receive:
```
Previous attempts: {N-1}
Last failure reason: {inspector feedback or STUCK reason}
What was tried: {summary of previous attempt}

FIX THE UNDERLYING ISSUE. Do not just retry the same approach.
```

**Milestone-level failure threshold:**

If **>50% of tasks in a milestone fail** after all retries:
1. STOP execution
2. Report: "Milestone {M} has critical failure rate ({X}% failed)"
3. List all failed tasks with reasons
4. Ask user: "Continue anyway?" or "Abort?"

**Session-level circuit breaker:**

If **5 consecutive tasks fail** across any milestones:
1. STOP execution immediately
2. Report: "Circuit breaker triggered - 5 consecutive failures"
3. This likely indicates a systemic issue (wrong environment, missing dependency)
4. Ask user to investigate before continuing

**Stuck vs Failed distinction:**
- **STUCK**: Worker couldn't complete (missing info, blocked by external factor)
- **FAILED**: Worker completed but inspector rejected (quality issue)

Both consume retry attempts, but STUCK may indicate the task definition needs revision.

**If STUCK:**
- attempts < 3 → pending, retry with more context
- attempts >= 3 → blocked, ask user "Is the task definition correct?"

### 5.4a: Artifact Validation

**Before marking complete, verify artifacts exist:**

```bash
ls -la .working/colony/{project}/logs/{task-id}_LOG.md
```

For VISUAL tasks:
```bash
ls .working/colony/{project}/screenshots/{prefix}_*.png | wc -l
```

If missing: DO NOT mark complete, retry task.

### 5.5: Update Blocked Dependencies

For tasks depending on failed/blocked task:
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state task {project} {dependent-id} blocked
```

### 5.6: Progress Report

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

### 5.6a: Milestone Checkpoint

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

**Non-autonomous mode (default) - TOKEN-OPTIMIZED:**

<critical>
DO NOT gather context manually (git status, git diff, reading logs).
Spawn a summarizer agent to generate the checkpoint summary.
This keeps verbose output OUT of orchestrator context.
</critical>

**Option A: Use CLI summary (simpler)**
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony milestone-summary {project} {milestone-id}
```

**Option B: Spawn summarizer agent (richer output)**

Spawn with `subagent_type="colony:summarizer"` and model `haiku`:

```
Generate milestone checkpoint summary.

Project: {project}
Milestone: {milestone-id}
Working dir: {working_dir}

Use: colony milestone-summary {project} {milestone-id}
Enhance with verification instructions based on task types.
```

The summarizer output goes directly to user terminal.
Orchestrator only needs to know "checkpoint shown, waiting for input".

Use AskUserQuestion with options:
- "Continue" - Proceed to next milestone (same context, faster)
- "Continue with fresh context" - Spawn fresh orchestrator for next milestone (slower but prevents drift)
- "Review files first" - Let user inspect before deciding
- "Pause" - Stop here

**If user selects "Continue with fresh context":**
```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state log {project} "milestone_handoff" '{"from": "M{N}", "to": "M{N+1}", "reason": "user_requested_fresh_context"}'
```

Then spawn fresh orchestrator:
```
Task(
  subagent_type: "general-purpose",
  model: "{orchestrator_model}",
  prompt: "Continue Colony orchestration for project: {project}

  Read and follow: {CLAUDE_PLUGIN_ROOT}/commands/colony-deploy.md
  Start from Step 1. Previous milestone M{N} complete, continue with M{N+1}.

  Config: worker={worker_model}, inspector={inspector_model}, autonomous={true/false}"
)
```
Then exit (return control to spawned agent).

**Autonomous mode:** Log completion, proceed to next milestone automatically.

### 5.7: Git Commit (if applicable)

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

### 5.8: User Checkpoint

**Classify user response:**

| Category | Examples | Action |
|----------|----------|--------|
| A: Info question | "What does X do?", "Show status" | Answer briefly, continue |
| B: Command | "pause", "set concurrency 3", "skip T005" | Execute command, continue |
| C: Implementation | "I get 404", "Fix X", "This shouldn't be committed", "Add Y to gitignore" | **STOP → Go to 5.9** |

<critical>
SELF-CHECK before responding:

Are you about to:
- Read a file to understand an issue?
- Run a command to debug something?
- Make a "quick" edit?
- Investigate an error?

If YES to any: YOU ARE IN CATEGORY C.
Stop immediately. Go to Step 5.9. Spawn a worker.
</critical>

### 5.9: Handle User Feedback

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

### 5.10: Context Health Check

After 5+ feedback cycles, or when you notice:
- Your responses slowing down or getting confused
- Losing track of task dependencies
- Forgetting which tasks are complete
- Confusion about project state

Tell the user:

```
Context is getting heavy. I recommend restarting with:
  /colony-deploy {project}

All state is preserved in CLI - execution will resume from current position.
```

**Why this works:**
- CLI state management preserves everything (tasks, status, logs)
- Fresh /colony-deploy reads state.json and continues
- You get fresh context with all the rules intact
- No work is lost, just context is refreshed

**Signs you need this:**
- You've processed more than 5 feedback items in one session
- Multiple milestones have passed without restart
- User has given complex multi-part feedback

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

If interrupted, re-run `/colony-deploy`. Tasks "running" >30 min reset to pending.

## User Commands

| Command | Effect |
|---------|--------|
| "pause" | Stop after current batch |
| "autonomous" | Switch to autonomous mode |
| "set concurrency to N" | Adjust parallel agents |
| "skip T005" | Mark skipped, continue |
| "retry T005" | Reset to pending |
| "commit now" | Force commit |
| {feedback} | Triggers 5.9 |

## Rules Summary

**STATELESS LOOP (Most Important):**
1. **Re-read state EVERY iteration** - Don't trust memory, CLI is truth
2. **Rule echo every 3 tasks** - Refresh core rules periodically
3. **CLI decides parallelization** - Use `next-batch`, don't second-guess

**Core Rules:**
4. NEVER verify without inspector PASS
5. NEVER mark complete without artifacts
6. **NEVER implement inline** - spawn workers for ALL implementation
7. **Feedback = subtask** - Every feedback item becomes a formal subtask
8. **Milestone checkpoints** - Pause at boundaries (unless autonomous)
9. **Log decisions** - All decisions logged to execution_log
