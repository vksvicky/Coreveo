#!/bin/bash
# Coreveo Version Management Script
# Updates version numbers in Info.plist based on year.month.buildnumber format

set -e

# Get current date components
YEAR=$(date +%Y)
MONTH=$(date +%m)
BUILD_NUMBER=$(git rev-list --count HEAD)

# Create version string
VERSION="${YEAR}.${MONTH}.${BUILD_NUMBER}"

echo "🏷️  Coreveo Version Management"
echo "================================"
echo "Year: ${YEAR}"
echo "Month: ${MONTH}"
echo "Build Number: ${BUILD_NUMBER}"
echo "Version: ${VERSION}"
echo ""

# Check if Info.plist exists
INFO_PLIST="Coreveo/Info.plist"
if [ ! -f "$INFO_PLIST" ]; then
    echo "❌ Error: Info.plist not found at $INFO_PLIST"
    echo "Please run this script from the project root directory."
    exit 1
fi

# Update CFBundleShortVersionString (Marketing Version)
echo "📝 Updating CFBundleShortVersionString to ${VERSION}..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$INFO_PLIST"

# Update CFBundleVersion (Build Number)
echo "📝 Updating CFBundleVersion to ${BUILD_NUMBER}..."
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "$INFO_PLIST"

# Verify the changes
echo ""
echo "✅ Version updated successfully!"
echo "================================"
echo "Marketing Version: $(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
echo "Build Number: $(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"

# Create git tag if this is a release
if [ "$1" = "--tag" ]; then
    echo ""
    echo "🏷️  Creating git tag..."
    git tag -a "v${VERSION}" -m "Release version ${VERSION}"
    echo "✅ Git tag 'v${VERSION}' created successfully!"
    echo "💡 Run 'git push origin v${VERSION}' to push the tag to remote."
fi

echo ""
echo "🎉 Version management complete!"
