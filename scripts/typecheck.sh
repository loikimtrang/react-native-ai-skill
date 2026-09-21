#!/usr/bin/env bash
# typecheck.sh — Definition-of-done check for an Expo/React Native + TypeScript project.
# Usage: bash typecheck.sh [/path/to/react-native-project]
# Prints "typecheck PASS" or "typecheck FAIL" + exits 0/1.
set -euo pipefail

REPO_ROOT="${1:-$(pwd)}"

if [ ! -f "$REPO_ROOT/package.json" ]; then
  echo "typecheck FAIL: no package.json found under $REPO_ROOT"
  exit 1
fi

if [ ! -f "$REPO_ROOT/tsconfig.json" ]; then
  echo "typecheck FAIL: no tsconfig.json found under $REPO_ROOT"
  exit 1
fi

echo "[typecheck] Running tsc --noEmit…"
cd "$REPO_ROOT"
if npx tsc --noEmit -p . --pretty 2>&1 | tail -40; then
  echo "typecheck PASS"
  exit 0
else
  echo "typecheck FAIL"
  exit 1
fi
