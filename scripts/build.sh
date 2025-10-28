#!/bin/bash
# Coreveo Build Script
# Compiles the Xcode project and updates build version in Info.plist

clear
echo "🏗️  Coreveo Build Script"
echo "========================"

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

# Generate version number
YEAR=$(date +%Y)
MONTH=$(date +%m)

# Get current build number from Info.plist
INFO_PLIST="Coreveo/Info.plist"
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
INFO_PLIST="Coreveo/Info.plist"
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
xcodebuild -project Coreveo.xcodeproj -scheme Coreveo clean

# Build the project
echo "🔨 Building Coreveo..."
if xcodebuild -project Coreveo.xcodeproj -scheme Coreveo -configuration Release build; then
    echo "✅ Build completed successfully!"
    echo ""
    echo "📊 Build Summary:"
    echo "   Version: $VERSION"
    echo "   Build Number: $BUILD_NUMBER_FORMATTED"
    echo "   Configuration: Release"
    echo "   Bundle ID: club.cycleruncode.Coreveo"
    echo ""
    echo "🎉 Coreveo is ready!"
    echo ""
    echo "📱 App location:"
    echo "   $(xcodebuild -project Coreveo.xcodeproj -scheme Coreveo -configuration Release -showBuildSettings | grep -E '^[[:space:]]*BUILT_PRODUCTS_DIR' | head -1 | sed 's/.*= //')Coreveo.app"
else
    echo "❌ Build failed!"
    exit 1
fi
