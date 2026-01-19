---
name: colony-plan
description: Plan tasks from a brief - interactive task decomposition
version: 1.2.0
status: active

# Claude Code command registration
allowed-tools: Read, Write, Bash, Grep, Glob, AskUserQuestion
---

# Plan Tasks

Create a colony project by decomposing a brief into executable tasks.

## Step 0: Verify CLI

```bash
# Verify colony CLI is available (Claude Code's Bash doesn't inherit user PATH)
[[ -x "${CLAUDE_PLUGIN_ROOT}/bin/colony" ]] && echo "colony CLI ready" || echo "ERROR: colony CLI not found"
```

## Step 1: Find Brief

```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony config init 2>/dev/null || true

# Check conventional locations first (priority order)
echo "=== .working/ (primary) ===" && ls -1 .working/*.md 2>/dev/null || true
echo "=== docs/ ===" && ls -1 docs/*.md 2>/dev/null || true
echo "=== root ===" && ls -1 ./*.md 2>/dev/null | grep -v -E '^\./(README|CHANGELOG|LICENSE)' || true
```

**Priority order:**
1. `$ARGUMENTS` - if user specified a path, use it
2. `.working/*.md` - conventional location for briefs
3. `docs/*.md` - documentation folder
4. Root `.md` files (excluding README, CHANGELOG, LICENSE)

If multiple candidates: ask user. If none: ask for path or inline description.

## Step 2: Generate Project Name

Derive from brief filename or H1 heading, slugified. Example: `INTEGRATION_BRIEF.md` → `integration-brief`

```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state list
```

If project exists: ask to continue, create new version, or overwrite.

## Step 3: Task Type Assessment

Determine if project needs Git tracking.

**Needs Git when:**
- Brief mentions: implement, build, create feature, fix bug, refactor
- Tasks modify tracked source files
- Brief mentions: PR, pull request, merge

**No Git when:**
- Research, analyze, investigate, document
- All outputs go to `.working/`
- Brief says "no code changes"

If uncertain, ask user.

## Step 4: Git Strategy (if applicable)

Skip if task type is research/documentation.

```bash
git status --porcelain
git branch --show-current
```

If dirty: STOP, ask user to commit/stash.

**Configure:**
- Branch: feature branch or current
- Commits: phase/task/end/manual
- Style: conventional commits

## Step 5: Visual/Browser Detection

Scan brief for visual verification indicators:
- "visual verification", "screenshot", "browser testing"
- "UI testing", "form verification", "end-to-end"

If found: set `verification_type: visual`, prefix criteria with `VISUAL:`.

## Step 6: Assess Complexity

After analyzing the brief, estimate task count before decomposition.

<critical>
This step is MANDATORY. You must estimate task count and follow the decision tree below.
Skipping this step leads to either over-decomposition (too many small tasks) or under-decomposition (tasks too large to parallelize).
</critical>

**If estimated tasks ≤ 6:** Proceed with quality-first approach (atomic tasks).

**If estimated tasks > 6:** You MUST ask user about atomicity vs speed using AskUserQuestion:

```
This brief is substantial. I estimate ~{N} tasks across {M} milestones.

How should I balance atomicity vs execution speed?

1. **Quality-first** (recommended for production)
   - Atomic tasks, each independently verified
   - Easier debugging, better recovery from failures
   - ~{N} tasks, ~{rounds} execution rounds

2. **Balanced**
   - Consolidate tightly-coupled tasks
   - Good middle ground
   - ~{N*0.7} tasks

3. **Speed-first** (for prototyping/experiments)
   - Maximize consolidation
   - Faster but larger blast radius on failure
   - ~{N*0.5} tasks
```

Use AskUserQuestion. Default to Quality-first if user doesn't respond.

## Step 7: Design Parallel Execution

**Goal:** Minimize sequential chains, maximize concurrent execution.

**Process:**
1. Identify tasks with NO dependencies (Round 1 candidates)
2. For each subsequent task, depend on minimum required predecessors
3. Avoid unnecessary chains (T001 → T002 → T003 when T002/T003 are independent)
4. Group tasks touching different files - they can parallelize

**Output execution rounds estimate:**

```
Execution Rounds (concurrency=5):
Round 1: T001, T003 (no deps, different modules)
Round 2: T002, T004 (deps satisfied, different files)
Round 3: T005, T006 (parallel integration)
Round 4: T007
Round 5: T008, T009 (tests + docs, independent)

Total: 5 rounds for 9 tasks
Sequential would be: 9 rounds
Parallelization benefit: 44% faster
```

**Anti-pattern to avoid:**
```
# BAD: Unnecessary chain
T001 → T002 → T003 → T004  (serial)

# GOOD: Parallel where possible
T001 ─┬→ T002
      └→ T003 → T004
```

## Step 8: Identify Milestones

Milestones are natural review points where work can be paused, reviewed, and approved before continuing. They help break large projects into reviewable chunks.

**Auto-detect milestones from:**
- Phases explicitly mentioned in brief ("Phase 1", "Stage 1", "Step 1")
- Logical boundaries (infrastructure → implementation → testing)
- Git strategy hints (if brief mentions multiple PRs or branches)
- Task dependencies that create natural groupings

**Milestone structure:**
```json
{
  "id": "M1",
  "name": "Infrastructure Setup",
  "tasks": ["T001", "T002", "T003"],
  "checkpoint": "review"
}
```

**Checkpoint types:**
- `review` (default) - Pause for human approval before continuing
- `commit` - Auto-commit at milestone boundary, then continue
- `branch` - Create new branch for next milestone
- `pr` - Create PR for completed milestone

**Behavior:**
- If milestones are obvious from brief: state them and proceed (user can challenge)
- If milestones are unclear: suggest milestones and confirm
- If brief is small (<10 tasks): single milestone is fine
- Don't over-ask - let user challenge after if they disagree

**Default checkpoint:** `review` (pause and ask for approval in non-autonomous mode)

## Step 9: Create Project Directories

Create the directory structure (but NOT state.json yet - that comes in Step 12 with bulk import):

```bash
working_dir="${CLAUDE_PLUGIN_ROOT}/../../../.working"  # Or use colony working-dir
mkdir -p .working/colony/{project-name}/{tasks,logs,resources,screenshots}
```

This creates:
```
.working/colony/{project}/
├── tasks/
├── logs/
├── resources/
└── screenshots/
```

**Note:** state.json is created in Step 12 via `--from plan.json` with all tasks and milestones.

## Step 10: Write Context File

Write `.working/colony/{project}/context.md`:

```markdown
# Project Context: {project-name}

Captured: {timestamp}

## Task Type
{implementation | research | documentation}

## Git Strategy
{Branch, commit frequency, or "not applicable"}

## Verification Type
{code-only | visual | mixed}

## Milestones
| ID | Name | Tasks | Checkpoint |
|----|------|-------|------------|
| M1 | {name} | T001-T003 | review |
| M2 | {name} | T004-T007 | review |

## Project Rules
{From CLAUDE.md if exists}

## Parallelization
- Can parallelize: {list with reasoning}
- Must serialize: {list with reasoning}

## Tech Stack
{From package.json, etc.}

## Decisions Log
{Orchestrator will append decisions here during execution}

## Feedback History
{Orchestrator will append user feedback and resulting subtasks here}
```

### Context Split Rule

Keep context.md unified UNLESS both conditions are met:
1. **Optional for ≥50% of tasks** - Extended content isn't needed by at least half the tasks
2. **≥30 lines** - Big enough to matter for token efficiency

If both met: Create `context-extended.md` and reference it from context.md.

## Step 11: Decompose into Tasks

<critical>
Each task file must be SELF-CONTAINED. Workers have NO memory of:
- The original brief
- Other tasks
- Your conversation history

PRESERVE in each task:
- User quotes showing preferences
- Design philosophy and intent
- What to AVOID
- How task relates to broader goal

CONDENSE (don't remove):
- Lengthy background

OMIT:
- Information about other tasks
</critical>

### Task Sizing

**Goal: Minimize task count while maintaining parallelization opportunities.**

**Why this matters:**
- Each task has fixed overhead: worker spawn (~30s), inspector verification (~30s), state management
- 9 tasks vs 6 tasks = 50% more overhead before any real work happens
- Granular tasks also increase failure surface area (more chances for lint errors, retry loops)
- The benefit of splitting is parallelization—if tasks can't run in parallel, combining them is pure gain

**Decomposition principles:**
1. **One module = one task** - Don't split types/constants/utils into separate tasks
2. **Split only for parallelization** - If two things can't run in parallel, combine them
3. **Split for different expertise** - Tests vs implementation vs docs can be separate

**Right-sizing test:** For each task, ask "could this be combined with an adjacent task without losing parallelization?" If yes, combine.

**Examples:**
- ✅ "Create protocol module" (includes types, constants, parser, utils)
- ❌ "Create types" + "Create constants" + "Create parser" + "Create utils" (4 tasks for one module)

- ✅ "Migrate auth module to new framework" (one coherent unit)
- ❌ "Update imports" + "Change function signatures" + "Update tests" (if all in same files)

### Task File Format

Write `.working/colony/{project}/tasks/T{NNN}.md`:

```markdown
# Task T{NNN}: {Short Name}

## Status
pending

## Why This Task
{Specific reason this task exists - not project background}

## What To Do
{Concrete deliverable - be specific}

## What To Avoid
{Task-specific pitfalls, anti-patterns}

## Files
- {path/to/file1}

## Acceptance Criteria
- [ ] {Specific, verifiable}

## Verification Command
```bash
{command - see guidelines below}
```

## Dependencies
{T001 or "None"}
```

**OMIT from task files** (already in context.md which workers receive):
- Tech stack details
- Git strategy
- Coding standards
- General project background

### Verification Command Guidelines

Verification must be achievable when the task completes. Don't reference artifacts that don't exist yet.

| Task Type | Verification | Example |
|-----------|--------------|---------|
| New module | TypeScript compiles | `npx tsc --noEmit` |
| New function | Module exports it | `node -e "require('./src/mod').fn"` |
| Integration | Build succeeds | `npm run build` |
| Integration | Existing tests pass | `npm test` |
| Test creation | New tests pass | `npm test -- --grep "pattern"` |
| Documentation | File has content | `test -s README.md` |

**Anti-pattern:** Don't reference tests that don't exist yet. If T001 creates a parser and T008 creates tests, T001's verification should be `npx tsc --noEmit`, not `npm test -- --grep parser`.

## Step 12: Write Plan File and Initialize State

Write `.working/colony/{project}/plan.json` with all tasks, milestones, and config:

```json
{
  "total_tasks": 9,
  "tasks": {
    "T001": {"status": "pending", "attempts": 0, "milestone": "M1"},
    "T002": {"status": "pending", "attempts": 0, "milestone": "M1", "depends_on": ["T001"]},
    "T003": {"status": "pending", "attempts": 0, "milestone": "M2"}
  },
  "milestones": [
    {"id": "M1", "name": "Infrastructure", "tasks": ["T001", "T002"], "checkpoint": "review", "status": "pending"},
    {"id": "M2", "name": "Implementation", "tasks": ["T003"], "checkpoint": "review", "status": "pending"}
  ],
  "git": {
    "strategy": "active",
    "branch": "feature/my-feature",
    "commit_strategy": "phase"
  }
}
```

Then initialize with bulk import (one command instead of many):

```bash
${CLAUDE_PLUGIN_ROOT}/bin/colony state init {project} --from .working/colony/{project}/plan.json
```

This is atomic - either all state is created or none. Reduces agent overhead and errors.

## Step 13: Copy Brief

```bash
cp {brief-path} .working/colony/{project}/resources/original-brief.md
```

## Step 14: Summary

```markdown
## Project Created: {project-name}

Location: .working/colony/{project}/
Tasks: {count}
Milestones: {milestone_count}
Type: {implementation | research}

### Milestones
| Milestone | Tasks | Checkpoint |
|-----------|-------|------------|
| M1: {name} | T001-T003 | review |
| M2: {name} | T004-T007 | review |

### Execution Plan

```
Estimated rounds (concurrency=5):
Round 1: T001, T003 (parallel, no deps)
Round 2: T002, T004 (parallel, deps satisfied)
...
Total: {X} rounds for {Y} tasks ({Z}% parallelization benefit)
```

**M1 - {name}:**
- T001: {name}
- T002, T003 (parallel)

**M2 - {name}:**
- T004: {name}
- T005, T006, T007 (parallel)

### Next Steps
1. Review tasks: `ls .working/colony/{project}/tasks/`
2. Run: `/colony-run` (pauses at each milestone for review)
3. Autonomous: `/colony-run autonomous` (no pauses)
```
