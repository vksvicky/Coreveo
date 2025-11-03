#!/bin/bash

# Reset TCC permissions for Coreveo
# This completely removes the app from the permission system so we can start fresh

set -e

BUNDLE_ID="club.cycleruncode.Coreveo"

echo "🔄 Resetting Coreveo Permissions"
echo "================================="
echo ""
echo "This will:"
echo "  1. Remove ALL permission entries for Coreveo"
echo "  2. Force macOS to prompt for permissions again"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "🧹 Removing TCC database entries..."

# Reset FDA permission
tccutil reset SystemPolicyAllFiles "$BUNDLE_ID" 2>/dev/null && echo "  ✅ Reset Full Disk Access" || echo "  ℹ️  No FDA entry to reset"

# Reset Accessibility permission
tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null && echo "  ✅ Reset Accessibility" || echo "  ℹ️  No Accessibility entry to reset"

echo ""
echo "🔧 Now follow these steps:"
echo ""
echo "  1. Quit Coreveo if it's running:"
echo "     killall Coreveo"
echo ""
echo "  2. Open System Settings → Privacy & Security"
echo "     - Go to Full Disk Access"
echo "     - Remove any Coreveo entries you see"
echo "     - Go to Accessibility"  
echo "     - Remove any Coreveo entries you see"
echo ""
echo "  3. Run the app from /Applications:"
echo "     open /Applications/Coreveo.app"
echo ""
echo "  4. The app will prompt for Accessibility - click 'Open System Settings'"
echo ""
echo "  5. In System Settings, click the + button and add:"
echo "     /Applications/Coreveo.app"
echo ""
echo "  6. Toggle the switch ON"
echo ""
echo "  7. Quit and restart Coreveo"
echo ""
echo "  8. When prompted for Full Disk Access, repeat steps 4-7"
echo ""
echo "✅ Done! The TCC database has been reset."
echo ""

# Kill Coreveo if running
killall Coreveo 2>/dev/null && echo "🛑 Quit running Coreveo instance" || true

