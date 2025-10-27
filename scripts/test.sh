#!/bin/bash
# Coreveo Test Script
# Runs all tests for the Coreveo project

clear
echo "🧪 Coreveo Test Script"
echo "====================="

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "📁 Project Directory: $PROJECT_DIR"
cd "$PROJECT_DIR"

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo "⚠️  SwiftLint is not installed. Installing..."
    if command -v brew &> /dev/null; then
        brew install swiftlint
    else
        echo "❌ Homebrew not found. Please install SwiftLint manually:"
        echo "   brew install swiftlint"
        exit 1
    fi
fi

echo "🔍 Running SwiftLint..."
if swiftlint lint --strict; then
    echo "✅ SwiftLint passed!"
else
    echo "❌ SwiftLint failed!"
    echo "💡 Run 'swiftlint --fix' to auto-fix some issues"
    exit 1
fi

echo ""
echo "🧪 Running Unit Tests..."

# Clean and build for testing
echo "🧹 Cleaning previous build..."
swift package clean

echo "🔨 Building for testing..."
if swift build; then
    echo "✅ Build completed successfully!"
else
    echo "❌ Build failed!"
    exit 1
fi

# Run tests
echo "🧪 Running tests..."
if swift test; then
    echo "✅ All tests passed!"
else
    echo "❌ Some tests failed!"
    exit 1
fi

echo ""
echo "📊 Test Summary:"
echo "   ✅ SwiftLint: Passed"
echo "   ✅ Build: Successful"
echo "   ✅ Tests: All passed"
echo ""
echo "🎉 All checks completed successfully!"
