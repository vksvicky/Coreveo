#!/bin/bash
# Coreveo Development Script
# Runs build, test, and run in sequence

clear
echo "🛠️  Coreveo Development Script"
echo "=============================="

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "📁 Project Directory: $PROJECT_DIR"
cd "$PROJECT_DIR"

# Function to run a script
run_script() {
    local script_name=$1
    local script_path="scripts/$script_name"
    
    if [ -f "$script_path" ]; then
        echo ""
        echo "🔄 Running $script_name..."
        chmod +x "$script_path"
        if ./"$script_path"; then
            echo "✅ $script_name completed successfully!"
        else
            echo "❌ $script_name failed!"
            exit 1
        fi
    else
        echo "❌ Script not found: $script_path"
        exit 1
    fi
}

# Run all scripts in sequence
echo "🚀 Starting development workflow..."

# 1. Run tests first
run_script "test.sh"

# 2. Build the project
run_script "build.sh"

# 3. Ask if user wants to run the app
echo ""
read -p "🤔 Do you want to run the app now? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    run_script "run.sh"
else
    echo "✅ Development workflow completed!"
    echo "💡 To run the app later, use: ./scripts/run.sh"
fi

echo ""
echo "🎉 Development workflow finished successfully!"
