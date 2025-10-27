#!/bin/bash
# Coreveo Run Script
# Runs the Coreveo application (assumes it's already built)

clear
echo "🚀 Coreveo Run Script"
echo "===================="

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "📁 Project Directory: $PROJECT_DIR"
cd "$PROJECT_DIR"

# Check if the app is already built
if [ ! -d ".build/release" ]; then
    echo "❌ App not built yet. Please run './scripts/build.sh' first."
    exit 1
fi

echo "🏃 Running Coreveo..."

# Run the built executable directly
if ./.build/release/Coreveo; then
    echo "✅ Coreveo ran successfully!"
else
    echo "❌ Failed to run Coreveo"
    exit 1
fi
