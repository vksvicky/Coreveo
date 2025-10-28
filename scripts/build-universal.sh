#!/bin/bash

# Clear terminal
clear

echo "🚀 Coreveo Universal Build Script"
echo "================================="
echo ""

# Check if we're in the right directory
if [ ! -f "Coreveo.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Please run this script from the Coreveo project root directory"
    exit 1
fi

# Set variables
APP_NAME="Coreveo"
RELEASE_DIR="release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
BUILD_DIR="DerivedData"
UNIVERSAL_DIR="$BUILD_DIR/universal"
APP_DIR="$APP_BUNDLE/Contents"

echo "📦 Building universal macOS app bundle..."
echo "   Supporting: Intel x64 + Apple Silicon (M1-M5)"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$RELEASE_DIR"
rm -rf "$UNIVERSAL_DIR"

# Create universal build directory
mkdir -p "$UNIVERSAL_DIR"

echo "🔨 Building for Intel x64..."
xcodebuild -project Coreveo.xcodeproj -scheme Coreveo -configuration Release -arch x86_64 build
if [ $? -ne 0 ]; then
    echo "❌ Intel x64 build failed!"
    exit 1
fi

# Copy Intel build
INTEL_BUILD_PATH=$(xcodebuild -project Coreveo.xcodeproj -scheme Coreveo -configuration Release -arch x86_64 -showBuildSettings | grep -E '^[[:space:]]*BUILT_PRODUCTS_DIR' | head -1 | sed 's/.*= //')
cp "$INTEL_BUILD_PATH/Coreveo.app/Contents/MacOS/Coreveo" "$UNIVERSAL_DIR/Coreveo-x86_64"

echo "🔨 Building for Apple Silicon (ARM64)..."
xcodebuild -project Coreveo.xcodeproj -scheme Coreveo -configuration Release -arch arm64 build
if [ $? -ne 0 ]; then
    echo "❌ ARM64 build failed!"
    exit 1
fi

# Copy ARM64 build
ARM64_BUILD_PATH=$(xcodebuild -project Coreveo.xcodeproj -scheme Coreveo -configuration Release -arch arm64 -showBuildSettings | grep -E '^[[:space:]]*BUILT_PRODUCTS_DIR' | head -1 | sed 's/.*= //')
cp "$ARM64_BUILD_PATH/Coreveo.app/Contents/MacOS/Coreveo" "$UNIVERSAL_DIR/Coreveo-arm64"

echo "🔗 Creating universal binary..."
lipo -create \
    "$UNIVERSAL_DIR/Coreveo-x86_64" \
    "$UNIVERSAL_DIR/Coreveo-arm64" \
    -output "$UNIVERSAL_DIR/Coreveo"

if [ $? -ne 0 ]; then
    echo "❌ Universal binary creation failed!"
    exit 1
fi

echo "✅ Universal binary created successfully!"
echo ""

# Create app bundle structure
echo "📱 Creating macOS app bundle..."
mkdir -p "$RELEASE_DIR"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

# Copy universal executable
cp "$UNIVERSAL_DIR/Coreveo" "$APP_DIR/MacOS/"
chmod +x "$APP_DIR/MacOS/Coreveo"

# Copy Info.plist and fix placeholder values
cp "Coreveo/Info.plist" "$APP_DIR/"
plutil -replace CFBundleExecutable -string "Coreveo" "$APP_DIR/Info.plist"
plutil -replace CFBundleName -string "Coreveo" "$APP_DIR/Info.plist"

# Copy resources from the built app
if [ -d "$ARM64_BUILD_PATH/Coreveo.app/Contents/Resources" ]; then
    cp -r "$ARM64_BUILD_PATH/Coreveo.app/Contents/Resources"/* "$APP_DIR/Resources/"
fi

echo "✅ App bundle created: $APP_BUNDLE"
echo ""

# Verify universal binary
echo "🔍 Verifying universal binary..."
file "$APP_DIR/MacOS/Coreveo"
echo ""

# Get file sizes
INTEL_SIZE=$(stat -f%z "$UNIVERSAL_DIR/Coreveo-x86_64")
ARM64_SIZE=$(stat -f%z "$UNIVERSAL_DIR/Coreveo-arm64")
UNIVERSAL_SIZE=$(stat -f%z "$UNIVERSAL_DIR/Coreveo")

echo "📊 Build Statistics:"
echo "   Intel x64:     $(numfmt --to=iec $INTEL_SIZE)"
echo "   ARM64:         $(numfmt --to=iec $ARM64_SIZE)"
echo "   Universal:     $(numfmt --to=iec $UNIVERSAL_SIZE)"
echo ""

echo "🎉 Universal build complete!"
echo ""
echo "📋 Next steps:"
echo "1. Test on Intel Mac: ./$APP_BUNDLE/Contents/MacOS/Coreveo"
echo "2. Test on Apple Silicon: ./$APP_BUNDLE/Contents/MacOS/Coreveo"
echo "3. Launch GUI: open $APP_BUNDLE"
echo "4. Drag to Applications folder for system-wide installation"
echo ""
echo "💡 The app will now appear in System Settings with proper icons"
echo "   when you request accessibility permissions!"
echo ""

# Optional: Launch the app
read -p "🚀 Launch Coreveo now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Launching Coreveo..."
    open "$APP_BUNDLE"
fi
