---
name: colony-run
description: Execute tasks with smart parallelization and verification
version: 1.0.0
status: active

# Claude Code command registration
allowed-tools: Read, Write, Edit, Bash, Task, Grep, Glob, AskUserQuestion
---

# Run Tasks

Execute tasks from a colony project using sub-agents with verification.

## Core Principles

**0. COORDINATION ONLY - NEVER IMPLEMENT INLINE**

You are an ORCHESTRATOR, not a worker. Your job is coordination.

When users provide feedback requiring implementation:
  - NEVER read files to debug
  - NEVER edit files directly
  - NEVER run builds or tests
  - NEVER make "quick fixes"

Your context is precious - it tracks project state, dependencies, and execution history.
If you debug inline, you lose coordination capability after 3-4 feedback cycles.

Workers have fresh context for implementation. Spawn them. Always.

1. **Correctness over speed** - Get it right, parallelization is a bonus
2. **File-based state** - All state in state.json, re-read before every decision
3. **Isolated execution** - Each task runs in fresh sub-agent context
4. **Independent verification** - Different agent verifies completion
5. **Smart parallelization** - Respect resource constraints, ask when uncertain

## Step 1: Find Project

```bash
ls -d .working/colony/*/ 2>/dev/null
```

If $ARGUMENTS specifies a project, use that.

If one project exists, use it automatically:
```
Found project: integration-brief (12 tasks, 3 complete)
Starting execution...
```

If multiple projects, ask:
```
Which project should I run?
• integration-brief (12 tasks, 3 complete) - last active 2 min ago
• api-refactor (8 tasks, 0 complete) - last active 3 days ago
```

If no projects:
```
No colony projects found. Use /colony-plan to create one.
```

## Step 2: Load State and Context

```
Read: .working/colony/{project}/state.json
Read: .working/colony/{project}/context.md
```

**You are stateless. Re-read state.json before EVERY decision.**

## Step 3: Git Pre-Flight Check

**SKIP this section if `state.json.git.strategy` is `"not_applicable"`.**

For research/documentation tasks that don't require Git tracking, proceed directly to Step 4.

---

**For projects with active Git strategy:**

Before starting execution, verify Git state:

```bash
git status --porcelain
```

**If working tree is dirty, STOP:**
```
Cannot start execution - working tree has uncommitted changes:
{list of changed files}

Please either:
• Commit these changes
• Stash them (git stash)
• Discard them

Then re-run /colony-run.
```

**If clean, verify we're on the correct branch:**
```bash
git branch --show-current
```

Check against `state.json.git.branch`. If different:
```
You're on branch `{current}` but this project was set up for `{expected}`.
• Switch to {expected}? (git checkout {expected})
• Continue on {current}? (will update project config)
```

**Display Git strategy reminder:**
```
**Git Strategy:**
• Branch: {branch-name}
• Commits: {phase/task/end/manual}
• Style: {conventional commits}
• Override: "commit now", "skip commit", "show changes"
```

## Step 4: Check Concurrency Setting

From state.json, get `concurrency` (default: 5).

If user says "set concurrency to N" or "run with N agents":
- Update state.json concurrency
- Confirm: "Concurrency set to {N} agents"

Minimum: 1 agent. No maximum—set based on task complexity and resources.

## Step 4b: Check Autonomous Mode

**Autonomous mode** runs without human checkpoints. The user MUST explicitly request this.

### Detection

Check if user explicitly requested autonomous mode:
- `$ARGUMENTS` contains "autonomous" or "auto"
- User said "run autonomous", "run without interruption", "run overnight"
- state.json has `autonomous_mode: true` (set during planning)

### If Autonomous Mode Requested

```
⚡ AUTONOMOUS MODE ENABLED

This run will:
• Continue past failures (mark failed, move on)
• Not pause for human checkpoints
• Not ask for parallelization confirmation
• Generate report at end with all issues

Safety limits:
• Max 3 retries per task (then mark failed)
• Max iterations: {total_tasks * 3}
• Will stop if >50% of tasks fail

To cancel: Ctrl+C or "stop"

Starting autonomous execution...
```

Update state.json:
```json
"autonomous_mode": true
```

### Autonomous Behavior Changes

| Behavior | Interactive (default) | Autonomous |
|----------|----------------------|------------|
| Failed task (3 attempts) | Pause and ask | Mark failed, continue |
| Uncertain parallelization | Ask user | Use conservative default (serialize) |
| Phase commits | Prompt for manual if configured | Auto-commit |
| Progress updates | After each batch | Every 5 tasks or 10 minutes |
| Completion | Wait for review | Generate report, exit |

### Autonomous Exit Conditions

Stop autonomous execution when:
1. All tasks complete or failed/blocked
2. >50% of tasks have failed (likely systemic issue)
3. User sends interrupt signal
4. Max iterations reached

On exit, ALWAYS generate the report (Step 7).

## Step 5: Execution Loop

```
REPEAT until all tasks complete/failed/blocked:

    ┌─────────────────────────────────────────────────────────────┐
    │  5.1: Read Current State (EVERY iteration)                  │
    └─────────────────────────────────────────────────────────────┘

    Read state.json fresh. You have no memory between iterations.

    ┌─────────────────────────────────────────────────────────────┐
    │  5.2: Identify Ready Tasks                                  │
    └─────────────────────────────────────────────────────────────┘

    A task is READY when:
    - status = "pending"
    - All tasks in depends_on have status = "complete"
    - Not blocked by a failed dependency

    ┌─────────────────────────────────────────────────────────────┐
    │  5.3: Check Completion                                      │
    └─────────────────────────────────────────────────────────────┘

    If no READY tasks:
      - All complete → Print success summary, EXIT
      - Some failed/blocked → Print summary with issues, EXIT
      - Pending but blocked → Explain blockage, EXIT

    ┌─────────────────────────────────────────────────────────────┐
    │  5.4: Plan Parallel Execution                               │
    └─────────────────────────────────────────────────────────────┘

    From ready tasks, select up to {concurrency} tasks to run.

    **Parallelization Rules:**

    1. Check parallel_group in each task:
       - Same serial group → run one at a time
       - Different groups or parallel groups → can run together

    2. Check for resource conflicts:
       - Browser tests → usually 1 at a time (unless separate instances)
       - Database migrations → always 1 at a time
       - Same file modifications → serialize
       - External API calls → check rate limits

    3. When uncertain, ASK:
       ```
       I'm about to run these tasks in parallel:
       • T003: Add user authentication
       • T004: Add session management

       Both modify auth-related files. Safe to parallelize?
       • Yes, they touch different files
       • No, run them one at a time
       • Let me check (show me the file lists)
       ```

    4. Log parallelization decisions:
       ```json
       {"time": "...", "event": "parallel_batch", "tasks": ["T003", "T004"],
        "reason": "different files, no shared resources"}
       ```

    ┌─────────────────────────────────────────────────────────────┐
    │  5.5: Execute Task Batch                                    │
    └─────────────────────────────────────────────────────────────┘

    For each task in the batch:

    a) Update state.json BEFORE starting:
       - status = "running"
       - started_at = now
       - Increment attempts (add 1 to current count, or set to 1 if first attempt)
       - Add to execution_log

    b) Ensure logs directory exists:
       ```bash
       mkdir -p .working/colony/{project}/logs
       ```

    c) Build execution bundle:
       - Read task file
       - Read context.md
       - Read source files listed in task's "Files" section

    d) Spawn worker sub-agent:

       Use the Task tool with subagent_type="worker":

       ```
       Task: Execute this task following the project context.

       ═══════════════════════════════════════════════════════════
       TASK EXECUTION BUNDLE
       ═══════════════════════════════════════════════════════════

       ## Logging Metadata

       - **Attempt:** {attempt_number} of max 3
       - **Log Path:** .working/colony/{project}/logs/{task-id}_LOG.md
       - **Start Time:** {current ISO timestamp}

       You MUST write an execution log to the log path above.
       See the Execution Logging section in your instructions.

       ## Your Task

       {Content of tasks/T{NNN}.md}

       ## Project Context (follow these rules)

       {Content of context.md}

       ## Relevant Source Files

       ### {filename1}
       ```
       {content}
       ```

       ═══════════════════════════════════════════════════════════

       Complete this task and respond with either:

       DONE: {summary}
       Files changed: {list}
       Verification output: {test results}

       OR

       STUCK: {reason}
       Attempted: {what you tried}
       Need: {what would unblock}
       ```

    e) If running multiple tasks in parallel:
       - Spawn all sub-agents together using multiple Task calls
       - Wait for all to complete
       - Process results together

    ┌─────────────────────────────────────────────────────────────┐
    │  5.6: Process Results                                       │
    └─────────────────────────────────────────────────────────────┘

    For each completed sub-agent:

    **If DONE:**

    Spawn inspector sub-agent:

    ```
    Task: Verify this task was completed correctly.

    ═══════════════════════════════════════════════════════════
    VERIFICATION REQUEST
    ═══════════════════════════════════════════════════════════

    ## Logging Metadata

    - **Attempt:** {attempt_number}
    - **Log Path:** .working/colony/{project}/logs/{task-id}_LOG.md

    You MUST append your verification results to the log above.
    See the Verification Logging section in your instructions.

    ## Task to Verify
    {Content of tasks/T{NNN}.md}

    ## Worker's Claim
    {The DONE response}

    ## Acceptance Criteria
    {From task file}

    ═══════════════════════════════════════════════════════════

    Run the verification command and check each criterion.
    Respond with:

    PASS
    Criteria verified: {evidence for each}

    OR

    FAIL
    Issues: {what's wrong}
    Suggestion: {how to fix}
    ```

    - If PASS → proceed to artifact validation (5.6a)
    - If FAIL → check attempts:
      - attempts < 3 → status = "pending" (will retry)
      - attempts >= 3 → status = "failed", ask for human intervention

    ┌─────────────────────────────────────────────────────────────┐
    │  5.6a: Artifact Validation (MANDATORY)                      │
    └─────────────────────────────────────────────────────────────┘

    **CRITICAL: Before marking ANY task complete, validate artifacts exist.**

    This step is NON-NEGOTIABLE. Never trust agent claims without proof.

    1. **Verify log file exists:**
       ```bash
       ls -la .working/colony/{project}/logs/{task-id}_LOG.md
       ```
       - If missing → DO NOT mark complete, log error, retry task

    2. **For VISUAL tasks, verify screenshots exist:**
       ```bash
       # Count screenshots matching task prefix (stored with project)
       ls -la .working/colony/{project}/screenshots/{IntegrationName}_*.png 2>/dev/null | wc -l
       ```
       - Compare count to expected (from task file's screenshot list)
       - If fewer than expected → DO NOT mark complete, log which are missing

    3. **If artifacts missing:**
       ```
       ⚠️ Artifact validation FAILED for {task-id}

       Missing artifacts:
       - [ ] Log file: .working/colony/{project}/logs/{task-id}_LOG.md
       - [ ] Screenshots: Expected 10, found 2

       The worker claimed DONE but didn't produce required outputs.
       Retrying task...
       ```
       - Reset status to "pending"
       - Increment attempts
       - Re-run with explicit reminder about artifacts

    4. **Only after ALL artifacts verified:**
       - status = "complete"
       - Log success

    **This validation must run for EVERY task, EVERY time, with no exceptions.**

    **If PARTIAL:**

    The worker completed some but not all acceptance criteria. This often
    happens when VISUAL: items couldn't be verified due to browser unavailability.

    Still spawn inspector to check the completed portions:

    ```
    Task: Verify the completed portions of this task.

    ═══════════════════════════════════════════════════════════
    VERIFICATION REQUEST (PARTIAL COMPLETION)
    ═══════════════════════════════════════════════════════════

    ## Logging Metadata

    - **Attempt:** {attempt_number}
    - **Log Path:** .working/colony/{project}/logs/{task-id}_LOG.md

    ## Task to Verify
    {Content of tasks/T{NNN}.md}

    ## Worker's PARTIAL Response
    {The PARTIAL response - shows completed and not-completed items}

    ## Your Job
    1. Verify the items the worker marked as completed
    2. Acknowledge the incomplete items
    3. If worker couldn't do VISUAL: items, you should try with browser

    ═══════════════════════════════════════════════════════════
    ```

    After inspector returns:
    - If inspector PASS (including completing VISUAL: items) → status = "complete"
    - If inspector FAIL → check attempts, retry or escalate
    - If inspector also couldn't complete VISUAL: → escalate to orchestrator

    **Orchestrator handling of unverified VISUAL: items:**

    If both worker and inspector couldn't verify VISUAL: items:
    1. The orchestrator (you) should attempt browser verification directly
    2. If all VISUAL: items pass → mark task complete
    3. If any VISUAL: items fail → task needs fixes, retry

    **If STUCK:**

    - Check attempts:
      - attempts < 3 → status = "pending" (will retry)
      - attempts >= 3 → status = "blocked", ask for human intervention

    **Human Intervention (after 3 failed attempts):**

    ```
    ⚠️ Task {task-id} has failed 3 times.

    **Last error:**
    {latest failure reason from inspector or STUCK message}

    **Execution log:** .working/colony/{project}/logs/{task-id}_LOG.md

    Options:
    • "retry T{NNN}" - Try again (maybe after manual fix)
    • "skip T{NNN}" - Mark as skipped, continue with others
    • "show T{NNN}" - View full task and log details
    • Fix manually and "mark T{NNN} complete"
    ```

    ┌─────────────────────────────────────────────────────────────┐
    │  5.7: Update Blocked Dependencies                           │
    └─────────────────────────────────────────────────────────────┘

    For any task whose depends_on includes a failed/blocked task:
    - status = "blocked"
    - blocked_by = [the failed task]
    - Print: "T{NNN} blocked by T{XXX}"

    ┌─────────────────────────────────────────────────────────────┐
    │  5.8: Progress Report                                       │
    └─────────────────────────────────────────────────────────────┘

    After each batch:

    ```
    ────────────────────────────────────────────────
    ## Progress: {project-name}

    ████████████░░░░░░░░ 60% (12/20)

    **This round:**
    ✅ T003: Add authentication - PASSED
    ✅ T004: Add sessions - PASSED
    ❌ T005: Add OAuth - FAILED (missing credentials)

    **Parallelization:** Ran 3 tasks concurrently (different files)

    **Next batch:** T006, T007, T008 (ready, can parallelize)
    **Concurrency:** 5 agents (say "set concurrency to N" to change)
    ────────────────────────────────────────────────
    ```

    ┌─────────────────────────────────────────────────────────────┐
    │  5.9: Git Commit (if strategy requires)                     │
    └─────────────────────────────────────────────────────────────┘

    **SKIP this step if `state.json.git.strategy` is `"not_applicable"`.**

    Check commit_strategy from state.json.git:

    **If "task":** Commit after each verified task
    ```bash
    git add -A
    git commit -m "{type}({project}): {task-name}

    {brief description of what was done}

    Task: {task-id}
    Co-Authored-By: Claude <noreply@anthropic.com>"
    ```

    **If "phase":** Commit when all tasks in a phase complete
    - Track current phase (from parallel_group)
    - When phase completes (all tasks in group done):
    ```bash
    git add -A
    git commit -m "{type}({project}): {phase-description}

    Completed tasks:
    - {T001}: {summary}
    - {T002}: {summary}

    Co-Authored-By: Claude <noreply@anthropic.com>"
    ```

    **If "end":** No commits during execution (commit at end)

    **If "manual":** Prompt user after each phase:
    ```
    Phase "{phase-name}" complete. Ready to commit?
    • Show changes (git diff --stat)
    • Commit now
    • Skip this commit
    • Edit commit message
    ```

    **User overrides:**
    - "commit now" → Force immediate commit of current changes
    - "skip commit" → Don't commit this phase
    - "show changes" → Display git diff --stat

    **Record commit in state.json:**
    ```json
    "commits": [
      {"sha": "abc123", "phase": "setup", "tasks": ["T001"], "time": "..."},
      {"sha": "def456", "phase": "features", "tasks": ["T002", "T003"], "time": "..."}
    ]
    ```

    ┌─────────────────────────────────────────────────────────────┐
    │  5.10: CHECKPOINT - Classify User Response                  │
    └─────────────────────────────────────────────────────────────┘

    **STOP. Before responding to user input, run this classification:**

    Read the user's message. Which category?

    ┌─────────────────────────────────────────────────────────────┐
    │ Category A: INFORMATIONAL QUESTION                          │
    │ Examples: "What does X do?", "Why did Y happen?"            │
    │ Action: Answer briefly, then continue execution             │
    └─────────────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────┐
    │ Category B: EXECUTION COMMAND                               │
    │ Examples: "pause", "set concurrency 3", "skip T005"         │
    │ Action: Execute the command, update state, acknowledge      │
    └─────────────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────┐
    │ Category C: IMPLEMENTATION FEEDBACK                         │
    │ Examples: "I get a 404", "Fix X", "This shouldn't be        │
    │           committed", "Can you also add...", "There's an    │
    │           error when..."                                    │
    │                                                             │
    │ !! CRITICAL: This requires worker spawn                     │
    │                                                             │
    │ Action: DO NOT debug. DO NOT edit files.                    │
    │         -> Go directly to Step 5.11 (Handle User Feedback)  │
    │         -> Follow the worker spawn procedure                │
    └─────────────────────────────────────────────────────────────┘

    **If you caught yourself about to read a file or run a build:**
    YOU ARE IN CATEGORY C. Stop immediately. Spawn a worker instead.

    **Classified as Category C?** Proceed to Step 5.11 now.
    **Otherwise?** Continue to Step 5.10a below.

    ┌─────────────────────────────────────────────────────────────┐
    │  5.10a: Continue or Pause (Non-Implementation)              │
    └─────────────────────────────────────────────────────────────┘

    After each batch, check if user wants to:
    - Continue (default, just proceed)
    - Pause ("pause" or "stop")
    - Adjust concurrency ("set concurrency to 3")
    - Skip a task ("skip T005")
    - Get details ("show T005 error")
    - Commit now ("commit now")
    - Show changes ("show changes")

    ┌═════════════════════════════════════════════════════════════┐
    ║  5.11: Handle User Feedback                                 ║
    ║                                                             ║
    ║  !! THIS IS THE RULE YOU ALWAYS VIOLATE                     ║
    ║  !! READ EVERY WORD BEFORE RESPONDING                       ║
    └═════════════════════════════════════════════════════════════┘

    ═══════════════════════════════════════════════════════════════
    CRITICAL RULE - ENFORCED WITHOUT EXCEPTION
    ═══════════════════════════════════════════════════════════════

    **The orchestrator coordinates. Workers implement. NEVER both.**

    You are about to receive user feedback that requires implementation work.

    DO NOT:
      - Read files to debug issues
      - Edit files to fix problems
      - Run builds or tests yourself
      - Make "quick fixes" inline
      - Investigate errors yourself

    Even if it seems faster. Even if it's "just one file". Even if you
    already know the fix. STOP. Spawn a worker.

    WHY THIS MATTERS:

    Your context is precious. Right now it contains:
      + Project state and task dependencies
      + Execution history and parallelization decisions
      + Git strategy and commit tracking
      + Overall coordination state

    If you implement inline, your context fills with:
      - File contents (hundreds of lines)
      - Error messages and stack traces
      - Multiple edit attempts
      - Build outputs and logs

    After 3-4 feedback cycles, you'll lose track of the project.
    You'll miss dependencies. You'll make coordination errors.

    Workers have FRESH context. They're designed for implementation.
    You're designed for coordination. Stay in your lane.

    ═══════════════════════════════════════════════════════════════

    ### Feedback Detection

    Recognize feedback that requires implementation work:

    | Triggers Work | Does NOT Trigger Work |
    |---------------|----------------------|
    | "I get a 404" | "Looks good" |
    | "Why is X in git?" (implies problem) | "Continue" |
    | "This shouldn't be committed" | "Show me the diff" |
    | "Fix X" / "Change Y" | "What does X do?" (pure info) |
    | "There's an error when..." | "Pause" / "Stop" |
    | "Can you also add..." | "Set concurrency to N" |

    **If feedback is informational only** (e.g., "What does X do?"):
    - Answer the question briefly
    - Continue with execution

    **If feedback requires implementation work**, proceed to the next section.

    ### Feedback Aggregation

    When implementation feedback is detected:

    1. **Parse the feedback into discrete items:**
       ```
       I see feedback that needs action:
       • 404 on dev server
       • .next folder shouldn't be in git
       • Conversion script lifecycle unclear
       ```

    2. **Ask if there's more:**
       ```
       Any other feedback to add before I proceed?
       ```

    3. **Wait for response** - user may add more items or say "that's all"

    ### Size Assessment

    Assess the overall scope of the feedback:

    **Small task indicators:**
    - Single config change (e.g., add line to .gitignore)
    - One-file fix
    - Clear, mechanical change
    - No design decisions needed

    **Large task indicators:**
    - Multiple files involved
    - Debugging required (root cause unclear)
    - Design decisions needed
    - Multiple discrete issues

    ### Present Options

    **For large/significant feedback:**

    ```
    📋 Feedback detected that needs action:
    • {item 1}
    • {item 2}
    • {item 3}

    How would you like me to handle this?

    1. **Add subtasks** → I'll create T{last}.1, T{last}.2, etc., execute with full
       worker + inspector verification, tracked in state.json

    2. **Spawn worker** → One worker handles all items, inspector verifies, logs created
    ```

    **For small/trivial feedback:**

    ```
    📋 Feedback detected that needs action:
    • {single item}

    This looks like a small fix. How would you like me to handle this?

    1. **Add subtask** → I'll create T{last}.1, execute with full verification

    2. **Spawn worker** → One worker handles this quickly
       - Skip inspector verification? (small fix, probably overkill)
       - Or verify anyway? (safer)
    ```

    ### Option 1: Add Subtasks

    Create formal subtask files that integrate into the execution flow.

    **Subtask ID Format:** `T{parent}.{sequence}`
    - Parent = last completed task ID (e.g., T009)
    - Sequence = 1, 2, 3...
    - Examples: T009.1, T009.2, T009.3

    **Create subtask file:**

    Write to `.working/colony/{project}/tasks/T{parent}.{seq}.md`:

    ```markdown
    # T{parent}.{seq}: {Short title from feedback}

    ## Context & Why

    This subtask addresses user feedback after {parent task/phase} completion.

    **User's feedback:** "{exact quote from user}"

    ## Acceptance Criteria

    - [ ] {Derived from feedback item}
    - [ ] Changes verified working

    ## Design Intent

    - Address the user's concern as stated
    - Minimal changes to fix the issue
    - Don't introduce new problems

    ## Verification

    ```bash
    {Appropriate verification command}
    ```

    ## Files

    - {Files likely to be involved, if known}
    ```

    **Update state.json:**

    Add subtasks to the tasks array:

    ```json
    {
      "id": "T009.1",
      "name": "{title}",
      "status": "pending",
      "attempts": 0,
      "depends_on": [],
      "is_subtask": true,
      "parent_task": "T009",
      "created_from": "user_feedback"
    }
    ```

    **Execution:**
    - Subtasks run immediately (next batch)
    - Full worker + inspector flow
    - Logs created at `logs/T009.1_LOG.md`
    - Shown in progress reports as subtasks
    - Normal human checkpoint at Step 5.10 after completion
    - User can provide more feedback, which creates more subtasks

    ### Option 2: Spawn Worker

    For quick handling without formal task tracking.

    **Always create a log file:**

    Log path: `.working/colony/{project}/logs/FEEDBACK_{timestamp}_LOG.md`

    **Spawn worker with aggregated feedback:**

    ```
    Task: Address user feedback from execution checkpoint.

    ═══════════════════════════════════════════════════════════
    FEEDBACK TASK
    ═══════════════════════════════════════════════════════════

    ## Logging Metadata

    - **Log Path:** .working/colony/{project}/logs/FEEDBACK_{timestamp}_LOG.md
    - **Start Time:** {current ISO timestamp}

    You MUST write an execution log to the log path above.

    ## User Feedback Items

    The user provided the following feedback after reviewing completed work:

    1. {feedback item 1}
    2. {feedback item 2}
    3. {feedback item 3}

    ## Your Job

    1. Investigate each item
    2. Implement fixes
    3. Verify fixes work
    4. Write execution log
    5. Return DONE or STUCK

    ## Project Context

    {Content of context.md}

    ═══════════════════════════════════════════════════════════

    Complete this work and respond with:

    DONE: {summary of what was fixed}
    Files changed: {list}
    Verification: {how you verified each fix}

    OR

    STUCK: {reason}
    Attempted: {what you tried}
    Need: {what would unblock}
    ```

    **Inspector Decision:**

    - **Large feedback (default):** Always spawn inspector to verify
    - **Small feedback (user chose to skip):** Skip inspector, trust worker result

    If inspector runs, use same verification flow as regular tasks.

    **After completion:**

    ```
    ✅ Feedback addressed

    Items fixed:
    • {item 1}: {how fixed}
    • {item 2}: {how fixed}

    Log: .working/colony/{project}/logs/FEEDBACK_{timestamp}_LOG.md

    Please review the fixes. Options:
    • "continue" - Resume execution
    • "show changes" - View git diff
    • {more feedback} - I'll handle it the same way
    ```

    **IMPORTANT:** Always pause for user review after feedback is addressed.
    Do NOT automatically continue - the user needs to verify the fix.

    ### CRITICAL: Never Implement Inline

    **FORBIDDEN actions when receiving feedback:**
    - Reading files to debug
    - Editing files directly
    - Running builds or tests
    - Making "quick fixes"

    **REQUIRED actions:**
    - Parse feedback into items
    - Assess size
    - Present options
    - Spawn worker(s) based on user choice

    **Why this matters:**

    If you debug inline, your context accumulates:
    - File contents you read
    - Error messages you encountered
    - Multiple edit attempts
    - Build outputs

    After 3-4 feedback cycles, your context is polluted with implementation
    details instead of coordination state. You'll lose track of the overall
    project, miss dependencies, and make coordination errors.

    Workers have fresh context. Use them.

    Then loop back to 5.1

END REPEAT
```

## Step 6: Final Summary

```markdown
════════════════════════════════════════════════════════════════
## Execution Complete: {project-name}

**Total:** {total} tasks
**✅ Completed:** {count}
**❌ Failed:** {count}
**🚫 Blocked:** {count}

{IF git.strategy is "active":}

### Git Summary
- Branch: `{branch-name}`
- Commits made: {count}
- Latest commit: `{sha}` - {message}

{If commit_strategy == "end" and changes exist:}
**Uncommitted changes ready for review:**
```
git diff --stat
{output}
```

Suggested commit:
```bash
git add -A && git commit -m "feat({project}): {summary of all work}

{list of completed tasks}

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Commits Made
| Commit | Phase | Tasks |
|--------|-------|-------|
| abc123 | setup | T001 |
| def456 | features | T002, T003, T004 |

{IF git.strategy is "not_applicable":}

### Git Summary
Not applicable - this was a research/documentation project.
All outputs saved to `.working/colony/{project}/`.

### Parallelization Stats
- Average batch size: {n} tasks
- Total batches: {n}
- Time saved (estimated): {parallel vs serial estimate}

### Completed Tasks
- T001: {name} ✅
- T002: {name} ✅
...

### Failed Tasks (need attention)
| Task | Name | Error | Attempts |
|------|------|-------|----------|
| T005 | OAuth setup | Missing API keys | 2 |

### Blocked Tasks
| Task | Blocked By |
|------|------------|
| T006 | T005 |

### Next Steps
{If all complete: "All tasks completed successfully!"}
{If failures: "Fix failed tasks manually or update definitions and re-run"}
{If on feature branch: "Ready to create PR: gh pr create"}
════════════════════════════════════════════════════════════════
```

## Step 7: Generate Report (MANDATORY)

**CRITICAL: You MUST generate a comprehensive report at the end of every run.**

This is NOT optional. The user should never have to ask "where is the report?"

Write to: `.working/colony/{project}/REPORT.md`

### Report Template

```markdown
# Colony Report: {project-name}

**Generated:** {ISO timestamp}
**Branch:** {branch-name}
**Duration:** {estimated total time}

---

## Executive Summary

**Original Request:** {one-line summary from resources/original-brief.md}
**Outcome:** {COMPLETE | PARTIAL | FAILED}
**Tasks:** {total} total → {passed} passed, {with_issues} with issues, {blocked} blocked

---

## Results by Task

| Task | Name | Status | Attempts | Notes |
|------|------|--------|----------|-------|
| T001 | {name} | PASS | 1 | - |
| T007 | {name} | PASS_WITH_BUGS | 1 | Headers persistence bug |
| T019 | {name} | BLOCKED | 1 | Feature flag required |
...

---

## Findings & Observations

### Critical Issues ({count})

{Issues that MUST be fixed - bugs, broken functionality}

1. **{Issue title}** - {Task ID}
   - Description: {what's wrong}
   - Impact: {who/what is affected}
   - Evidence: {screenshot or log reference}

### Recurring Patterns ({count})

{Issues that appear across multiple tasks - likely systemic}

1. **{Pattern name}** - Affects {T007, T012, T013, T014}
   - Description: {what the pattern is}
   - Likely cause: {hypothesis}

### Unexpected Obstacles ({count})

{Things that blocked progress unexpectedly}

1. **{Obstacle}** - {Task ID}
   - What happened: {description}
   - How resolved: {or "unresolved - requires X"}

### Areas of Ambiguity ({count})

{Places where requirements were unclear}

1. **{Ambiguity}** - {Task ID}
   - Question: {what was unclear}
   - Assumption made: {what the agent decided}
   - Needs clarification: {yes/no}

---

## Agent Self-Assessment

### Effectiveness Rating: {percentage}%

**What went well:**
- {positive observation}
- {another positive}

**What could have been better:**
- {area for improvement}
- {another area}

**Confidence in results:**
- High confidence: {X}/{total} tasks
- Medium confidence: {Y}/{total} tasks (partial verification)
- Low confidence: {Z}/{total} tasks (blocked/failed)

### Did we achieve the original goal?

{Honest assessment of whether the brief's objectives were met}

---

## Recommended Actions

### Immediate (bugs found during verification)

1. [ ] **{Action}** - {Priority: P1/P2/P3}
   - Related tasks: {T007, T012}
   - Suggested fix: {brief description}

### Follow-up Tasks

1. [ ] **{Task description}**
   - Why: {reason this is needed}
   - Blocked by: {if applicable}

### Questions for Human Decision

1. **{Question}**
   - Context: {relevant info}
   - Options: {A or B}

---

## Artifacts Inventory

| Type | Count | Location |
|------|-------|----------|
| Task logs | {count} | `logs/` |
| Screenshots | {count} | `screenshots/` |
| Original brief | 1 | `resources/original-brief.md` |

**Total artifacts:** {count} files

---

## Execution Statistics

- **Execution time:** {duration}
- **Average per task:** {time}
```

### Report Generation Rules

1. **Always generate** - Even for partial/failed runs
2. **Be honest** - Don't minimize issues or inflate success
3. **Be specific** - Link issues to specific tasks and evidence
4. **Be actionable** - Every issue should have a clear next step
5. **Self-assess critically** - Rate effectiveness honestly

### After Writing Report

Confirm to user:
```
📋 Report generated: .working/colony/{project}/REPORT.md

Summary:
- {X} tasks completed, {Y} with issues, {Z} blocked
- {N} critical issues found
- {M} follow-up actions recommended

View full report: cat .working/colony/{project}/REPORT.md
```

## Recovery

If interrupted:
1. Re-run `/colony-run`
2. Reads state.json
3. Tasks "running" for >30 minutes reset to "pending"
4. Continues from where it left off

## User Commands During Execution

| Command | Effect |
|---------|--------|
| "pause" / "stop" | Stop after current batch |
| "autonomous" / "auto" | Switch to autonomous mode |
| "interactive" | Switch back to interactive mode |
| "set concurrency to N" | Adjust parallel agents |
| "skip T005" | Mark task as skipped, continue |
| "show T005" | Display task details and error |
| "retry T005" | Reset failed task to pending |
| "serialize" | Set concurrency to 1 |
| "commit now" | Force commit of current changes |
| "skip commit" | Skip the current phase commit |
| "show changes" | Display git diff --stat |
| {feedback about issues} | Triggers feedback handling (Step 5.11) |
| "add subtasks" | When prompted, create formal subtasks |
| "spawn worker" | When prompted, use single worker for feedback |
| "skip inspector" | When prompted for small tasks, skip verification |

## Important Rules

1. **NEVER skip verification** - every DONE must be verified
2. **NEVER mark complete without PASS** - inspector must confirm
3. **NEVER mark complete without artifacts** - log file MUST exist, screenshots MUST match count
4. **Update state.json BEFORE spawning** - crash recovery
5. **Re-read state.json every iteration** - you are stateless
6. **Ask when parallelization is uncertain** - correctness > speed
7. **Respect resource constraints** - browser, database, APIs
8. **Check Git state before starting** - refuse if working tree dirty (only if `git.strategy` is `"active"`)
9. **Follow commit strategy** - phase/task/end/manual as configured (only if `git.strategy` is `"active"`)
10. **Record commits in state.json** - for recovery and summary (only if `git.strategy` is `"active"`)
11. **Task runner is commit exception** - explicit permission via /colony-run (only if `git.strategy` is `"active"`)
12. **NEVER implement inline when receiving feedback** - always spawn workers (see Step 5.11)

## Critical: Artifact Validation Is Non-Negotiable

**The #1 failure mode is agents claiming DONE without producing artifacts.**

You MUST run artifact validation (Step 5.6a) for EVERY task:
- Check log file exists: `ls -la .working/colony/{project}/logs/{task-id}_LOG.md`
- Check screenshots exist (for VISUAL tasks): `ls .working/colony/{project}/screenshots/{prefix}_*.png`

If artifacts are missing:
- DO NOT mark complete
- Log the failure
- Retry the task with explicit artifact reminder

**Never trust an agent's word. Trust the filesystem.**

## Critical: Report Generation Is Non-Negotiable

**The #2 failure mode is completing tasks without generating a report.**

You MUST generate REPORT.md (Step 7) at the end of EVERY run:
- Even if some tasks failed
- Even if run was interrupted
- Even if user didn't explicitly ask for it

The user should NEVER have to ask "where is the report?"

## Critical: Never Implement Inline

**The #3 failure mode is implementing fixes directly when receiving user feedback.**

When users provide feedback that requires implementation work, you MUST:
1. Parse the feedback into discrete items
2. Assess the size (small vs large)
3. Present options (add subtasks OR spawn worker)
4. Spawn worker(s) based on user choice

You MUST NOT:
- Read files to debug the issue
- Edit files directly
- Run builds or tests
- Make "quick fixes" yourself

**Why this matters:**

Your context is precious. It contains:
- Project state and task status
- Dependency relationships
- Parallelization decisions
- Execution history

If you start debugging inline, your context fills with:
- File contents
- Error messages
- Multiple edit attempts
- Build outputs

After 3-4 feedback cycles, you'll lose track of the project. Workers have
fresh context specifically for implementation work. Use them.

**The orchestrator coordinates. Workers implement.**
