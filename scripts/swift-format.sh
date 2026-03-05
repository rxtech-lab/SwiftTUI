#!/bin/sh

# Format staged Swift files with swift-format
# Usage: scripts/swift-format.sh [--all]
#   --all: format all Swift files, not just staged ones

set -e

if ! command -v swift-format >/dev/null 2>&1; then
    echo "error: swift-format not found. Install it with: brew install swift-format"
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)

if [ "$1" = "--all" ]; then
    find "$REPO_ROOT/Sources" "$REPO_ROOT/Tests" -name '*.swift' -print0 | xargs -0 swift-format format --in-place
    echo "Formatted all Swift files."
else
    STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACM -- '*.swift')

    if [ -z "$STAGED_SWIFT_FILES" ]; then
        echo "No staged Swift files to format."
        exit 0
    fi

    for file in $STAGED_SWIFT_FILES; do
        swift-format format --in-place "$file"
        git add "$file"
    done

    for file in $STAGED_SWIFT_FILES; do
        if ! swift-format lint "$file" 2>&1; then
            echo "swift-format lint failed. Please fix the issues above."
            exit 1
        fi
    done

    echo "Formatted staged Swift files."
fi
