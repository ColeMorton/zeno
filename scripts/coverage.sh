#!/bin/bash
# Smart Contract Coverage Report Generator
# Generates LCOV and HTML coverage reports

set -e

echo "Running coverage analysis..."

# Generate LCOV report
forge coverage --report lcov

# Check if lcov.info was created
if [ ! -f lcov.info ]; then
    echo "Error: lcov.info not generated"
    exit 1
fi

echo "Coverage data generated: lcov.info"

# Check if genhtml is available
if command -v genhtml &> /dev/null; then
    echo "Generating HTML report..."

    # Create coverage directory
    mkdir -p coverage

    # Generate HTML report
    genhtml lcov.info -o coverage --branch-coverage --legend

    echo ""
    echo "HTML report generated: coverage/index.html"
    echo "Open in browser: open coverage/index.html"
else
    echo ""
    echo "Note: genhtml not found. Install lcov for HTML reports:"
    echo "  macOS: brew install lcov"
    echo "  Linux: apt install lcov"
    echo ""
    echo "Raw LCOV data available in: lcov.info"
fi

# Print summary
echo ""
echo "=== Coverage Summary ==="
forge coverage 2>&1 | tail -20
