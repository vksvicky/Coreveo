# Coreveo Development Plan

**Versioning, Code Quality, and CI/CD Setup**

This document outlines the development practices and automation setup for Coreveo before we begin implementation.

## 📋 Table of Contents

1. [Versioning Pattern](#versioning-pattern)
2. [Code Quality & Pre-Commit Hooks](#code-quality--pre-commit-hooks)
3. [Code Review Checklist](#code-review-checklist)
4. [GitHub CI/CD Pipeline](#github-cicd-pipeline)
5. [Development Workflow](#development-workflow)

---

## 🏷️ Versioning Pattern

### **Format: `year.month.buildnumber`**

**Examples:**
- `2025.01.1` - January 2025, Build 1
- `2025.01.2` - January 2025, Build 2
- `2025.02.1` - February 2025, Build 1

### **Implementation**

#### **1. Automated Version Script**
```bash
#!/bin/bash
# scripts/version.sh

YEAR=$(date +%Y)
MONTH=$(date +%m)
BUILD_NUMBER=$(git rev-list --count HEAD)

VERSION="${YEAR}.${MONTH}.${BUILD_NUMBER}"
echo "Setting version to: ${VERSION}"

# Update Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" Coreveo/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" Coreveo/Info.plist

echo "Version updated successfully"
```

#### **2. Xcode Build Settings**
- **CFBundleShortVersionString**: `$(YEAR).$(MONTH).$(BUILD_NUMBER)`
- **CFBundleVersion**: `$(BUILD_NUMBER)`
- **MARKETING_VERSION**: `$(YEAR).$(MONTH).$(BUILD_NUMBER)`

#### **3. Git Tagging**
```bash
# Tag releases
git tag -a "v${VERSION}" -m "Release version ${VERSION}"
git push origin "v${VERSION}"
```

---

## 🔍 Code Quality & Pre-Commit Hooks

### **SwiftLint Configuration**

#### **1. Install SwiftLint**
```bash
brew install swiftlint
```

#### **2. SwiftLint Configuration (.swiftlint.yml)**
```yaml
# Coreveo SwiftLint Configuration
disabled_rules:
  - trailing_whitespace
  - line_length

opt_in_rules:
  - empty_count
  - empty_string
  - force_unwrapping
  - implicitly_unwrapped_optional
  - overridden_super_call
  - prohibited_interface_builder
  - redundant_nil_coalescing
  - redundant_type_annotation
  - switch_case_on_newline
  - vertical_parameter_alignment_on_call
  - yoda_condition

included:
  - Coreveo
  - CoreveoTests
  - CoreveoUITests

excluded:
  - Pods
  - .build
  - DerivedData

line_length:
  warning: 120
  error: 200

function_body_length:
  warning: 50
  error: 100

file_length:
  warning: 400
  error: 1000

type_body_length:
  warning: 200
  error: 500

cyclomatic_complexity:
  warning: 10
  error: 20

identifier_name:
  min_length: 2
  max_length: 40

type_name:
  min_length: 3
  max_length: 40

reporter: "xcode"
```

#### **3. Pre-Commit Hook**
```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "🔍 Running pre-commit checks..."

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo "❌ SwiftLint is not installed. Please install it using 'brew install swiftlint'."
    exit 1
fi

# Run SwiftLint
echo "📝 Running SwiftLint..."
swiftlint lint --strict
LINT_RESULT=$?

if [ $LINT_RESULT -ne 0 ]; then
    echo "❌ SwiftLint detected issues. Please fix them before committing."
    echo "💡 Run 'swiftlint --fix' to auto-fix some issues."
    exit 1
fi

# Run unit tests
echo "🧪 Running unit tests..."
xcodebuild test -project Coreveo.xcodeproj -scheme Coreveo -destination 'platform=macOS' -quiet
TEST_RESULT=$?

if [ $TEST_RESULT -ne 0 ]; then
    echo "❌ Unit tests failed. Please fix them before committing."
    exit 1
fi

echo "✅ All pre-commit checks passed!"
exit 0
```

#### **4. Commit Message Hook**
```bash
#!/bin/bash
# .git/hooks/commit-msg

COMMIT_MSG_FILE=$1
COMMIT_MSG=$(cat $COMMIT_MSG_FILE)

# Valid commit prefixes
VALID_PREFIXES=(
    "feat:"      # New feature
    "fix:"       # Bug fix
    "docs:"      # Documentation
    "style:"     # Code style changes
    "refactor:"  # Code refactoring
    "test:"      # Adding tests
    "chore:"     # Maintenance tasks
    "perf:"      # Performance improvements
    "ci:"        # CI/CD changes
    "build:"     # Build system changes
)

# Check if commit message starts with valid prefix
VALID_COMMIT=false
for prefix in "${VALID_PREFIXES[@]}"; do
    if [[ $COMMIT_MSG == $prefix* ]]; then
        VALID_COMMIT=true
        break
    fi
done

if [ "$VALID_COMMIT" = false ]; then
    echo "❌ Invalid commit message format!"
    echo "📝 Commit message must start with one of:"
    printf "   %s\n" "${VALID_PREFIXES[@]}"
    echo ""
    echo "💡 Example: feat: add CPU monitoring dashboard"
    exit 1
fi

echo "✅ Commit message format is valid"
exit 0
```

---

## 📋 Code Review Checklist

### **Swift Code Review Checklist**

Based on industry best practices from [Swift Code Review Checklist](https://github.com/FadiOssama/Swift-Code-Review-Checklist/blob/master/CHECKLIST.md), [Code Review Checklist](https://medium.com/@ashokrwt/code-review-checklist-483614b91821), and [Redwerk Swift Checklist](https://redwerk.com/blog/swift-code-review-checklist-manage-it-easily/).

#### **🔍 Code Quality**

- [ ] **Code follows Swift style guidelines**
- [ ] **No force unwrapping (`!`) without proper justification**
- [ ] **Proper error handling with `do-catch` blocks**
- [ ] **No magic numbers - use constants or enums**
- [ ] **Functions are focused and do one thing**
- [ ] **No code duplication (DRY principle)**
- [ ] **Proper use of access control (`private`, `internal`, `public`)**
- [ ] **No unused variables, imports, or code**

#### **🏗️ Architecture & Design**

- [ ] **Follows MVVM or appropriate architecture pattern**
- [ ] **Proper separation of concerns**
- [ ] **No tight coupling between components**
- [ ] **Uses dependency injection where appropriate**
- [ ] **Protocols used for abstraction**
- [ ] **Proper use of SwiftUI/AppKit patterns**

#### **⚡ Performance**

- [ ] **No unnecessary object creation in loops**
- [ ] **Proper use of `lazy` properties**
- [ ] **Efficient data structures chosen**
- [ ] **No memory leaks (weak references where needed)**
- [ ] **Proper use of `@StateObject` vs `@ObservedObject`**
- [ ] **No blocking operations on main thread**

#### **🔒 Security & Privacy**

- [ ] **No hardcoded secrets or API keys**
- [ ] **Proper input validation**
- [ ] **No sensitive data in logs**
- [ ] **Proper use of Keychain for sensitive data**
- [ ] **No unnecessary permissions requested**

#### **🧪 Testing**

- [ ] **Unit tests cover critical functionality**
- [ ] **Test cases are clear and descriptive**
- [ ] **Mock objects used appropriately**
- [ ] **Edge cases are tested**
- [ ] **No test dependencies on external resources**

#### **📚 Documentation**

- [ ] **Public APIs are documented**
- [ ] **Complex logic has inline comments**
- [ ] **README is updated if needed**
- [ ] **Code is self-documenting with clear naming**

#### **🔄 SwiftUI Specific**

- [ ] **Proper use of `@State`, `@Binding`, `@StateObject`**
- [ ] **No unnecessary view updates**
- [ ] **Proper use of `@Environment` and `@EnvironmentObject`**
- [ ] **Views are properly decomposed**
- [ ] **No business logic in views**

#### **🖥️ macOS Specific**

- [ ] **Proper use of AppKit integration**
- [ ] **Menu bar functionality implemented correctly**
- [ ] **Proper handling of macOS permissions**
- [ ] **App follows macOS Human Interface Guidelines**
- [ ] **Proper use of IOKit and Core Foundation**

---

## 🚀 GitHub CI/CD Pipeline

### **GitHub Actions Workflow**

#### **1. Main CI Pipeline (.github/workflows/ci.yml)**
```yaml
name: Coreveo CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

env:
  DEVELOPER_DIR: /Applications/Xcode.app/Contents/Developer

jobs:
  lint:
    name: Code Quality Check
    runs-on: macos-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Set up Xcode
      run: sudo xcode-select -switch ${{ env.DEVELOPER_DIR }}
      
    - name: Install SwiftLint
      run: brew install swiftlint
      
    - name: Run SwiftLint
      run: swiftlint lint --strict

  test:
    name: Unit Tests
    runs-on: macos-latest
    needs: lint
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Set up Xcode
      run: sudo xcode-select -switch ${{ env.DEVELOPER_DIR }}
      
    - name: Run Unit Tests
      run: |
        xcodebuild test \
          -project Coreveo.xcodeproj \
          -scheme Coreveo \
          -destination 'platform=macOS' \
          -quiet

  build:
    name: Build App
    runs-on: macos-latest
    needs: [lint, test]
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Set up Xcode
      run: sudo xcode-select -switch ${{ env.DEVELOPER_DIR }}
      
    - name: Build App
      run: |
        xcodebuild build \
          -project Coreveo.xcodeproj \
          -scheme Coreveo \
          -destination 'platform=macOS' \
          -configuration Release \
          CODE_SIGN_IDENTITY="" \
          CODE_SIGNING_REQUIRED=NO
          
    - name: Archive App
      run: |
        xcodebuild archive \
          -project Coreveo.xcodeproj \
          -scheme Coreveo \
          -destination 'platform=macOS' \
          -archivePath Coreveo.xcarchive \
          CODE_SIGN_IDENTITY="" \
          CODE_SIGNING_REQUIRED=NO
          
    - name: Upload Build Artifacts
      uses: actions/upload-artifact@v4
      with:
        name: Coreveo-build
        path: Coreveo.xcarchive

  release:
    name: Create Release
    runs-on: macos-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Generate Version
      id: version
      run: |
        YEAR=$(date +%Y)
        MONTH=$(date +%m)
        BUILD_NUMBER=$(git rev-list --count HEAD)
        VERSION="${YEAR}.${MONTH}.${BUILD_NUMBER}"
        echo "version=${VERSION}" >> $GITHUB_OUTPUT
        
    - name: Create Release
      uses: actions/create-release@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        tag_name: v${{ steps.version.outputs.version }}
        release_name: Coreveo v${{ steps.version.outputs.version }}
        body: |
          ## Changes in this Release
          
          - Automated build from main branch
          - Version: ${{ steps.version.outputs.version }}
          
          ## Installation
          
          1. Download the latest build from the artifacts
          2. Extract and run Coreveo.app
        draft: false
        prerelease: true
```

#### **2. Security Scanning (.github/workflows/security.yml)**
```yaml
name: Security Scan

on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly on Monday at 2 AM
  push:
    branches: [ main ]

jobs:
  security:
    name: Security Scan
    runs-on: macos-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Run Security Scan
      run: |
        # Add security scanning tools here
        echo "Security scan completed"
```

---

## 🔄 Development Workflow

### **Branch Strategy**

```
main (production)
├── develop (integration)
├── feature/feature-name
├── bugfix/bug-description
└── hotfix/critical-fix
```

### **Development Process**

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/cpu-monitoring
   ```

2. **Development**
   - Write code following the checklist
   - Write unit tests
   - Update documentation

3. **Pre-Commit Checks**
   - Git hooks run automatically
   - SwiftLint checks code quality
   - Unit tests run

4. **Commit**
   ```bash
   git commit -m "feat: add CPU monitoring dashboard"
   ```

5. **Push & Create PR**
   ```bash
   git push origin feature/cpu-monitoring
   ```

6. **Code Review**
   - Use the code review checklist
   - Address feedback
   - Update PR

7. **Merge to Develop**
   - PR merged to develop branch
   - CI runs automatically

8. **Release**
   - Merge develop to main
   - Automatic release creation
   - Version tagging

### **Quality Gates**

- [ ] **SwiftLint passes with no warnings**
- [ ] **All unit tests pass**
- [ ] **Code review approved**
- [ ] **Documentation updated**
- [ ] **No security vulnerabilities**

---

## 📁 Project Structure

```
Coreveo/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── security.yml
├── .git/
│   └── hooks/
│       ├── pre-commit
│       └── commit-msg
├── docs/
│   ├── ROADMAP.md
│   ├── PRODUCT_COMPARISON.md
│   └── DEVELOPMENT_PLAN.md
├── scripts/
│   └── version.sh
├── Coreveo/
│   ├── Info.plist
│   ├── Sources/
│   ├── Resources/
│   └── Tests/
├── .swiftlint.yml
└── README.md
```

---

## 🎯 Next Steps

1. **Initialize Git Repository**
2. **Set up Xcode Project**
3. **Install SwiftLint**
4. **Create Pre-Commit Hooks**
5. **Set up GitHub Actions**
6. **Begin Phase 1 Development**

This comprehensive plan ensures that Coreveo maintains high code quality, proper versioning, and automated CI/CD processes from day one.

---

*Last Updated: [Current Date]*
*Version: 1.0*
