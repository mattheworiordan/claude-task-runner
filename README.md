# Colony

![Colony](assets/colony-logo.jpg)

A Claude Code plugin that decomposes complex tasks into parallel sub-tasks with independent verification — like a colony of AI workers.

---

## Why This Exists

When tackling large, multi-step coding tasks, AI assistants often struggle with:
- **Context drift** - forgetting requirements after many interactions
- **Verification gaps** - claiming completion without proper testing
- **Parallelization** - not leveraging concurrent execution opportunities
- **Recovery** - losing progress when interrupted
- **Reporting** - not summarizing what was done and what needs attention

Colony solves these problems by spawning specialized worker agents that execute tasks in parallel, with independent inspector agents verifying each completion.

## Installation

### Option 1: Install from Marketplace (Recommended)

```bash
# In Claude Code, add the Colony marketplace and install
/plugin marketplace add mattheworiordan/colony
/plugin install colony
```

### Option 2: Manual Installation

```bash
# Clone the repository
git clone https://github.com/mattheworiordan/colony.git ~/.claude/plugins/colony
```

After cloning, the plugin is automatically available. Restart Claude Code if it's already running.

### Option 3: Project-Local Installation

To use Colony in a specific project only:

```bash
# Clone into your project
git clone https://github.com/mattheworiordan/colony.git .claude-plugins/colony

# Run Claude Code with the plugin directory
claude --plugin-dir .claude-plugins/colony
```

### Verify Installation

After installation, run `/help` in Claude Code — you should see the `/colony-*` commands listed.

**Community Registry**: Colony is also indexed at [claude-plugins.dev](https://claude-plugins.dev/), which automatically discovers Claude Code plugins on GitHub.

### Working Directory Convention

Colony stores all project state in a `.working/colony/` directory within your project. This includes task files, execution logs, screenshots, and reports.

**Recommendation**: Add `.working/` to your global gitignore to avoid committing Colony's working files:

```bash
# Add to your global gitignore
echo ".working/" >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```

Alternatively, add `.working/` to your project's `.gitignore` if you prefer per-project configuration.

## Quick Start

### Option 1: Create a Brief File

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
/colony-plan .working/MY_FEATURE_BRIEF.md

# 3. Review the decomposition, then run
/colony-run
```

### Option 2: Point to Any File

You can use any markdown file as a brief — it doesn't need to be in `.working/`:

```bash
# Use a file from docs/
/colony-plan docs/FEATURE_SPEC.md

# Use a file from anywhere
/colony-plan ~/Desktop/my-project-plan.md
```

### Option 3: Describe Inline

If you don't have a brief file, just run `/colony-plan` and describe what you want:

```bash
/colony-plan
# Colony will ask: "I didn't find any brief files. You can:
#   1. Tell me the path to your brief
#   2. Paste the tasks directly here
#   3. Describe what you want to accomplish"
```

### Option 4: Quick Tasks

For simple, well-defined tasks, skip the planning phase entirely:

```bash
/colony-quick "Add a loading spinner to the submit button"
```

## Brief Discovery

When you run `/colony-plan` without specifying a file, Colony searches for potential briefs in:

1. **`.working/*.md`** - The conventional location for working documents
2. **`docs/*.md`** - Documentation folder
3. **Files matching patterns**: `*brief*`, `*plan*`, `*todo*`, `*spec*`

If multiple candidates are found, Colony will ask which one to use. If none are found, you can paste or describe your requirements directly.

## Commands

| Command | Description |
|---------|-------------|
| `/colony-plan [brief]` | Decompose a brief into executable tasks |
| `/colony-run [project]` | Execute tasks with verification |
| `/colony-run autonomous` | Execute without human checkpoints |
| `/colony-status [project]` | Show detailed project status |
| `/colony-projects` | List all colony projects |
| `/colony-quick "prompt"` | Quick execution for simple tasks |

## How It Works

### 1. Planning Phase (`/colony-plan`)

- Finds or creates a brief file
- Analyzes the codebase for parallelization opportunities
- Decomposes work into 15-45 minute tasks
- Captures context, design intent, and acceptance criteria
- Sets up Git strategy (branch, commit frequency)

### 2. Execution Phase (`/colony-run`)

- Spawns isolated **worker** agents for each task
- Runs tasks in parallel where safe
- Independent **inspector** agents verify each completion
- Automatic retry on failure (up to 3 attempts)
- Git commits at phase boundaries
- Comprehensive report generation

### 3. Key Features

**Context Isolation**: Each worker runs in a fresh context with only the information it needs. No context drift from accumulated conversation history.

**Independent Verification**: A separate inspector agent checks every "DONE" claim. Catches workarounds, missing criteria, and design intent violations.

**Smart Parallelization**: Analyzes dependencies and resource constraints. Asks when uncertain. Serializes browser tests, database migrations, etc.

**Artifact Validation**: Log files and screenshots must exist before marking complete. Never trusts agent claims without filesystem proof.

**Recovery**: All state persisted to JSON. Pick up exactly where you left off if interrupted.

**Autonomous Mode**: Run overnight without checkpoints. Safety limits prevent runaway failures.

## Project Structure

When you run `/colony-plan`, it creates:

```
.working/colony/{project-name}/
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

| Aspect | Colony | RALF |
|--------|--------|------|
| **Approach** | Task decomposition + worker agents | Simple while loop |
| **Context** | Fresh per-task (isolated) | Full reset each iteration |
| **State** | JSON file (structured) | Filesystem + progress file |
| **Verification** | Independent inspector agent | LLM self-check in next iteration |

### When to Use Colony

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
- *Colony*: Each worker gets exactly the context it needs. No accumulated drift.
- *RALF*: Full context reset each iteration. Progress tracked in filesystem.

**Verification**:
- *Colony*: Independent inspector verifies every completion. Catches workarounds.
- *RALF*: Same model checks its own work in next iteration.

**Parallelization**:
- *Colony*: Runs up to 8 workers concurrently when safe.
- *RALF*: Single-threaded by design.

**Recovery**:
- *Colony*: Structured state.json allows precise recovery.
- *RALF*: Progress file provides coarse-grained recovery.

### Bottom Line

- Use **Colony** for structured, parallelizable work where verification matters
- Use **RALF** for simple, sequential tasks where you want minimal setup

They're complementary approaches, not competitors. Choose based on your task's needs.

## Configuration

### Concurrency

```
# During execution
"set concurrency to 3"   # Run up to 3 workers in parallel
"serialize"              # Set concurrency to 1
"maximize"               # Set concurrency to 8
```

### Git Strategy

Configured during `/colony-plan`:
- **Branch**: Feature branch or current branch
- **Commits**: After each task, phase, or at end
- **Style**: Conventional commits with Co-Authored-By

### Autonomous Mode

```
/colony-run autonomous
```

Safety limits:
- Max 3 retries per task
- Stops if >50% of tasks fail
- Max iterations = total_tasks × 3

## Task File Format

Each task file (`.working/colony/{project}/tasks/T{NNN}.md`) contains:

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

Run `/colony-plan` first to create a project from a brief.

### Task stuck in "running"

Tasks running >30 minutes reset to "pending" on next `/colony-run`.

### Verification keeps failing

Read the inspector's feedback in `.working/colony/{project}/logs/{task}_LOG.md`. It includes specific suggestions.

### Browser verification not working

Ensure you have browser automation tools available (Playwright, Puppeteer). Colony will use whatever browser automation is available in your environment.

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
