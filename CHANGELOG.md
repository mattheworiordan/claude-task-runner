# Changelog

## v1.4.0 (2026-01-19)

### Summary

**Requirement fidelity and fresh context execution.** This release addresses the core issue of requirements being lost during task decomposition, and introduces an alternative RELF-style execution mode with fresh context per milestone.

### New: Requirement Extraction (colony-mobilize.md Step 5)

Mobilization now treats the brief as a **contract, not a suggestion**:

- Extracts all explicit verification requirements
- Creates `requirements-checklist.md` mapping each requirement
- Flags requirements that can't be automated instead of silently dropping them

```markdown
<critical>
If the brief says "run X", there must be a task/verification that ACTUALLY RUNS X.
NO SUBSTITUTING complex verification with simpler checks.
</critical>
```

### New: Validation Agent (colony-mobilize.md Step 13.5)

After task decomposition, a validation agent checks coverage:

- Reads original brief and all task files
- Verifies every requirement has a task or acceptance criterion
- Flags gaps BEFORE execution begins
- Mobilization loops until validation passes

### New: Complex Verification Templates

Enhanced verification command guidelines with browser/visual testing templates:

```bash
#!/bin/bash
# Visual/Browser verification template
npm run dev & PID1=$!
npm run dev:next -- --port 3001 & PID2=$!
timeout 60 bash -c 'until curl -s http://localhost:8000 > /dev/null; do sleep 1; done'
npx playwright test scripts/visual-test.ts
kill $PID1 $PID2
```

### New: RELF-Style Fresh Context Execution

Alternative execution mode using `colony-runner` bash script:

```bash
# Fresh context per milestone, bash outer loop can't drift
colony-runner my-project --autonomous --verbose
```

**How it works:**
- Bash script loops through milestones (deterministic, can't forget rules)
- Each milestone executed via `claude -p` (fresh context)
- `claude -p` CAN spawn sub-agents (verified: Task tool works)
- Progress visibility via `--output-format stream-json`

**Two execution modes now available:**

| Mode | Command | Context | Best For |
|------|---------|---------|----------|
| In-session | `/colony-deploy` | Accumulates | Interactive, quick tasks |
| Fresh context | `colony-runner` | Per milestone | Long runs, strict adherence |

### New: Milestone CLI Commands

```bash
colony milestone current <project>     # Get current milestone ID
colony milestone complete? <project>   # Check if tasks are done
colony milestone advance <project>     # Move to next milestone
colony milestone tasks <project>       # Get task IDs in milestone
colony next-batch <project>            # Get ready tasks (space-separated)
colony is-complete <project>           # Check if all tasks complete
```

### Enhanced: Inspector Verification

Inspector prompt now explicitly requires actual testing:

```markdown
CRITICAL: VERIFICATION MEANS ACTUALLY TESTING

If the acceptance criteria says "visual tests pass with 0 diff",
you must:
- Run the visual test script
- Check the output shows 0 diff
- If diff > 0, FAIL with the actual diff count

Do NOT:
- Just check if the test script file exists
- Substitute simpler verification
```

### Enhanced: Retry Logic

Clearer failure thresholds:

| Level | Threshold | Action |
|-------|-----------|--------|
| Per-task | 3 attempts | Mark blocked/failed |
| Per-milestone | >50% tasks fail | STOP, ask user |
| Session-wide | 5 consecutive failures | Circuit breaker |

### Technical: Nested Task Limitation

Discovered that sub-agents cannot spawn sub-agents (Task tool not available to Task-spawned agents). This is why `colony-runner` uses `claude -p` instead - each `claude -p` invocation is a fresh top-level session with full tool access.

---

## v1.3.0 (2026-01-19)

### Summary

**Colony now positions itself as the execution engine for Claude's plan mode.** New command names, Claude plan auto-detection, and quality-aware task decomposition.

### Command Renames

| Old | New | Rationale |
|-----|-----|-----------|
| `/colony-plan` | `/colony-mobilize` | Avoids confusion with Claude's plan mode |
| `/colony-run` | `/colony-deploy` | Pairs with mobilize; "deploy the workers" |

### New: Colony + Claude Plan Mode Integration

Colony now auto-detects recent Claude plans from `~/.claude/plans/`:

```bash
# Claude creates a plan
claude --permission-mode plan
> Interview me about adding OAuth2 authentication

# Colony finds and uses it
/colony-mobilize
# → Shows: "Found ~/.claude/plans/gleaming-sniffing-bird.md (2 hours ago) ⭐ Likely relevant"
```

Plans are ranked by relevance (file path matches, project name mentions, recency).

### New: Weak Brief Detection

When a brief appears underspecified (short, vague, no acceptance criteria), Colony warns:

```
⚠️ This appears to be a high-level goal rather than a detailed plan.

Colony is an execution engine - it works best with well-defined requirements.
Consider using Claude's plan mode first...
```

### New: DRY-Aware Task Decomposition

Colony now detects shared patterns during mobilization:

- Same UI component mentioned multiple times → creates shared component task first
- Common utilities referenced across features → infrastructure task in M1
- Prevents duplicate implementations across parallel workers

### New: Project Standards Detection

Mobilization now scans for quality tools and guidelines:

```bash
# Auto-detected
CLAUDE.md, CONTRIBUTING.md, ESLint, Prettier, TypeScript...
```

Workers must follow detected standards. Inspectors verify compliance.

### Fix: Orchestrator Model Changed to Sonnet

**Problem:** Haiku orchestrator (from v1.2) was skipping inspector verification entirely, allowing tasks to be marked complete without quality checks. This resulted in lint errors passing undetected.

**Root cause:** Haiku model is too weak to reliably follow the 600-line orchestrator prompt. It was:
- Receiving worker DONE status
- Skipping the "spawn inspector" instruction
- Marking tasks complete directly

**Solution:**
1. Default orchestrator model changed from `haiku` to `sonnet`
2. CLI now enforces inspection: `task-complete` fails if no `inspection_started` event exists
3. Stronger prompt reinforcement for inspector spawn step

**Impact:** Slightly slower orchestration, but guaranteed quality verification.

### Documentation

- New README section: "Colony + Claude Plan Mode"
- Workflow diagram showing Plan → Mobilize → Deploy
- Updated Quick Start with recommended plan mode workflow

---

## v1.2.0 (2026-01-19)

### Summary

**Colony now matches Ralph's speed while producing dramatically higher quality code.**

| Metric | Ralph | Colony v1.2 | Winner |
|--------|-------|-------------|--------|
| **Runtime** | 12m 39s | ~12 min | Tie |
| **Lint Errors** | 419 | 0 | **Colony** |
| **Lines of Code** | 537 | 165 | **Colony** (3.3x leaner) |
| **Quality Score** | ~23/100 | ~100/100 | **Colony** |
| **PR Ready?** | No | Yes | **Colony** |

### The Real Comparison

Ralph's 12-minute run produces code that needs ~1 hour of cleanup (419 lint errors).
Colony's 12-minute run produces code that's ready to merge.

**Time to deployable code:**
- Ralph: 12 min execution + 60 min cleanup = **72 minutes**
- Colony: 12 min execution + 0 min cleanup = **12 minutes**

---

### Performance: Haiku Orchestrator with Session Model Passthrough

> ⚠️ **Superseded in v1.3.0:** Haiku orchestrator proved too weak to reliably spawn inspectors. Default changed to Sonnet in v1.3.0.

The orchestrator now runs on Haiku by default while workers use your session model (Opus/Sonnet).

**How it works:**
1. Colony reads your session model from `~/.claude/settings.json`
2. Spawns a Haiku sub-agent for orchestration (cheap coordination)
3. Haiku orchestrator spawns workers with your session model (full power for implementation)
4. Inspectors run on Haiku (simple verification)

**Result:** 4.5x faster than v1.0, matching Ralph's 12-minute execution time.

```json
{
  "models": {
    "orchestrator": "haiku",
    "worker": "inherit",
    "inspector": "haiku"
  }
}
```

When `worker: "inherit"`, Colony resolves this to your `/model` setting before delegating to Haiku.

---

### Model Logging

Every task now logs which models were used:

```json
{
  "event": "task_complete",
  "task": "T001",
  "worker_model": "opus",
  "inspector_model": "haiku"
}
```

Enables analysis of token usage and model effectiveness across runs.

---

### Improved Task Sizing

New principle-based guidance replaces arbitrary rules:

**Why minimize tasks:**
- Each task has fixed overhead: worker spawn (~30s), inspector verification (~30s), state management
- 9 tasks vs 6 tasks = 50% more overhead before any real work happens
- Granular tasks increase failure surface area (more chances for lint errors, retry loops)

**Decomposition principles:**
1. **One module = one task** - Don't split types/constants/utils into separate tasks
2. **Split only for parallelization** - If two things can't run in parallel, combine them
3. **Split for different expertise** - Tests vs implementation vs docs can be separate

---

### Brief Discovery Fix

`/colony-plan` now checks the right places first instead of getting flooded by node_modules:

1. `.working/*.md` (primary location)
2. `docs/*.md`
3. Root `.md` files (excluding README, CHANGELOG, LICENSE)

---

### Enhanced Milestone Checkpoints

Non-autonomous mode now shows actionable verification guidance:

```
═══════════════════════════════════════════════════════════════
MILESTONE COMPLETE: M1 - Infrastructure Setup
═══════════════════════════════════════════════════════════════

Tasks completed:
  ✅ T001: Create protocol types - Types and constants defined
  ✅ T002: Implement parser - Keypress parsing working

Files changed:
  src/kitty-protocol.ts   | 120 ++++++++++++
  src/parse-keypress.ts   |  45 +++--

How to verify:
  • Run `npm test` - should show all tests passing
  • Check `src/kitty-protocol.ts` exports expected types

Proposed commit:
  feat(kitty): M1 - Infrastructure Setup

  - T001: Create protocol types
  - T002: Implement parser
═══════════════════════════════════════════════════════════════
```

---

### Milestones & Active Checkpoints

Projects are decomposed into milestones - natural review points where work can be paused and approved.

- `/colony-plan` auto-detects milestones from phases in brief
- Each milestone has a checkpoint type: `review`, `commit`, `branch`, or `pr`
- Non-autonomous mode actively asks for approval via AskUserQuestion
- Autonomous mode logs and continues automatically

---

### Orchestrator Guardrails

**Structural constraint:** Removed Edit from orchestrator's allowed-tools.

- Orchestrator literally cannot edit files
- Forces worker spawns for any code changes
- Enhanced psychological warnings restored from pre-compression

**Feedback = Subtask:** Every feedback item becomes a formal subtask with full worker + inspector verification. No exceptions.

---

### CLI Updates

- `get-model` now always shows note when using explicit (non-inherit) model
- Removed `notifications.model_override_shown` tracking (always inform user)
- Dotted task ID support for subtasks (T001.1, T001.2)
- Config defaults updated: `orchestrator: "haiku"`

---

### Breaking Changes

None. Existing projects continue to work. New config defaults are backward compatible.

---

## v1.1.0 (2026-01-17)

### Performance Improvements

**2.6x faster execution** compared to v1.0.0, closing the gap with Ralph from 4.3x slower to just 1.7x slower.

| Metric | v1.0.0 | v1.1.0 | Change |
|--------|--------|--------|--------|
| Runtime | ~55 min | ~21 min | 2.6x faster |
| Total tokens | ~76k | ~70k | 8% reduction |
| Tasks generated | 9 | 6 | 33% fewer |
| Prompt size | 2,726 lines | 929 lines | 66% smaller |
| First-attempt success | 100% | 100% | Maintained |

### What Changed

1. **CLI for state management** - New `colony` CLI (`bin/colony`) replaces JSON file reads/writes with simple commands like `colony state list`, `colony state task-complete`. Reduces token usage and simplifies orchestration.

2. **Prompt compression** - Removed redundant warnings, condensed examples, eliminated verbose instructions. Commands are now 66% smaller while maintaining clarity.

3. **Configurable models** - Inspector defaults to Haiku (faster, cheaper for verification). All models configurable via `~/.colony/config.json`.

4. **Better task decomposition** - Improved planner creates fewer, more focused tasks. Quality over quantity.

5. **Plugin-relative paths** - Commands use `${CLAUDE_PLUGIN_ROOT}/bin/colony` for reliable CLI access across any installation.

### Why It's Faster

- **Less token overhead**: Compressed prompts mean faster parsing and less context used
- **Efficient state management**: CLI operations are faster than reading/writing JSON blobs
- **Smarter task sizing**: Fewer tasks = fewer agent spawns = less overhead
- **Haiku for verification**: Inspector tasks are simpler and don't need expensive models

---

## v1.0.0 (2026-01-16)

Initial release with:
- Task decomposition via `/colony-plan`
- Parallel execution via `/colony-run`
- Worker and Inspector agents
- Independent verification (worker can't mark itself complete)
- Git-aware workflow (branch strategy, smart commits)
- Full recovery (task-level resume from state.json)
- Project status tracking
