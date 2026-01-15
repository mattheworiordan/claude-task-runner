---
name: colony-plan
description: Plan tasks from a brief - interactive task decomposition
version: 1.0.0
status: active

# Claude Code command registration
allowed-tools: Read, Write, Bash, Grep, Glob, AskUserQuestion
---

# Plan Tasks

Create a colony project by decomposing a brief into executable tasks.

## Step 1: Find Brief Files

Search for potential brief files:

```bash
# Look in common locations
find . -maxdepth 3 -type f \( -name "*.md" -o -name "*.txt" \) \
  -path "*working*" -o -path "*brief*" -o -path "*plan*" -o -path "*todo*" \
  2>/dev/null | head -20
```

Also check:
- `.working/*.md`
- `docs/*.md`
- Any file mentioned in $ARGUMENTS

## Step 2: Interactive Brief Selection

If $ARGUMENTS contains a file path, use that.

Otherwise, present found candidates to the user:

```
I found these potential brief files:
• .working/INTEGRATION_BRIEF.md (2.3KB, modified today)
• .working/API_REFACTOR_PLAN.md (1.8KB, modified yesterday)

Which brief should I use? Or paste/describe the tasks directly.
```

If no candidates found:
```
I didn't find any brief files. You can:
1. Tell me the path to your brief
2. Paste the tasks directly here
3. Describe what you want to accomplish and I'll create the task list
```

## Step 3: Generate Project Name

Derive from brief:
1. Use filename without extension, slugified: `INTEGRATION_BRIEF.md` → `integration-brief`
2. Or use first H1 heading, slugified: `# API Refactor Plan` → `api-refactor-plan`
3. If unclear, ask user

Check if project exists:
```bash
ls -d .working/colony/*/ 2>/dev/null
```

If project name already exists, ask:
```
Project "integration-brief" already exists (8 tasks, 3 complete).
• Continue with existing project? (use /colony-run)
• Create new version? (integration-brief-2)
• Overwrite? (will lose existing progress)
```

## Step 4: Task Type Assessment

Before establishing Git strategy, determine whether this project requires code changes that would benefit from a feature branch.

### 4.1: Analyze Task Type Signals

**Scan the brief for task type indicators:**

```bash
# Check if this is a code repository (has source files)
ls package.json Gemfile Cargo.toml go.mod pyproject.toml setup.py pom.xml 2>/dev/null | head -5

# Check if brief suggests research/documentation only
grep -i "research\|analyze\|investigate\|explore\|document\|write-up\|summary\|report" "{brief_path}" | head -5
```

**Feature branch LIKELY NEEDED when:**
- Brief mentions: implement, build, create feature, fix bug, refactor, add code
- Tasks will modify tracked source files (not just `.working/`)
- Brief mentions: PR, pull request, merge, code review
- Working in an application/library repository with active development

**Feature branch LIKELY NOT NEEDED when:**
- Brief mentions: research, analyze, investigate, explore, document
- All task outputs go to `.working/` or `docs/` folders
- Tasks involve external tools/APIs without code changes
- No source files would be modified
- Brief explicitly says "no code changes" or "research only"
- Working in a notes/documentation-only repository

### 4.2: Determine Git Applicability

**Set `requires_git_strategy` based on analysis:**

| Condition | `requires_git_strategy` |
|-----------|------------------------|
| Brief mentions implementation/features/fixes | `true` |
| Tasks modify tracked source files | `true` |
| Brief explicitly says research/documentation only | `false` |
| All outputs go to `.working/` only | `false` |
| Mixed (some code, some research) | Ask user |
| Uncertain | Ask user |

**If uncertain, prompt the user:**
```
## Task Type Assessment

I analyzed the brief and I'm unsure whether this project needs a feature branch.

**Indicators suggesting code changes:**
{list any found}

**Indicators suggesting research/documentation only:**
{list any found}

Does this project involve code changes that should be on a feature branch?
1. Yes - Create feature branch (for implementation work)
2. No - Skip Git strategy (for research/documentation)
3. Some tasks need branches - I'll manage per-task
```

### 4.3: Skip or Continue

**If `requires_git_strategy` is `false`:**
- Skip Steps 5.1-5.6 entirely
- Set `git.strategy` to `"not_applicable"` in state.json
- Proceed to Step 6 (Detect Visual/Browser Requirements)

**If `requires_git_strategy` is `true`:**
- Continue to Step 5 (Git Strategy)

---

## Step 5: Git Strategy

**SKIP this section if `requires_git_strategy` is `false`.**

Before starting work, establish the Git strategy for this project.

### 5.1: Check Working Tree State

```bash
git status --porcelain
```

**If there are uncommitted changes, STOP and ask:**
```
Your working tree has uncommitted changes:
{list of changed files}

Before starting the task runner, please:
• Commit these changes
• Stash them (git stash)
• Or discard them if unneeded

I'll wait for a clean working tree to avoid mixing task work with existing changes.
```

**Do not proceed until working tree is clean.**

### 5.2: Detect Existing Git Conventions

Look for documented Git strategies:

```bash
# Check for contributing guidelines
cat CONTRIBUTING.md 2>/dev/null | head -50
cat .github/CONTRIBUTING.md 2>/dev/null | head -50

# Check for commit conventions
cat .github/pull_request_template.md 2>/dev/null
cat commitlint.config.js 2>/dev/null

# Check for branch naming conventions
git branch -a | head -20

# Check CLAUDE.md for Git rules
grep -i "git\|commit\|branch" .claude/CLAUDE.md ~/.claude/CLAUDE.md 2>/dev/null
```

Note any conventions found:
- Commit message format (conventional commits, etc.)
- Branch naming patterns
- PR requirements
- Required reviewers

### 5.3: Branch Strategy

Check current branch state:

```bash
git branch --show-current
git log --oneline -5
```

**Prompt the user:**
```
## Git Strategy for {project-name}

**Current branch:** {branch-name}
**Uncommitted changes:** None (clean)

### Branch Strategy

I recommend creating a feature branch for this work:
• Suggested name: `colony/{project-name}` or `feature/{project-name}`
• This keeps main clean and allows easy review/rollback

Options:
1. Create feature branch (recommended): `colony/{project-name}`
2. Work on current branch: `{current-branch}`
3. Different branch name: [specify]

{If conventions detected: "Note: Your repo uses {convention} for branch names."}
```

**If user chooses feature branch:**
```bash
git checkout -b {branch-name}
```

### 5.4: Commit Strategy

**Present the default and allow override:**
```
### Commit Strategy

**Default:** Commit after each completed phase (logical groupings)
• Phase 1 complete → commit "feat: setup infrastructure for {project}"
• Phase 2 complete → commit "feat: implement core features"
• etc.

This balances atomic commits with not interrupting flow.

**Alternatives:**
• After each task: More granular, easier rollback, more commits
• At the end: Review all changes first, single commit
• Manual: I'll prompt you after each phase to review and commit

Which strategy? [phase/task/end/manual] (default: phase)
```

### 5.5: Commit Message Style

**Detect and confirm style:**
```
### Commit Messages

**Detected conventions:** {conventional commits / none detected}

**Defaults:**
• Style: Conventional commits (feat:, fix:, chore:, etc.)
• Co-author: Included as `Co-Authored-By: Claude <noreply@anthropic.com>`

Override any of these? [y/N]
```

**Note:** The task runner is an exception to the "never commit without permission" rule
since you explicitly invoked `/colony-run` to execute work autonomously.

### 5.6: Store Git Configuration

Record the Git strategy in state.json (see Step 8) and context.md.

**Summary to user:**
```
### Git Configuration Saved

• Branch: `{branch-name}` {created / existing}
• Commits: After each phase
• Style: Conventional commits
• Co-author: Claude <noreply@anthropic.com>

You can override during execution:
• "commit now" - Force immediate commit
• "skip commit" - Skip the phase commit
• "show changes" - Review before committing
```

## Step 6: Detect Visual/Browser Verification Requirements

**CRITICAL: Analyze the brief to determine if tasks require browser verification.**

Scan the brief for indicators of visual/browser requirements:

**Strong indicators (task REQUIRES browser verification):**
- "visual verification", "visually verify", "check in browser"
- "screenshot", "take screenshot", "capture screenshot"
- "browser automation", "browser testing"
- "UI testing", "UX verification", "look and feel"
- "form verification", "form testing", "end-to-end"
- Mentions of specific UI elements to verify visually

**Moderate indicators (task MAY need browser verification):**
- "verify the form works", "check the dropdown"
- "ensure the button", "confirm the modal"
- "styling", "layout", "spacing", "appearance"
- References to visual design requirements

**If ANY visual/browser indicators are found:**

1. Set `verification_type` to `visual` or `mixed` in project context
2. ALL acceptance criteria that require visual inspection must be prefixed with `VISUAL:`
3. Task files must include explicit browser verification instructions
4. Verification commands must check for screenshot existence

## Step 6b: Analyze Brief for Parallelization

Before decomposing, analyze the codebase for parallelization hints:

```bash
# Check for test parallelization hints
grep -r "parallel" package.json Gemfile Makefile .github/workflows/ 2>/dev/null | head -10

# Check for CI configuration
cat .github/workflows/*.yml 2>/dev/null | grep -A5 "jobs:" | head -20

# Check for database/resource constraints
grep -r "DATABASE\|REDIS\|connection" .env.example .env.test 2>/dev/null
```

Look for:
- **Test frameworks**: Can tests run in parallel? (RSpec parallel, Jest workers, pytest-xdist)
- **Browser tests**: Usually need serialization or separate browser instances
- **Database tests**: May need isolation or serialization
- **Build steps**: Often must be sequential
- **Independent features**: Can usually parallelize

## Step 7: Create Project Directory

```bash
mkdir -p .working/colony/{project-name}/tasks
mkdir -p .working/colony/{project-name}/logs
mkdir -p .working/colony/{project-name}/resources
mkdir -p .working/colony/{project-name}/screenshots
```

The `resources/` folder stores the original brief and any reference materials.
The `screenshots/` folder stores all visual verification evidence (kept with the project for audit trail).

## Step 8: Capture Context

Create `.working/colony/{project-name}/context.md`:

```markdown
# Project Context: {project-name}

Captured at: {timestamp}

## Source Brief
{path to original brief}

## Task Type
- **Type:** {implementation | research | documentation | mixed}
- **Git strategy required:** {yes | no}

{Brief analysis that led to this classification}

## Git Strategy

{INCLUDE THIS SECTION ONLY IF git strategy is required}

- **Branch:** {branch-name}
- **Commit frequency:** {phase/task/end/manual}
- **Commit style:** {conventional commits, etc.}
- **Co-author:** {yes/no}

**Detected conventions:**
{any Git conventions found in CONTRIBUTING.md, commitlint, etc.}

{IF git strategy is NOT required:}
**Git strategy not applicable for this project.**
This is a {research/documentation} task - outputs go to `.working/` folder only.
No feature branch or commits will be created.

## Verification Type

{Set based on Step 6 analysis}

- **Type:** {code-only | visual | mixed}
- **Browser required:** {yes | no}
- **Screenshot folder:** `.working/colony/{project-name}/screenshots/`

{If visual or mixed:}
**Browser verification is REQUIRED for this project.**
- Tasks with `VISUAL:` prefixed criteria MUST use browser automation
- PARTIAL response if browser verification cannot be completed
- Screenshots saved to: `.working/colony/{project-name}/screenshots/`

## Project Rules

### From CLAUDE.md
{content of .claude/CLAUDE.md or ~/.claude/CLAUDE.md if exists}

## Parallelization Analysis

### Can Parallelize
- {tasks that can run concurrently}
- Reasoning: {why these are safe}

### Must Serialize
- {tasks that must run in order}
- Reasoning: {shared resources, dependencies, etc.}

### Uncertain (Will Ask)
- {tasks where parallelization is unclear}

## Tech Stack
{detected from package.json, Gemfile, etc.}

## Testing Patterns
{test framework, how to run tests, parallel support}

## Conventions
{coding style, patterns observed}
```

## Step 9: Decompose Brief into Tasks

Read the brief and create individual task files.

**CRITICAL: Preserve Context for Sub-Agents**

Sub-agents executing tasks will NOT have access to:
- The original brief
- Other tasks
- Your conversation history
- The "why" behind decisions

Each task file must be **self-contained** with enough context for an agent to:
1. Understand WHY this task exists
2. Make good judgment calls beyond just acceptance criteria
3. Understand the user's design philosophy
4. Know what patterns to follow or avoid

**What to PRESERVE (never strip these):**
- User quotes showing their thinking/preferences
- Design philosophy and intent
- Research suggestions or patterns to follow
- Context about what to AVOID
- Trade-offs to consider
- How this task relates to the broader goal

**What to CONDENSE (summarize, don't remove):**
- Lengthy background that can be shortened
- Repetitive explanations
- Implementation details that are obvious from the code

**What to OMIT:**
- Information about OTHER tasks (they don't need it)
- Status tracking from the brief (we have our own)
- Redundant file listings

### Task Sizing Guidelines
- Each task: 15-45 minutes of focused work
- Too large? Split into subtasks
- Too small? Combine related work
- One clear deliverable per task

### Dependency Detection
- Shared files → likely dependency
- "after X" or "once Y is done" → explicit dependency
- Setup/infrastructure → should come first
- Tests for feature → depends on feature

### Parallel Group Assignment

Assign each task a `parallel_group`:
- `setup` - Infrastructure, must run first, usually serial
- `independent-{n}` - No shared resources, can parallelize
- `tests-unit` - Unit tests, usually parallelizable
- `tests-integration` - May need serialization
- `tests-browser` - Usually serialize (browser resource)
- `database` - Often needs serialization
- `build` - Usually serial
- `cleanup` - Runs last

### Task File Format

Create `.working/colony/{project-name}/tasks/T{NNN}.md`:

```markdown
# Task T{NNN}: {Short Name}

## Status
pending

## Context & Why

{Why does this task exist? What problem does it solve?}
{How does it fit into the broader project goals?}
{What will be possible once this is complete?}

## Design Intent

{The philosophy behind HOW this should be implemented}
{User's thinking - include direct quotes when available}
{What "good" looks like beyond just acceptance criteria}
{What to AVOID - anti-patterns, things user doesn't want}

## Considerations

{Things to research or reference}
{Patterns from other products to consider}
{Trade-offs to think about}
{Edge cases to handle}

## Description

{Concise description of what needs to be done}

## Files
- {path/to/file1}
- {path/to/file2}

## Acceptance Criteria

- [ ] {Specific, verifiable criterion}
- [ ] {Another criterion}

## Completion Promise

When ALL acceptance criteria are verified, output exactly:
```
TASK_COMPLETE: T{NNN}
```

This signals to the verification system that the task is done.

## Verification Command
```bash
{command to verify success - for automated criteria}
```

## Dependencies
{T001, T002 or "None"}

## Parallel Group
{group-name}

## Estimated Effort
{small: <15min, medium: 15-30min, large: 30-45min}
```

## Step 10: Create State File

Create `.working/colony/{project-name}/state.json`:

```json
{
  "project_name": "{project-name}",
  "created_at": "{ISO timestamp}",
  "updated_at": "{ISO timestamp}",
  "brief_source": "{path}",
  "total_tasks": 0,
  "concurrency": 5,
  "autonomous_mode": false,
  "task_type": "{implementation | research | documentation | mixed}",
  "git": {
    "strategy": "{active | not_applicable}",
    "branch": "{branch-name | null}",
    "created_branch": "{true | false | null}",
    "original_branch": "{original-branch | null}",
    "commit_strategy": "{phase | task | end | manual | null}",
    "commit_style": "{conventional | null}",
    "include_coauthor": "{true | false | null}",
    "commits": [],
    "detected_conventions": "{any conventions found | null}"
  },
  "parallelization": {
    "analyzed": true,
    "groups": {
      "setup": {"tasks": ["T001"], "strategy": "serial"},
      "independent": {"tasks": ["T002", "T003", "T004"], "strategy": "parallel"},
      "tests-browser": {"tasks": ["T005", "T006"], "strategy": "serial"}
    },
    "notes": "{reasoning about parallelization decisions}"
  },
  "verification_type": "{code-only | visual | mixed}",
  "tasks": {
    "T001": {
      "status": "pending",
      "attempts": 0,
      "started_at": null,
      "completed_at": null,
      "last_error": null
    }
  },
  "execution_log": []
}
```

## Step 11: Copy Brief to Resources

Copy original brief to the resources folder for audit trail:

```bash
cp {original-brief-path} .working/colony/{project-name}/resources/original-brief.md
```

## Step 12: Output Summary

```markdown
## Project Created: {project-name}

**Location:** .working/colony/{project-name}/
**Tasks:** {count} tasks created
**Task Type:** {implementation | research | documentation | mixed}
**Estimated Total Effort:** {sum of estimates}

### Git Strategy

{IF git strategy is active:}

| Setting | Value |
|---------|-------|
| Branch | `{branch-name}` {(created) or (existing)} |
| Commits | After each phase |
| Style | Conventional commits |
| Co-author | Claude <noreply@anthropic.com> |

{IF git strategy is not applicable:}

**Not applicable** - This is a {research/documentation} task.

### Execution Plan

**Phase 1 - Setup (serial):**
- T001: {name}

**Phase 2 - Main Work (parallel, up to 5 concurrent):**
- T002, T003, T004: {can run together}

### Next Steps
1. Review tasks: `ls .working/colony/{project-name}/tasks/`
2. Start execution: `/colony-run`
3. Start autonomous: `/colony-run autonomous`
4. Monitor: `/colony-status`
```

## Error Handling

- If brief is unparseable, ask user to clarify structure
- If parallelization is unclear, ask user
- If task type is unclear, ask user (see Step 4)
- If Git strategy is active AND Git state is dirty, refuse and prompt user
- Log issues to `.working/colony/{project-name}/planning.log`
