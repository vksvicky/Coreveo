#!/bin/bash

# Permission Diagnosis Script for Coreveo
# Shows which apps have FDA/Accessibility and helps identify the issue

echo "🔍 Coreveo Permission Diagnostic"
echo "================================"
echo ""

# Check FDA permissions in TCC database
echo "📊 Full Disk Access - Granted Apps:"
echo "-----------------------------------"
sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db \
    "SELECT client, auth_value, last_modified FROM access WHERE service='kTCCServiceSystemPolicyAllFiles';" 2>/dev/null || echo "⚠️  Cannot read system TCC database (requires root)"

echo ""
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
    "SELECT client, auth_value, last_modified FROM access WHERE service='kTCCServiceSystemPolicyAllFiles';" 2>/dev/null || echo "⚠️  No user TCC database"

echo ""
echo "📊 Accessibility - Granted Apps:"
echo "--------------------------------"
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
    "SELECT client, auth_value, last_modified FROM access WHERE service='kTCCServiceAccessibility';" 2>/dev/null || echo "⚠️  No entries found"

echo ""
echo "🔎 Looking for Coreveo entries..."
echo "--------------------------------"
echo "Bundle ID we're looking for: club.cycleruncode.Coreveo"
echo ""

# Check if Coreveo is in FDA
FDA_STATUS=$(sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
    "SELECT auth_value FROM access WHERE service='kTCCServiceSystemPolicyAllFiles' AND client='club.cycleruncode.Coreveo';" 2>/dev/null)

if [ -z "$FDA_STATUS" ]; then
    echo "❌ FDA: No entry found for club.cycleruncode.Coreveo"
else
    if [ "$FDA_STATUS" = "2" ]; then
        echo "✅ FDA: GRANTED (auth_value=$FDA_STATUS)"
    else
        echo "⚠️  FDA: Entry exists but denied (auth_value=$FDA_STATUS)"
    fi
fi

# Check if Coreveo is in Accessibility
ACC_STATUS=$(sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
    "SELECT auth_value FROM access WHERE service='kTCCServiceAccessibility' AND client='club.cycleruncode.Coreveo';" 2>/dev/null)

if [ -z "$ACC_STATUS" ]; then
    echo "❌ Accessibility: No entry found for club.cycleruncode.Coreveo"
else
    if [ "$ACC_STATUS" = "2" ]; then
        echo "✅ Accessibility: GRANTED (auth_value=$ACC_STATUS)"
    else
        echo "⚠️  Accessibility: Entry exists but denied (auth_value=$ACC_STATUS)"
    fi
fi

echo ""
echo "📁 App Locations:"
echo "----------------"

# Check common locations
LOCATIONS=(
    "/Applications/Coreveo.app"
    "$HOME/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/Coreveo.app"
    "$HOME/Library/Developer/Xcode/DerivedData/*/Build/Products/Release/Coreveo.app"
)

for loc in "${LOCATIONS[@]}"; do
    for app in $loc; do
        if [ -d "$app" ]; then
            echo "  Found: $app"
            BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app/Contents/Info.plist" 2>/dev/null)
            echo "    Bundle ID: $BUNDLE_ID"
            CODE_SIGN=$(codesign -dv "$app" 2>&1 | grep "Identifier=" | cut -d'=' -f2)
            echo "    Code Sign ID: $CODE_SIGN"
        fi
    done
done

echo ""
echo "💡 Diagnosis:"
echo "------------"
echo "The issue is likely that:"
echo "  1. You granted permissions to the app in /Applications"
echo "  2. But you're running a DIFFERENT app from Xcode"
echo "  3. Xcode's debug build has a different signature/location"
echo "  4. macOS sees these as two different apps!"
echo ""
echo "🔧 Solution:"
echo "  1. Build the app for Release"
echo "  2. Copy it to /Applications"
echo "  3. Remove old permission entries in System Settings"
echo "  4. Add the /Applications/Coreveo.app to permissions"
echo "  5. Quit and restart the app"
echo "  6. Run from /Applications, NOT from Xcode"
echo ""
echo "Or use: ./scripts/build_and_run.sh"

