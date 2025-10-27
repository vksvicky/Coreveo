#!/bin/bash
# Coreveo Build Script
# Compiles the Swift package and updates build version in Info.plist

clear
echo "🏗️  Coreveo Build Script"
echo "========================"

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "📁 Project Directory: $PROJECT_DIR"
cd "$PROJECT_DIR"

# Generate version number
YEAR=$(date +%Y)
MONTH=$(date +%m)

# Get current build number from Info.plist
INFO_PLIST="Coreveo/Resources/Info.plist"
if [ -f "$INFO_PLIST" ]; then
    CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "0")
else
    CURRENT_BUILD="0"
fi

# Increment build number
BUILD_NUMBER=$((10#$CURRENT_BUILD + 1))

# Format build number with leading zero (2 digits)
BUILD_NUMBER_FORMATTED=$(printf "%02d" $BUILD_NUMBER)
VERSION="${YEAR}.${MONTH}.${BUILD_NUMBER_FORMATTED}"

echo "🏷️  Generated Version: $VERSION"
echo "📝 Previous Build: $CURRENT_BUILD"
echo "📝 New Build Number: $BUILD_NUMBER_FORMATTED"

# Update Info.plist with version
INFO_PLIST="Coreveo/Resources/Info.plist"
if [ -f "$INFO_PLIST" ]; then
    echo "📝 Updating Info.plist..."
    
    # Update CFBundleShortVersionString (Marketing Version)
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$INFO_PLIST"
    
    # Update CFBundleVersion (Build Number)
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER_FORMATTED}" "$INFO_PLIST"
    
    echo "✅ Info.plist updated successfully!"
else
    echo "❌ Error: Info.plist not found at $INFO_PLIST"
    exit 1
fi

# Clean previous build
echo "🧹 Cleaning previous build..."
swift package clean

# Build the project
echo "🔨 Building Coreveo..."
if swift build --configuration release; then
    echo "✅ Build completed successfully!"
    echo ""
    echo "📊 Build Summary:"
    echo "   Version: $VERSION"
    echo "   Build Number: $BUILD_NUMBER_FORMATTED"
    echo "   Configuration: Release"
    echo "   Bundle ID: club.cycleruncode.Coreveo"
    echo ""
    echo "🎉 Coreveo is ready!"
else
    echo "❌ Build failed!"
    exit 1
fi
