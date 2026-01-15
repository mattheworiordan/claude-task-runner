# Architecture Overview

## System Components

```
┌─────────────────────────────────────────────────────────────┐
│                     Claude Task Runner                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐      ┌──────────────┐                    │
│  │     CLI      │─────▶│ Task Runner  │                    │
│  │  (Commander) │      │ (Orchestrator)│                    │
│  └──────────────┘      └──────┬───────┘                    │
│                               │                             │
│         ┌────────────────────┼─────────────────┐           │
│         │                    │                 │           │
│         ▼                    ▼                 ▼           │
│  ┌──────────────┐    ┌──────────────┐  ┌──────────────┐  │
│  │   Decomposer │    │   Executor   │  │   Reporter   │  │
│  │              │    │              │  │              │  │
│  │ - Parse task │    │ - Parallel   │  │ - Text       │  │
│  │ - Extract    │    │   execution  │  │ - JSON       │  │
│  │   steps      │    │ - Sequential │  │ - Markdown   │  │
│  │ - Analyze    │    │   execution  │  │ - File       │  │
│  │   deps       │    │              │  │   output     │  │
│  └──────────────┘    └──────┬───────┘  └──────────────┘  │
│                             │                             │
│                   ┌─────────┼──────────┐                  │
│                   │                    │                  │
│                   ▼                    ▼                  │
│            ┌──────────────┐     ┌──────────────┐         │
│            │   Verifier   │     │ Git Manager  │         │
│            │              │     │              │         │
│            │ - Run tests  │     │ - Stage      │         │
│            │ - Run lint   │     │ - Commit     │         │
│            │ - Run build  │     │ - Branch     │         │
│            │ - Check npm  │     │ - Diff       │         │
│            │   scripts    │     │              │         │
│            └──────────────┘     └──────────────┘         │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Input** → CLI receives task description or file
2. **Decomposition** → TaskDecomposer breaks task into sub-tasks
3. **Analysis** → Dependency analysis creates execution groups
4. **Execution** → TaskExecutor runs groups in parallel
5. **Verification** → Verifier checks each task (optional)
6. **Git Integration** → GitManager handles version control (optional)
7. **Reporting** → Reporter generates comprehensive output
8. **Output** → Results displayed in chosen format

## Task Lifecycle

```
┌──────────┐
│ PENDING  │
└────┬─────┘
     │
     ▼
┌──────────────┐
│ IN_PROGRESS  │
└────┬─────────┘
     │
     ├─────────────┐
     ▼             ▼
┌───────────┐ ┌─────────┐
│ COMPLETED │ │ FAILED  │
└───────────┘ └─────────┘
```

## Core Modules

### TaskDecomposer
- **Purpose**: Parse and analyze task descriptions
- **Input**: Task description (string)
- **Output**: Array of SubTask objects with dependencies
- **Features**:
  - Supports bullet points and numbered lists
  - Analyzes keywords for dependency detection
  - Creates parallelizable task groups

### TaskExecutor
- **Purpose**: Execute tasks with proper orchestration
- **Input**: SubTask arrays
- **Output**: TaskResult objects
- **Features**:
  - Parallel execution with configurable concurrency
  - Sequential execution for dependent tasks
  - Integration with Verifier and GitManager
  - Extensible for custom execution logic

### Verifier
- **Purpose**: Independent verification of task completion
- **Input**: SubTask
- **Output**: VerificationResult
- **Features**:
  - npm test execution
  - npm lint execution
  - npm build execution
  - Smart package.json script detection

### GitManager
- **Purpose**: Smart Git integration
- **Input**: Configuration and commands
- **Output**: Git operation results
- **Features**:
  - Stage changes
  - Create commits with templates
  - Branch management
  - Diff generation

### Reporter
- **Purpose**: Comprehensive reporting
- **Input**: Task and execution data
- **Output**: Formatted reports
- **Features**:
  - Multiple output formats (text, JSON, markdown)
  - File output support
  - Duration tracking
  - Success/failure statistics

## Configuration System

```typescript
{
  maxParallelTasks: number,        // Concurrency limit
  verificationEnabled: boolean,    // Enable/disable verification
  gitIntegration: {
    enabled: boolean,              // Enable/disable Git features
    autoCommit: boolean,           // Auto-commit after tasks
    autoStage: boolean,            // Auto-stage before verification
    branchPrefix: string,          // Prefix for new branches
    commitMessageTemplate: string  // Template for commits
  },
  reporting: {
    verbose: boolean,              // Verbose output
    outputFormat: string,          // text | json | markdown
    logFile: string                // Optional log file path
  }
}
```

## Extension Points

1. **Custom Executor**
   - Extend `TaskExecutor` class
   - Override `executeTask` method
   - Implement custom execution logic

2. **Custom Verifier**
   - Extend `Verifier` class
   - Add custom verification checks
   - Integrate additional tools

3. **Custom Reporter**
   - Extend `Reporter` class
   - Add custom output formats
   - Integrate with external systems

## Security Features

- ✅ No command injection vulnerabilities
- ✅ Safe npm script detection via package.json parsing
- ✅ Input sanitization in Git operations
- ✅ No arbitrary code execution from user input
- ✅ CodeQL verified (0 vulnerabilities)

## Performance Characteristics

- **Parallel Execution**: Configurable concurrency (default: 3)
- **Memory**: Minimal - task metadata only
- **Scalability**: Handles hundreds of sub-tasks
- **I/O**: Async operations for Git and verification

## Dependencies

- **commander**: CLI argument parsing
- **simple-git**: Git operations
- **chalk**: Terminal colors (available but not currently used)
- **ora**: Spinners (available but not currently used)
- **TypeScript**: Type safety and modern JavaScript
