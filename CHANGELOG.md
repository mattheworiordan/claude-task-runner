# Changelog

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
