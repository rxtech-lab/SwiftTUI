#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLES_DIR="$REPO_ROOT/Examples"

failed=()

for example in "$EXAMPLES_DIR"/*/; do
    name=$(basename "$example")
    if [ ! -f "$example/Package.swift" ]; then
        echo "Skipping $name (no Package.swift)"
        continue
    fi
    echo "Building example: $name"
    if swift build --package-path "$example"; then
        echo "  OK"
    else
        echo "  FAILED"
        failed+=("$name")
    fi
done

if [ ${#failed[@]} -ne 0 ]; then
    echo ""
    echo "Failed examples: ${failed[*]}"
    exit 1
fi

echo ""
echo "All examples built successfully."
