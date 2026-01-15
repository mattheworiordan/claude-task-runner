# Colony

<img src="assets/colony-logo.jpg" alt="Colony" width="300">

**Your AI swarm for serious software engineering.**

Colony turns Claude Code into a parallel task execution engine with independent verification. Give it a complex task, and it spawns a colony of specialized workers—each with fresh context, each verified by an independent inspector.

> **Like Ralph, but built for real work.** Where Ralph iterates sequentially and checks its own homework, Colony intelligently parallelizes work with independent QA. Human-in-the-loop or fully autonomous. Git-aware. Production-ready.

---

## See It In Action

<img src="assets/colony-runner-animated.gif" alt="Colony executing tasks" width="700">

**Smart Planning** — Colony analyzes your brief, identifies parallelization opportunities, and creates an execution plan:

<img src="assets/colony-planning.png" alt="Colony planning phase" width="700">

**Dependency-Aware Execution** — Tasks run in parallel where safe, serialize where necessary:

<img src="assets/colony-planned.png" alt="Colony execution plan" width="700">

**Simple Commands** — Everything accessible via `/colony-*` commands:

<img src="assets/colony-commands.png" alt="Colony commands" width="700">

---

## Why Colony Wins

| Capability | Traditional AI | Ralph | Colony |
|------------|----------------|-------|--------|
| **Context** | Drifts after 10+ exchanges | Full reset each iteration | Fresh context per task |
| **Verification** | "Done!" (it wasn't) | Checks its own homework | Independent inspector |
| **Speed** | One thing at a time | Single-threaded | Intelligent parallelization |
| **Oversight** | All or nothing | Autonomous only | Human-in-loop or autonomous |
| **Git workflow** | Manual | Manual | Automatic branch + commits |
| **Recovery** | Start over | Coarse progress file | Task-level resume |
| **Audit trail** | Nothing | Progress notes | Full execution logs |

---

## Key Features

### Intelligent Parallelization
Colony doesn't just run things in parallel—it *thinks* about what can safely parallelize:

- **Dependency analysis** — Understands task dependencies and serializes when needed
- **Resource awareness** — Knows when tasks touch the same files and avoids conflicts
- **Asks when uncertain** — Won't guess on parallelization safety; asks you instead
- **Dynamic adjustment** — Change concurrency mid-run: `"set concurrency to 3"`

### Two Execution Modes

**Human-in-the-Loop (default)**
- Checkpoints between phases for review
- Approve parallelization decisions
- Intervene on failures before retrying

**Fully Autonomous**
- Run overnight without interruption
- Safety limits prevent runaway failures (max retries, failure thresholds)
- Complete report waiting for you in the morning

```bash
/colony-run              # Interactive mode
/colony-run autonomous   # Autonomous mode
```

### Git-Aware Workflow
Colony understands your git workflow and integrates seamlessly:

- **Branch strategy** — Creates feature branches or works on current branch
- **Smart commits** — After each task, phase, or at project end (you choose)
- **Conventional commits** — Proper commit messages with Co-Authored-By attribution
- **Conflict prevention** — Won't parallelize tasks that touch the same files

### Independent Verification
Every task completion is verified by a separate inspector agent:

- **Fresh context** — Inspector has no knowledge of worker's struggles or workarounds
- **Acceptance criteria** — Checks every criterion, not just "does it compile"
- **Visual verification** — `VISUAL:` criteria trigger screenshot capture and validation
- **No self-deception** — Worker can't mark itself complete; inspector decides

### Full Recovery
Interrupted? Pick up exactly where you left off:

- **Structured state** — All progress saved to `state.json`
- **Task-level granularity** — Resume from the exact task that was interrupted
- **Execution logs** — Every task has detailed logs of what happened
- **Artifact validation** — Screenshots and logs must exist before marking complete

---

## The Problem With AI Coding Today

When tackling large, multi-step coding tasks, AI assistants struggle with:

- **Context drift** — forgetting requirements after many interactions
- **Verification gaps** — claiming completion without proper testing
- **Sequential bottlenecks** — not leveraging concurrent execution
- **Lost progress** — no recovery when interrupted
- **Invisible work** — no summary of what was done

**Colony solves all of this.** Specialized worker agents execute tasks in parallel. Independent inspector agents verify every completion. Everything logged, everything recoverable.

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

## Colony vs Ralph

[Ralph](https://www.cursor.com/blog/ralf) popularized autonomous AI coding with a clever while-loop approach. Colony takes it further.

### The Key Insight

**Ralph's weakness**: It checks its own homework. The same model that claims "done" also decides if it's really done. That's like asking a student to grade their own test.

**Colony's answer**: Independent verification. A separate inspector agent—with fresh context and no ego investment—verifies every completion. It catches workarounds, missing criteria, and "works on my machine" claims.

### Head-to-Head

| Capability | Colony | Ralph |
|------------|--------|------|
| **Parallelization** | Intelligent—analyzes dependencies, asks when uncertain | Single-threaded |
| **Execution modes** | Human-in-the-loop or fully autonomous | Single mode |
| **Verification** | Independent inspector agent | Self-check (same model) |
| **Context** | Fresh per-task | Full reset each iteration |
| **Git workflow** | Branch strategy, smart commits, conflict prevention | Manual |
| **Visual testing** | Built-in screenshot verification | Manual |
| **Recovery** | Precise task-level resume | Coarse progress file |
| **Audit trail** | Complete execution logs per task | Progress notes |

### When to Use Each

**Choose Colony when:**
- Work can be parallelized (most real projects)
- You need proof that tasks are actually complete
- Multiple people need to understand what happened
- You're building production code, not prototyping

**Choose Ralph when:**
- Tasks are strictly sequential
- You want zero setup (just a prompt pattern)
- You're exploring without clear requirements

### The Bottom Line

Ralph proved autonomous AI coding works. Colony makes it production-ready.

**Speed**: Parallelization beats sequential iteration.
**Trust**: Independent verification beats self-assessment.
**Recovery**: Structured state beats hope.

## Configuration

### Concurrency

```
# During execution
"set concurrency to 3"   # Run 3 workers in parallel
"set concurrency to 10"  # Run 10 workers in parallel
"serialize"              # Set concurrency to 1
```

Default is 5. Set to any value based on your machine resources and task complexity.

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

---

**Built by [Matthew O'Riordan](https://github.com/mattheworiordan)**, CEO at [Ably](https://ably.com)

[Ably](https://ably.com) powers realtime experiences with trillions of messages for billions of devices each month. 
Colony is how we ship code fast without breaking things.

Building AI agents? Check out [Ably AI Transport](https://ably.com/solutions/ai-agents) - drop-in infrastructure layer for a resilient, AI UX. Ably AI Transport brings realtime continuity and control to your agents. Stateful, steerable, multi-device experiences.

[Star on GitHub](https://github.com/mattheworiordan/colony) • [Report Issues](https://github.com/mattheworiordan/colony/issues) • [Follow @mattheworiordan](https://x.com/mattheworiordan)
