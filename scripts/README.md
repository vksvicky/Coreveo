# Coreveo Scripts

This directory contains all the build, test, and development scripts for Coreveo.

## 📋 Available Scripts

### **🏗️ build.sh**
Builds the Xcode project and updates version numbers.

**Features:**
- Generates version number (year.month.buildnumber)
- Updates Info.plist with version and build number
- Cleans previous builds
- Builds Xcode project in release configuration
- Shows build summary
- Creates proper macOS app bundle with icons

**Usage:**
```bash
./scripts/build.sh
```

### **🚀 run.sh**
Runs the Coreveo application (assumes it's already built).

**Features:**
- Checks if Xcode project exists
- Finds the built app bundle
- Launches the app using `open` command
- No building or version updates
- Fast execution

**Usage:**
```bash
./scripts/run.sh
```

**Note:** Run `./scripts/build.sh` first if the app hasn't been built yet.

### **🧪 test.sh**
Runs all tests and code quality checks.

**Features:**
- Runs SwiftLint for code quality
- Builds the project
- Executes all unit tests
- Shows comprehensive test summary

**Usage:**
```bash
./scripts/test.sh
```

### **🛠️ dev.sh**
Complete development workflow script.

**Features:**
- Runs tests first
- Builds the project
- Optionally runs the app
- Complete development cycle

**Usage:**
```bash
./scripts/dev.sh
```

### **🏷️ version.sh**
Updates version numbers in Info.plist.

**Features:**
- Generates version from date and git commit count
- Updates CFBundleShortVersionString
- Updates CFBundleVersion
- Creates git tags (with --tag flag)

**Usage:**
```bash
./scripts/version.sh
./scripts/version.sh --tag  # Also creates git tag
```

### **🌐 build-universal.sh**
Creates a universal macOS app bundle supporting both Intel and Apple Silicon.

**Features:**
- Builds for Intel x64 architecture
- Builds for Apple Silicon (ARM64) architecture  
- Creates universal binary using `lipo`
- Supports M1, M2, M3, M4, M5 Macs
- Creates proper .app bundle with icons
- Creates app in `release/` folder for clean organization
- Fixes Info.plist placeholder values
- Shows build statistics and file sizes
- Optionally launches the app after building

**Usage:**
```bash
./scripts/build-universal.sh
```

**Note:** This creates a universal binary that runs natively on both Intel and Apple Silicon Macs. The app bundle is created in the `release/` folder to keep the project root clean.

## 🎯 Quick Start

### **For Development:**
```bash
# Run complete development workflow
./scripts/dev.sh
```

### **For Testing:**
```bash
# Run all tests and quality checks
./scripts/test.sh
```

### **For Building:**
```bash
# Build and update version
./scripts/build.sh
```

### **For Running:**
```bash
# Build first (if not already built)
./scripts/build.sh

# Then run the app
./scripts/run.sh
```

## 📁 Project Structure

```
Coreveo/
├── scripts/
│   ├── build.sh           # Build script
│   ├── run.sh             # Run script
│   ├── dev.sh             # Development workflow
│   ├── version.sh          # Version management
│   └── build-universal.sh # Universal build script
├── Coreveo/
│   ├── Sources/           # Swift source files
│   └── Resources/
│       ├── Info.plist     # App configuration
│       ├── Coreveo.png    # App icon
│       └── Assets.xcassets/ # Asset catalog
├── CoreveoTests/          # Unit tests
└── release/               # Generated app bundles (created by build-universal.sh)
```

## 🔧 Requirements

- **Xcode 15.0+**
- **Swift 5.9+**
- **macOS 14+**
- **SwiftLint** (installed via Homebrew)
- **Git** (for version numbering)

## 📝 Notes

- All scripts include `clear` at the start for clean output
- Scripts are designed to be run from the project root
- Version numbers follow format: `year.month.buildnumber`
- Bundle identifier: `club.cycleruncode.Coreveo`
- All scripts are executable and include error handling
