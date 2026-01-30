#!/bin/bash
# Test that the Rust engine works correctly
# Run from project root

set -e

echo "=== Engine Integration Tests ==="

cd "$(dirname "$0")/.."

# Run unit tests
echo "Running unit tests..."
cargo test -p ai-english-engine --all-features

echo ""
echo "Running clippy..."
cargo clippy -p ai-english-engine --all-targets -- -D warnings

echo ""
echo "Checking formatting..."
cargo fmt -p ai-english-engine -- --check

echo ""
echo "=== All Engine Tests Passed ==="
