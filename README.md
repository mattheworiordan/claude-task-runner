# Claude Task Runner

A powerful task orchestration tool that decomposes complex coding tasks into parallel sub-tasks with independent verification, smart Git integration, and comprehensive reporting for Claude Code.

## Features

- 🚀 **Task Decomposition**: Automatically breaks down complex tasks into manageable sub-tasks
- ⚡ **Parallel Execution**: Executes independent tasks in parallel for faster completion
- 🔍 **Independent Verification**: Verifies each task with tests, linting, and builds
- 🔗 **Smart Git Integration**: Automatic staging, commits, and branch management
- 📊 **Comprehensive Reporting**: Detailed reports in text, JSON, or Markdown format
- 🎯 **Dependency Management**: Analyzes task dependencies and creates optimal execution order

## Installation

```bash
npm install -g claude-task-runner
```

Or use it directly with npx:

```bash
npx claude-task-runner run "your task description"
```

## Usage

### Basic Usage

Run a task from a description:

```bash
claude-task-runner run "Implement user authentication with login and signup"
```

### Advanced Usage

Run with custom options:

```bash
claude-task-runner run "Refactor codebase" \
  --parallel 5 \
  --auto-commit \
  --auto-stage \
  --format markdown \
  --log-file report.md
```

### Using a Task File

Create a task file (e.g., `task.txt`):

```
- Set up project structure
- Create database models
- Implement API endpoints
- Add authentication middleware
- Write tests
- Update documentation
```

Then run it:

```bash
claude-task-runner run task.txt
```

### Configuration File

Initialize a configuration file:

```bash
claude-task-runner init
```

This creates `task-runner.config.json`:

```json
{
  "maxParallelTasks": 3,
  "verificationEnabled": false,
  "gitIntegration": {
    "enabled": true,
    "autoCommit": false,
    "autoStage": false,
    "branchPrefix": "task",
    "commitMessageTemplate": "Complete task: {description}"
  },
  "reporting": {
    "verbose": true,
    "outputFormat": "text"
  }
}
```

Use the configuration file:

```bash
claude-task-runner run "your task" --config task-runner.config.json
```

## CLI Options

### `run` Command

- `<task>`: Task description or path to task file (required)
- `-p, --parallel <number>`: Maximum number of parallel tasks (default: 3)
- `--no-verify`: Disable verification
- `--no-git`: Disable Git integration
- `--auto-commit`: Auto-commit changes after each task
- `--auto-stage`: Auto-stage changes before verification
- `--format <format>`: Output format - text, json, or markdown (default: text)
- `--log-file <file>`: Save report to specified file
- `--config <file>`: Load configuration from file

### `init` Command

- `-o, --output <file>`: Output file path (default: task-runner.config.json)

## How It Works

1. **Task Decomposition**: The task description is parsed and broken down into sub-tasks
2. **Dependency Analysis**: Dependencies between sub-tasks are analyzed
3. **Execution Planning**: Tasks are organized into groups that can run in parallel
4. **Parallel Execution**: Each group is executed with configurable parallelism
5. **Verification**: Each task is verified with tests, linting, and builds (if enabled)
6. **Git Integration**: Changes are staged and committed (if enabled)
7. **Reporting**: A comprehensive report is generated in your chosen format

## Task Description Format

The task runner supports multiple formats:

### Bullet Points

```
- Task one
- Task two
- Task three
```

### Numbered Lists

```
1. First task
2. Second task
3. Third task
```

### Dependencies

Use keywords like "after", "once", "then", or "following" to indicate dependencies:

```
- Set up project
- Install dependencies after setting up project
- Build the project once dependencies are installed
```

## Examples

### Example 1: Simple Task List

```bash
claude-task-runner run "
- Create new React component
- Add styling with CSS modules
- Write unit tests
- Update Storybook
"
```

### Example 2: With Verification

```bash
claude-task-runner run "Refactor authentication module" \
  --verify \
  --parallel 2
```

### Example 3: Full CI/CD Integration

```bash
claude-task-runner run "Release v2.0" \
  --verify \
  --auto-stage \
  --auto-commit \
  --format markdown \
  --log-file release-report.md
```

## Output Formats

### Text Format (Default)

Clean, readable terminal output with emoji indicators.

### JSON Format

Structured JSON for programmatic processing:

```bash
claude-task-runner run "task" --format json > report.json
```

### Markdown Format

Documentation-ready markdown reports:

```bash
claude-task-runner run "task" --format markdown --log-file REPORT.md
```

## Integration with Claude Code

This tool is designed to work seamlessly with Claude Code AI assistants. Claude can:

1. Generate task descriptions
2. Decompose complex requests into structured tasks
3. Execute tasks through this runner
4. Review and verify completed work
5. Generate comprehensive reports

### Framework vs. Implementation

The current implementation provides a **complete orchestration framework** including:
- Task decomposition and dependency analysis
- Parallel execution management
- Independent verification system
- Smart Git integration
- Comprehensive reporting

The actual task execution is intentionally simplified (simulated) to demonstrate the framework. For production use, you can extend the `TaskExecutor` class to integrate with:
- Claude AI API for intelligent task execution
- Custom scripts and automation tools
- CI/CD systems
- Other execution backends

See [EXTENDING.md](EXTENDING.md) for detailed examples of custom executor implementation.

## Development

### Build from Source

```bash
git clone https://github.com/mattheworiordan/claude-task-runner.git
cd claude-task-runner
npm install
npm run build
```

### Run the Demo

To see all features in action:

```bash
./demo.sh
```

This interactive demo showcases:
- Basic task execution
- Task file processing
- Different output formats (text, JSON, markdown)
- Configuration generation
- Parallel execution

### Run in Development Mode

```bash
npm run dev -- run "your task"
```

## License

MIT

## Author

Matthew O'Riordan

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
