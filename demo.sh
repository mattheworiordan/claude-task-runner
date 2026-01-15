#!/bin/bash

# Demo script for Claude Task Runner
# This demonstrates all features of the task runner

echo "======================================"
echo "Claude Task Runner - Feature Demo"
echo "======================================"
echo ""

# Test 1: Basic task execution
echo "Test 1: Basic Task Execution"
echo "------------------------------"
node dist/cli/index.js run "- Task one
- Task two  
- Task three" --no-verify --no-git

echo ""
echo "Press Enter to continue..."
read

# Test 2: Using a task file
echo "Test 2: Task File Execution"
echo "------------------------------"
node dist/cli/index.js run examples/api-task.txt --no-verify --no-git --parallel 5

echo ""
echo "Press Enter to continue..."
read

# Test 3: Markdown output
echo "Test 3: Markdown Output Format"
echo "------------------------------"
node dist/cli/index.js run examples/frontend-task.txt --format markdown --no-verify --no-git

echo ""
echo "Press Enter to continue..."
read

# Test 4: JSON output
echo "Test 4: JSON Output Format"
echo "------------------------------"
node dist/cli/index.js run "- Initialize project
- Install dependencies
- Configure settings" --format json --no-verify --no-git

echo ""
echo "Press Enter to continue..."
read

# Test 5: Init config
echo "Test 5: Initialize Configuration"
echo "------------------------------"
node dist/cli/index.js init -o demo-config.json
echo ""
cat demo-config.json
rm demo-config.json

echo ""
echo "Press Enter to continue..."
read

# Test 6: Help command
echo "Test 6: Help Information"
echo "------------------------------"
node dist/cli/index.js --help

echo ""
echo "======================================"
echo "Demo Complete!"
echo "======================================"
