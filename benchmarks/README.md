# Colony Benchmarks

This folder contains reproducible benchmarks comparing Colony against Ralph (and potentially other approaches).

## v1.2.0 Benchmark: Kitty Keyboard Protocol

**Test Repository:** [vadimdemedes/ink](https://github.com/vadimdemedes/ink)
**Base Commit:** `2aaa8b4` (Fix link for GitHub Copilot CLI in readme)
**Task:** Implement Kitty Keyboard Protocol support for the `useInput` hook
**Brief:** [kitty-protocol-brief.md](./kitty-protocol-brief.md)

### Results Summary

| Metric | Ralph | Colony v1.2 | Winner |
|--------|-------|-------------|--------|
| **Runtime** | 12m 39s | ~12 min | Tie |
| **Lint Errors** | 419 | 0 | **Colony** |
| **Lines of Code** | 537 | 165 | **Colony** (3.3x leaner) |
| **Time to Merge** | ~72 min | ~12 min | **Colony** |
| **Quality Score** | ~23/100 | ~100/100 | **Colony** |

**Full report:** [v1.2-results.md](./v1.2-results.md)

### How to Reproduce

#### Setup

```bash
# Clone ink repository
git clone https://github.com/vadimdemedes/ink.git
cd ink

# Checkout the base commit
git checkout 2aaa8b4

# Create worktrees for isolated testing
git worktree add ../ink-ralph ralph-test
git worktree add ../ink-colony colony-test

# Install dependencies in each
cd ../ink-ralph && npm install
cd ../ink-colony && npm install
```

#### Run Ralph Test

```bash
cd ink-ralph

# Start Claude Code
claude

# Run Ralph with this prompt:
```

**Ralph Prompt:**
```
<ralph_loop>
You are implementing a feature. Work autonomously until complete.

After EACH response, check: is the feature fully complete and tested?
- If NO: continue working
- If YES: output <promise>COMPLETE</promise>

TASK:
Implement Kitty Keyboard Protocol support for the useInput hook in Ink.
See: https://github.com/vadimdemedes/ink/issues/824

Requirements:
- Detect terminal support for Kitty keyboard protocol
- Parse Kitty escape sequences (CSI number ; modifiers u)
- Update useInput hook to expose modifier information
- Fall back gracefully to legacy parsing
- Add tests, all existing tests must pass
- No breaking changes to useInput API

Success criteria:
- shift+enter distinguishable from enter
- ctrl+i distinguishable from tab
- All tests pass
</ralph_loop>
```

**Measure:**
- Runtime: Note start/end time
- After completion: `npx xo src/kitty*.ts 2>&1 | grep -c "✖"` (lint errors)
- Lines: `wc -l src/kitty*.ts`

#### Run Colony Test

```bash
cd ink-colony

# Copy the brief
cp /path/to/colony/benchmarks/kitty-protocol-brief.md .working/brief.md

# Start Claude Code
claude

# Plan and execute (2 commands)
/colony-plan
/colony-run autonomous
```

**Measure:**
- Runtime: Check `.working/colony/*/state.json` execution_log timestamps
- Lint errors: `npx xo src/kitty*.ts 2>&1 | grep -c "✖"`
- Lines: `wc -l src/kitty*.ts`

### Quality Scoring Methodology

```
Quality Score = (
  Lint Score (30%) +
  Conciseness Score (25%) +
  Simplicity Score (25%) +
  Structure Score (20%)
)

Where:
- Lint Score = 100 if 0 errors, else max(0, 100 - errors)
- Conciseness = 100 * (baseline / actual_lines), capped at 100
- Simplicity = 100 * (baseline / actual_returns), capped at 100
- Structure = based on conditionals and function counts
```

### Historical Results

| Version | Runtime | vs Ralph | Lint Errors | Notes |
|---------|---------|----------|-------------|-------|
| v1.0.0 | ~55 min | 4.3x slower | 0 | Initial release |
| v1.1.0 | ~21 min | 1.7x slower | 0 | CLI + prompt compression |
| v1.2.0 | ~12 min | Same | 0 | Haiku orchestrator |

### Contributing

To add a new benchmark:

1. Create a brief in `benchmarks/` describing the task
2. Document the test repository and base commit
3. Run both approaches and record metrics
4. Add results to this README and create a detailed report
