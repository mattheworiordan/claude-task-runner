# Changelog

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

## v1.0.0 (2026-01-16)

Initial release with:
- Task decomposition via `/colony-plan`
- Parallel execution via `/colony-run`
- Worker and Inspector agents
- Project status tracking
