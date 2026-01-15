# Claude Task Runner

A Claude Code plugin for decomposing complex tasks into executable sub-tasks with parallel execution, independent verification, and comprehensive reporting.

## Why This Exists

When tackling large, multi-step coding tasks, AI assistants often struggle with:
- **Context drift** - forgetting requirements after many interactions
- **Verification gaps** - claiming completion without proper testing
- **Parallelization** - not leveraging concurrent execution opportunities
- **Recovery** - losing progress when interrupted
- **Reporting** - not summarizing what was done and what needs attention

This plugin solves these problems with a structured task execution framework.

## Installation

```bash
# Clone the repository
git clone https://github.com/mattheworiordan/claude-task-runner.git

# Or install via Claude Code plugin manager (coming soon)
claude plugins install claude-task-runner
```

After installation, restart Claude Code. The `/tasks-*` commands will be available.

## Quick Start

```bash
# 1. Create a brief describing what you want to accomplish
cat > .working/MY_FEATURE_BRIEF.md << 'EOF'
# Add User Authentication

## Goal
Add login/logout functionality with session management.

## Requirements
- [ ] Login form with email/password
- [ ] Session storage in localStorage
- [ ] Protected routes redirect to login
- [ ] Logout clears session
EOF

# 2. Plan the tasks
/tasks-plan .working/MY_FEATURE_BRIEF.md

# 3. Review the decomposition, then run
/tasks-run

# 4. Or run autonomously (no human checkpoints)
/tasks-run autonomous
```

## Commands

| Command | Description |
|---------|-------------|
| `/tasks-plan [brief]` | Decompose a brief into executable tasks |
| `/tasks-run [project]` | Execute tasks with verification |
| `/tasks-run autonomous` | Execute without human checkpoints |
| `/tasks-status [project]` | Show detailed project status |
| `/tasks-projects` | List all task-runner projects |
| `/tasks-quick "prompt"` | Quick execution for simple tasks |

## How It Works

### 1. Planning Phase (`/tasks-plan`)

- Finds or creates a brief file
- Analyzes the codebase for parallelization opportunities
- Decomposes work into 15-45 minute tasks
- Captures context, design intent, and acceptance criteria
- Sets up Git strategy (branch, commit frequency)

### 2. Execution Phase (`/tasks-run`)

- Spawns isolated sub-agents for each task
- Runs tasks in parallel where safe
- Independent verification agent checks each completion
- Automatic retry on failure (up to 3 attempts)
- Git commits at phase boundaries
- Comprehensive report generation

### 3. Key Features

**Context Isolation**: Each task runs in a fresh agent context with only the information it needs. No context drift from accumulated conversation history.

**Independent Verification**: A separate verification agent checks every "DONE" claim. Catches workarounds, missing criteria, and design intent violations.

**Smart Parallelization**: Analyzes dependencies and resource constraints. Asks when uncertain. Serializes browser tests, database migrations, etc.

**Artifact Validation**: Log files and screenshots must exist before marking complete. Never trusts agent claims without filesystem proof.

**Recovery**: All state persisted to JSON. Pick up exactly where you left off if interrupted.

**Autonomous Mode**: Run overnight without checkpoints. Safety limits prevent runaway failures.

## Project Structure

When you run `/tasks-plan`, it creates:

```
.working/task-runner/{project-name}/
├── context.md              # Project rules, tech stack, parallelization
├── state.json              # Task status, Git config, execution log
├── tasks/
│   ├── T001.md            # Individual task files
│   ├── T002.md
│   └── ...
├── logs/
│   ├── T001_LOG.md        # Execution + verification logs
│   └── ...
├── screenshots/            # Visual verification evidence
├── resources/
│   └── original-brief.md  # Copy of source brief
└── REPORT.md              # Final execution report
```

## Comparison with RALF

[RALF (Ralph Wiggum)](https://www.cursor.com/blog/ralf) is another approach to autonomous AI coding. Here's how they compare:

### Architecture

| Aspect | Task Runner | RALF |
|--------|-------------|------|
| **Approach** | Task decomposition + sub-agents | Simple while loop |
| **Context** | Fresh per-task (isolated) | Full reset each iteration |
| **State** | JSON file (structured) | Filesystem + progress file |
| **Verification** | Independent verifier agent | LLM self-check in next iteration |

### When to Use Task Runner

✅ **Complex multi-step projects** - When work can be parallelized and benefits from structured decomposition

✅ **Teams or handoffs** - Clear task files, logs, and reports make it easy to understand what happened

✅ **Visual/browser testing** - Built-in VISUAL: criteria and screenshot capture

✅ **Git workflow integration** - Automatic branch management and phase commits

✅ **Projects needing audit trail** - Every task has execution logs and verification results

### When to Use RALF

✅ **Single-threaded iteration** - When tasks must be strictly sequential

✅ **Simpler setup** - No plugin installation, just a prompt pattern

✅ **Maximum simplicity** - When you want the AI to figure out its own workflow

✅ **Exploration tasks** - When the goal isn't well-defined upfront

### Key Differences

**Context Handling**:
- *Task Runner*: Each task gets exactly the context it needs. No accumulated drift.
- *RALF*: Full context reset each iteration. Progress tracked in filesystem.

**Verification**:
- *Task Runner*: Independent agent verifies every completion. Catches workarounds.
- *RALF*: Same model checks its own work in next iteration.

**Parallelization**:
- *Task Runner*: Runs up to 8 tasks concurrently when safe.
- *RALF*: Single-threaded by design.

**Recovery**:
- *Task Runner*: Structured state.json allows precise recovery.
- *RALF*: Progress file provides coarse-grained recovery.

### Bottom Line

- Use **Task Runner** for structured, parallelizable work where verification matters
- Use **RALF** for simple, sequential tasks where you want minimal setup

They're complementary approaches, not competitors. Choose based on your task's needs.

## Configuration

### Concurrency

```
# During execution
"set concurrency to 3"   # Run up to 3 tasks in parallel
"serialize"              # Set concurrency to 1
"maximize"               # Set concurrency to 8
```

### Git Strategy

Configured during `/tasks-plan`:
- **Branch**: Feature branch or current branch
- **Commits**: After each task, phase, or at end
- **Style**: Conventional commits with Co-Authored-By

### Autonomous Mode

```
/tasks-run autonomous
```

Safety limits:
- Max 3 retries per task
- Stops if >50% of tasks fail
- Max iterations = total_tasks × 3

## Task File Format

Each task file (`.working/task-runner/{project}/tasks/T{NNN}.md`) contains:

```markdown
# Task T001: Setup Authentication

## Status
pending

## Context & Why
{Why this task exists, how it fits the broader goal}

## Design Intent
{Philosophy, user preferences, what to avoid}

## Description
{What needs to be done}

## Files
- src/auth/login.js
- src/auth/session.js

## Acceptance Criteria
- [ ] Login form validates email format
- [ ] VISUAL: Form shows error state on invalid input
- [ ] Session persists across page reload

## Completion Promise
When done, output: TASK_COMPLETE: T001

## Verification Command
npm test -- --testPathPattern=auth

## Dependencies
None

## Parallel Group
setup
```

## Troubleshooting

### "No projects found"

Run `/tasks-plan` first to create a project from a brief.

### Task stuck in "running"

Tasks running >30 minutes reset to "pending" on next `/tasks-run`.

### Verification keeps failing

Read the verifier's feedback in `.working/task-runner/{project}/logs/{task}_LOG.md`. It includes specific suggestions.

### Browser verification not working

Ensure you have browser automation tools available (Playwright, Puppeteer). The plugin will use whatever browser automation is available in your environment.

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## License

MIT License - See [LICENSE](LICENSE) for details.

## Author

Matthew O'Riordan ([@mattheworiordan](https://github.com/mattheworiordan))

---

Built with Claude Code. Tested on real projects.
