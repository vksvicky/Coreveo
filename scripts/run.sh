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

# Check if Xcode project exists
if [ ! -f "Coreveo.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Xcode project not found. Please run from Coreveo project root."
    exit 1
fi

# Find the built app (prefer Release, then Debug, then latest in DerivedData)
SCHEME="Coreveo"

# Try Release
RELEASE_DIR=$(xcodebuild -project Coreveo.xcodeproj -scheme "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null | grep -E '^[[:space:]]*BUILT_PRODUCTS_DIR' | head -1 | sed 's/.*= //')
if [ -n "$RELEASE_DIR" ]; then
    CANDIDATE_APP="$RELEASE_DIR/$SCHEME.app"
fi

# If not found, try Debug
if [ -z "$CANDIDATE_APP" ] || [ ! -d "$CANDIDATE_APP" ]; then
    DEBUG_DIR=$(xcodebuild -project Coreveo.xcodeproj -scheme "$SCHEME" -configuration Debug -showBuildSettings 2>/dev/null | grep -E '^[[:space:]]*BUILT_PRODUCTS_DIR' | head -1 | sed 's/.*= //')
    if [ -n "$DEBUG_DIR" ]; then
        CANDIDATE_APP="$DEBUG_DIR/$SCHEME.app"
    fi
fi

# If still not found, search DerivedData for the most recent Coreveo.app
if [ -z "$CANDIDATE_APP" ] || [ ! -d "$CANDIDATE_APP" ]; then
    DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
    CANDIDATE_APP=$(find "$DERIVED_DATA" -type d -name "$SCHEME.app" 2>/dev/null | sort -r | head -1)
fi

if [ -z "$CANDIDATE_APP" ] || [ ! -d "$CANDIDATE_APP" ]; then
    echo "❌ App not built yet. Please run './scripts/build.sh' first."
    exit 1
fi

echo "🏃 Running Coreveo..."
echo "📱 App location: $CANDIDATE_APP"

# Run the built app
if open "$CANDIDATE_APP"; then
    echo "✅ Coreveo launched successfully!"
else
    echo "❌ Failed to launch Coreveo"
    exit 1
fi
